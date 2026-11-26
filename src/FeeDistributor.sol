// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @notice Minimal KongMarket interface: only the fee sweep is needed.
interface IKongMarketSweep {
    function sweepFees(address token) external;
}

/// @title FeeDistributor — fee treasury for KongMarket
/// @notice This contract is the `treasury` of the KongMarket mainnet
///         deployment. It receives swept market fees (1% of sales) plus
///         KongMintPass secondary-sale royalties (5%, receiver = treasury),
///         and splits every new USDT 50% holder pool / 30% builder /
///         20% rebate pool. The rebate pool funds the 50% trading-fee
///         rebate for pass holders ("Balik Modal dari Aktivitas Sendiri",
///         25 Nov 2026): rebates first, referral rewards from the
///         remainder, both paid out monthly via Merkle (v1.1 wiring).
///
///         HISTORICAL NOTE (closed 26 Nov 2026): the market used to
///         accept BNB-denominated sales, and a BNB sale's 1% fee was
///         stranded in the market — `sweep()` only ever called
///         `market.sweepFees(address(usdt))` and `split()` accounts USDT
///         only, while `sweepFees(address(0))` could only be called by
///         this contract as treasury and no function here ever called it
///         (proven on testnet 26 Nov 2026: one BNB sale left exactly
///         0.0000269851 tBNB, 1% of the price, unsweepable). The market
///         contract was rewritten USDT-only (KongMarketOracle, testnet
///         26 Nov 2026): `list()`/`floorOf()` revert `InvalidPaymentToken()`
///         for anything but USDT, `buy()` is non-payable, and the oracle
///         price feed was removed — so there is no BNB fee path left to
///         strand, and this contract sweeps USDT by construction.
///         Re-verified 26 Nov 2026: a 2 USDT sale's 0.02 USDT fee split
///         exactly 50/30/20, and list/floor/buy/sweepFees with BNB all
///         revert. (NatSpec-only change: no bytecode change; the deployed
///         testnet contract keeps its earlier verification.)
///
///         TESTNET BUILD (25 Nov 2026, user order: "build testnet aja dulu").
///         Mainnet deploy is NOT part of this build.
///
/// @dev No owner/admin/pause/upgrade — same house style as KongSale.
///      The market address is a ONE-TIME setter (not immutable) only
///      because the market's own constructor needs this contract as its
///      treasury while this contract needs the market's address to sweep:
///      a circular dependency. Deploy order: (1) deploy this contract,
///      (2) deploy KongMarket with treasury = this contract, (3) call
///      setMarket() in the SAME deploy script, immediately. For mainnet,
///      the deploy script must do all three steps back-to-back; a factory
///      that deploys both atomically is the v1.1 hardening.
///      Splits are computed on the BALANCE DELTA (balance - accounted),
///      so no accounting can drift from actual holdings.
///      Holder-pool distribution (monthly Merkle claims) is v1.1 wiring:
///      the pool is accounted here as `holderPool` and funded into the
///      existing audited KongMerkleDistributor from there. Nothing in this
///      contract lets anyone withdraw holder funds.
///      Mint-proceeds seed is split 50/50 between `holderPool` and
///      `rebatePool`, so rebates run from month one, before fee income
///      is meaningful.
contract FeeDistributor is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Fee split (basis points, must sum to 10_000).
    uint256 public constant HOLDER_BPS = 5_000;
    uint256 public constant BUILDER_BPS = 3_000;
    uint256 public constant GROWTH_BPS = 2_000;

    /// @notice USDT (18 decimals on BSC).
    IERC20 public immutable usdt;

    /// @notice Receives the 30% builder share (user's wallet).
    address public immutable builder;

    /// @notice Receives the 20% rebate-pool share (rebates/referrals).
    ///         Withdraws it to fund the monthly Merkle distributions.
    address public immutable growthPool;

    /// @notice The KongMarketPass contract: the ONLY caller of seed().
    ///         Set once via setMarketPass() (same one-time pattern as
    ///         setMarket — the pass constructor needs this contract's
    ///         address while this contract needs the pass's address).
    address public marketPass;

    /// @notice KongMarket contract. Set once via setMarket().
    address public market;

    /// @notice Total USDT already allocated into buckets.
    uint256 public accounted;

    /// @notice USDT owed to pass holders (monthly Merkle distribution, v1.1).
    uint256 public holderPool;

    /// @notice USDT owed to the builder.
    uint256 public builderShare;

    /// @notice USDT funding pass-holder fee rebates (50% of fee paid,
    ///         max 2 USDT/pass/month, pro-rata if short) and, from the
    ///         remainder, referral rewards. Funded by 20% of swept fees
    ///         plus half of every mint-proceeds seed.
    uint256 public rebatePool;

    /// @notice Referral scheme (recorded here; paid monthly via Merkle
    ///         v1.1 from the rebate pool — see contract header). A
    ///         referee's trading fees earn their referrer 10% for 90
    ///         days from the day the referrer was set, capped at 20 USDT
    ///         per referrer per calendar month. Fees are swept in
    ///         aggregate, so this contract has no per-trade accrual:
    ///         the cap and the 90-day window are enforced by the Merkle
    ///         builder at payout time, and the constants below are the
    ///         on-chain source of truth for those parameters.
    uint256 public constant REFERRAL_BPS = 1_000; // 10% of the referee's fee
    uint256 public constant REFERRAL_WINDOW = 90 days;
    uint256 public constant REFERRAL_MONTHLY_CAP = 20 ether; // 20 USDT (18 decimals)

    /// @notice Referrer recorded for each referee (trader).
    ///         address(0) = no referrer recorded.
    mapping(address => address) public referrerOf;

    /// @notice Timestamp when the referee's referrer was set. Start of
    ///         the 90-day referral window.
    mapping(address => uint256) public referrerSetAt;

    /// @notice Timestamp of the first fee income (first sweep/split that
    ///         brought market fees in). 0 = the market has never earned
    ///         fees yet. Read by KongMarketPass for the "launch guarantee":
    ///         a pass refund window extends to 7 days after this moment.
    uint256 public firstSweepAt;

    error MarketAlreadySet();
    error MarketPassAlreadySet();
    error MarketNotSet();
    error NotMarketPass();
    error NotBuilder();
    error NotGrowthPool();
    error NothingNew();
    error InsufficientShare();
    error InvalidReferrer();
    error SelfReferral();
    error ReferrerAlreadySet();

    event MarketSet(address indexed market);
    event MarketPassSet(address indexed marketPass);
    event ReferrerSet(address indexed referee, address indexed referrer, uint256 timestamp);
    event Swept(uint256 amount);
    event Split(uint256 holderAmount, uint256 builderAmount, uint256 rebateAmount);
    event Seeded(uint256 holderAmount, uint256 rebateAmount);
    event FirstSweep(uint256 timestamp);
    event Withdrawn(address indexed to, uint256 amount, uint8 indexed bucket);

    constructor(address usdt_, address builder_, address growthPool_) {
        require(usdt_ != address(0), "usdt zero");
        require(builder_ != address(0), "builder zero");
        require(growthPool_ != address(0), "growth zero");
        usdt = IERC20(usdt_);
        builder = builder_;
        growthPool = growthPool_;
    }

    /// @notice Point this distributor at the KongMarketPass contract.
    ///         One-time; only the pass may call seed(). Call in the deploy
    ///         script right after deploying the pass.
    function setMarketPass(address marketPass_) external {
        if (marketPass != address(0)) revert MarketPassAlreadySet();
        require(marketPass_ != address(0), "marketPass zero");
        marketPass = marketPass_;
        emit MarketPassSet(marketPass_);
    }

    /// @notice Point this distributor at the KongMarket contract. One-time:
    ///         once set it can never change (treasury is immutable on the
    ///         market side too). Call in the deploy script, immediately
    ///         after deploying the market with treasury = this contract.
    function setMarket(address market_) external {
        if (market != address(0)) revert MarketAlreadySet();
        require(market_ != address(0), "market zero");
        market = market_;
        emit MarketSet(market_);
    }

    /// @notice Record the caller's referrer. One-time and self-service
    ///         only: only the trader themselves may set their own
    ///         referrer, the referrer must be a different non-zero
    ///         address, and once set it can never be changed (same
    ///         one-time style as setMarket / setMarketPass). Pure
    ///         recording — it moves no funds and does not touch escrow,
    ///         splits, or withdrawals. The 90-day window starts at the
    ///         recorded timestamp; referral rewards are paid monthly via
    ///         Merkle v1.1 from the rebate pool.
    function setReferrer(address referrer) external {
        if (referrer == address(0)) revert InvalidReferrer();
        if (referrer == msg.sender) revert SelfReferral();
        if (referrerOf[msg.sender] != address(0)) revert ReferrerAlreadySet();
        referrerOf[msg.sender] = referrer;
        referrerSetAt[msg.sender] = block.timestamp;
        emit ReferrerSet(msg.sender, referrer, block.timestamp);
    }

    /// @notice True while a referee's referral window covers `timestamp`:
    ///         a referrer was recorded and the timestamp falls within 90
    ///         days of when it was set. Read by the Merkle builder (and
    ///         anyone verifying a payout) — no funds move here.
    function isReferralActive(address referee, uint256 timestamp) external view returns (bool) {
        address referrer = referrerOf[referee];
        if (referrer == address(0)) return false;
        uint256 start = referrerSetAt[referee];
        return timestamp >= start && timestamp <= start + REFERRAL_WINDOW;
    }

    /// @notice Pull swept fees from the market, then split them 50/30/20.
    ///         Callable by anyone (keeper/cron) — the split is fixed, so
    ///         there is nothing for the caller to gain or manipulate.
    function sweep() external nonReentrant {
        if (market == address(0)) revert MarketNotSet();
        uint256 before = usdt.balanceOf(address(this));
        IKongMarketSweep(market).sweepFees(address(usdt));
        uint256 swept = usdt.balanceOf(address(this)) - before;
        _splitNew(0);
        emit Swept(swept);
    }

    /// @notice Split any unaccounted USDT sitting in this contract (e.g.
    ///         direct royalty transfers) 50/30/20. Callable by anyone.
    function split() external nonReentrant {
        _splitNew(0);
    }

    /// @notice Credit a mint-proceeds seed from the KongMarketPass.
    ///         ONLY the pass contract may call this, and the pass contract
    ///         transfers the USDT + calls seed() atomically in the same tx
    ///         (see KongMarketPass.distributeProceeds), so the seed can
    ///         never be re-split as fee income. The seed is split 50/50
    ///         between the holder pool and the rebate pool.
    function seed() external nonReentrant {
        if (msg.sender != marketPass) revert NotMarketPass();
        _splitNew(1);
    }

    /// @notice Builder withdraws their accumulated 30% share.
    function withdrawBuilder() external nonReentrant {
        if (msg.sender != builder) revert NotBuilder();
        uint256 amount = builderShare;
        if (amount == 0) revert InsufficientShare();
        builderShare = 0;
        usdt.safeTransfer(builder, amount);
        emit Withdrawn(builder, amount, 1);
    }

    /// @notice Growth-pool operator withdraws the accumulated rebate pool
    ///         (20% fee share + half of every seed) to fund the monthly
    ///         Merkle rebate/referral distributions (v1.1 wiring).
    function withdrawGrowth() external nonReentrant {
        if (msg.sender != growthPool) revert NotGrowthPool();
        uint256 amount = rebatePool;
        if (amount == 0) revert InsufficientShare();
        rebatePool = 0;
        usdt.safeTransfer(growthPool, amount);
        emit Withdrawn(growthPool, amount, 2);
    }

    /// @notice Allocate all unaccounted USDT. kind 0 = fee split
    ///         50/30/20 (holder/builder/rebate), kind 1 = mint-proceeds
    ///         seed split 50/50 between holder pool and rebate pool.
    function _splitNew(uint8 kind) internal {
        uint256 balance = usdt.balanceOf(address(this));
        if (balance <= accounted) revert NothingNew();
        uint256 fresh = balance - accounted;
        accounted = balance;
        if (kind == 1) {
            uint256 holderAmount = fresh / 2;
            uint256 rebateAmount = fresh - holderAmount;
            holderPool += holderAmount;
            rebatePool += rebateAmount;
            emit Seeded(holderAmount, rebateAmount);
            emit Split(holderAmount, 0, rebateAmount);
        } else {
            if (firstSweepAt == 0) {
                firstSweepAt = block.timestamp;
                emit FirstSweep(block.timestamp);
            }
            uint256 holderAmount = (fresh * HOLDER_BPS) / 10_000;
            uint256 builderAmount = (fresh * BUILDER_BPS) / 10_000;
            uint256 rebateAmount = fresh - holderAmount - builderAmount;
            holderPool += holderAmount;
            builderShare += builderAmount;
            rebatePool += rebateAmount;
            emit Split(holderAmount, builderAmount, rebateAmount);
        }
    }
}
