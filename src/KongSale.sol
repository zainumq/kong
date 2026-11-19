// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {KongMintPass} from "./KongMintPass.sol";
import {KongVesting} from "./KongVesting.sol";
import {IAgentID, IPancakeRouter02} from "./interfaces/Interfaces.sol";

/// @title KongSale — $KONG bonding-curve sale, escrow, graduation & refunds
/// @notice Sells Mint Pass NFTs (1 pass = 1 share) on a 3-tier stepped
///         bonding curve, holds all USDT in escrow, and settles exactly one
///         of two ways:
///
///         GRADUATION (10,000 shares sold): 80% of USDT + 250M KONG are
///         added as PancakeSwap V2 liquidity (LP tokens sent to the dead
///         address, permanently locked), 20% of USDT goes to treasury,
///         vesting clocks start, and pass holders can claim $KONG
///         (burning their pass). Referrers can also claim their accrued
///         referral rewards (see below).
///
///         REFUND (deadline passed without selling out): a 14-day window
///         opens in which any pass holder can burn their pass for a 100%
///         USDT refund. After the window closes, unclaimed escrow goes to
///         treasury (announced upfront in the design doc). Referral
///         rewards are void on a failed sale (no graduation, no claims).
///
///         REFERRAL (on-chain, added 19 Nov 2026): mintPass takes a
///         `referrer` address. The referrer must hold at least one Mint
///         Pass at mint time (else the referral is silently ignored — the
///         mint still succeeds, no reward); self-referral reverts. The
///         referrer earns 3% of the referred buyer's claimable $KONG per
///         share (Tier 1: 1,800; Tier 2: 1,500; Tier 3: 1,200), accrued at
///         mint time and claimable via claimReferral() after graduation
///         only. Rewards are paid from a 15M KONG referral pool held by
///         this contract (funded from the community allocation, which
///         drops 65M -> 50M). Max possible payout is 3% of 485M =
///         14.55M, so the pool always covers it. Any leftover pool stays
///         locked (no recovery function — consistent with the no-admin
///         design).
///
/// @dev NO owner/admin/pause/withdraw. All parameters are immutable
///      (constructor-set). The sale deploys its own KongMintPass and both
///      KongVesting contracts in the constructor (factory pattern), so the
///      whole system is immutable immediately after deploy — there is no
///      two-step setup that could be forgotten or abused.
///
///      FUNDING (deployer responsibility, see README): after deploying this
///      contract the deployer MUST transfer 750M KONG to it (485M for
///      claims + 250M for liquidity + 15M referral pool), 100M KONG to
///      each vesting contract, and 50M KONG to the community address.
///      Claims/graduation revert if the sale is underfunded.
///
///      USDT has 18 decimals on BSC (verified on-chain 19 Nov 2026:
///      decimals() == 18 on 0x55d398326f99059fF775485246999027B3197955).
///      All USDT amounts here are in 18-decimal units (1 USDT = 1e18).
///      v2 priced shares at 1e6 assuming 6 decimals (Ethereum USDT) and
///      was abandoned — see KongDecimalsTest for the regression tests.
contract KongSale is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ---- Curve constants (immutable by design) ----
    uint256 public constant MAX_SHARES = 10_000;
    uint256 public constant MAX_PER_WALLET = 10;
    uint256 public constant TIER1_END = 2_500; // shares 1..2500
    uint256 public constant TIER2_END = 6_000; // shares 2501..6000
    // shares 6001..10000 are Tier 3.

    uint256 public constant TIER1_PRICE = 1e18; // 1 USDT (18 decimals)
    uint256 public constant TIER2_PRICE = 1.5e18; // 1.5 USDT
    uint256 public constant TIER3_PRICE = 2e18; // 2 USDT

    uint256 public constant TIER1_TOKENS = 60_000 ether;
    uint256 public constant TIER2_TOKENS = 50_000 ether;
    uint256 public constant TIER3_TOKENS = 40_000 ether;

    /// @notice Referral reward = 3% of the referred buyer's claimable KONG
    ///         per share. All three are exact integers (no rounding):
    ///         3% of 60,000 / 50,000 / 40,000.
    uint256 public constant TIER1_REFERRAL = 1_800 ether;
    uint256 public constant TIER2_REFERRAL = 1_500 ether;
    uint256 public constant TIER3_REFERRAL = 1_200 ether;

    /// @notice Total raise if sold out: 15,750 USDT.
    uint256 public constant FULL_RAISE_USDT = 15_750e18;
    /// @notice KONG reserved for pass-holder claims.
    uint256 public constant SALE_ALLOCATION = 485_000_000 ether;
    /// @notice KONG paired with 80% of USDT at graduation.
    uint256 public constant LIQUIDITY_ALLOCATION = 250_000_000 ether;
    /// @notice KONG reserved for referral rewards (held by this contract).
    ///         Max possible payout is 3% of 485M = 14.55M, so the pool
    ///         always covers it; any leftover stays locked.
    uint256 public constant REFERRAL_POOL = 15_000_000 ether;
    /// @notice Total KONG the sale must hold (claims + liquidity + referral
    ///         pool). graduate() reverts if the balance is below this, so
    ///         every post-graduation payout is covered.
    uint256 public constant SALE_FUNDING = SALE_ALLOCATION + LIQUIDITY_ALLOCATION + REFERRAL_POOL;
    /// @notice Share of the raise (in basis points) going to liquidity.
    uint256 public constant LIQUIDITY_BPS = 8_000; // 80%

    /// @notice Sale length: 30 days from saleStart.
    uint256 public constant SALE_DURATION = 30 days;
    /// @notice Refund window after the sale deadline: 14 days.
    uint256 public constant REFUND_WINDOW = 14 days;

    /// @notice LP tokens from graduation are sent here: permanently locked,
    ///         nobody can ever remove the initial liquidity.
    address public constant LP_BURN = 0x000000000000000000000000000000000000dEaD;

    // ---- Immutable wiring ----
    IERC20 public immutable kong;
    IERC20 public immutable usdt;
    IAgentID public immutable agentId;
    IPancakeRouter02 public immutable router;
    address public immutable treasury;
    address public immutable team;
    address public immutable community;

    KongMintPass public immutable pass;
    KongVesting public immutable treasuryVesting;
    KongVesting public immutable teamVesting;

    /// @notice Timestamp the sale opens (constructor-set, usually deploy time).
    uint256 public immutable saleStart;

    // ---- State ----
    /// @notice Shares sold so far (== passes minted).
    uint256 public sharesSold;
    /// @notice Total USDT escrowed (gross, before any settlement).
    uint256 public totalRaised;
    /// @notice True once graduate() has succeeded.
    bool public graduated;
    /// @notice True once sweepUnclaimed() has run after a failed sale.
    bool public swept;

    /// @notice Passes minted per wallet (mint cap accounting; transfers do
    ///         not change it — the cap limits minting, not holding).
    mapping(address wallet => uint256 count) public mintedByWallet;
    /// @notice USDT paid for each tokenId (exact refund amount).
    mapping(uint256 tokenId => uint256 usdtPaid) public paidFor;
    /// @notice Referral rewards accrued per referrer (claimable after
    ///         graduation via claimReferral()). Accrued at mint time;
    ///         zeroed on claim. Void on a failed sale (no graduation).
    mapping(address referrer => uint256 earned) public referralEarned;
    /// @notice Sum of all referral rewards ever accrued (pool accounting;
    ///         can never exceed 14.55M = 3% of the 485M sale allocation).
    uint256 public totalReferralEarned;

    event PassMinted(address indexed buyer, uint256 indexed tokenId, uint8 tier, uint256 price);
    event Graduated(uint256 liquidityUsdt, uint256 treasuryUsdt, uint256 liquidityKong);
    event Claimed(address indexed holder, uint256 indexed tokenId, uint256 amount);
    event Refunded(address indexed holder, uint256 indexed tokenId, uint256 amount);
    event Swept(uint256 amount);
    event ReferralReward(address indexed referrer, address indexed buyer, uint256 amount);
    event ReferralClaimed(address indexed referrer, uint256 amount);

    error SaleNotStarted();
    error SaleEnded();
    error SaleSoldOut();
    error NotSoldOut();
    error InvalidAmount();
    error NoAgentId();
    error ExceedsWalletCap();
    error NotGraduated();
    error AlreadyGraduated();
    error RefundNotActive();
    error RefundWindowClosed();
    error AlreadySwept();
    error NotPassOwner();
    error Underfunded();
    error SelfReferral();
    error NothingToClaim();

    constructor(
        address kong_,
        address usdt_,
        address agentId_,
        address router_,
        address treasury_,
        address team_,
        address community_,
        uint256 saleStart_,
        string memory tier1Image_,
        string memory tier2Image_,
        string memory tier3Image_
    ) {
        require(kong_ != address(0), "kong zero");
        require(usdt_ != address(0), "usdt zero");
        require(agentId_ != address(0), "agentId zero");
        require(router_ != address(0), "router zero");
        require(treasury_ != address(0), "treasury zero");
        require(team_ != address(0), "team zero");
        require(community_ != address(0), "community zero");
        require(saleStart_ >= block.timestamp, "saleStart in past");

        kong = IERC20(kong_);
        usdt = IERC20(usdt_);
        agentId = IAgentID(agentId_);
        router = IPancakeRouter02(router_);
        treasury = treasury_;
        team = team_;
        community = community_;
        saleStart = saleStart_;

        // The sale deploys its own pass + vesting contracts: no circular
        // dependency, no post-deploy wiring step.
        pass = new KongMintPass(address(this), treasury_, tier1Image_, tier2Image_, tier3Image_);
        treasuryVesting = new KongVesting(kong_, treasury_, address(this));
        teamVesting = new KongVesting(kong_, team_, address(this));
    }

    // ---- Views ----

    /// @notice Timestamp the sale closes (saleStart + 30 days).
    function saleDeadline() public view returns (uint256) {
        return saleStart + SALE_DURATION;
    }

    /// @notice Timestamp the refund window closes (deadline + 14 days).
    function refundDeadline() public view returns (uint256) {
        return saleDeadline() + REFUND_WINDOW;
    }

    /// @notice Tier (1/2/3) of a share number.
    function tierOfShare(uint256 shareNumber) public pure returns (uint8) {
        if (shareNumber <= TIER1_END) return 1;
        if (shareNumber <= TIER2_END) return 2;
        return 3;
    }

    /// @notice USDT price of one share number (18 decimals).
    function priceOfShare(uint256 shareNumber) public pure returns (uint256) {
        if (shareNumber <= TIER1_END) return TIER1_PRICE;
        if (shareNumber <= TIER2_END) return TIER2_PRICE;
        return TIER3_PRICE;
    }

    /// @notice $KONG claimable for one share number (18 decimals).
    function tokensOfShare(uint256 shareNumber) public pure returns (uint256) {
        if (shareNumber <= TIER1_END) return TIER1_TOKENS;
        if (shareNumber <= TIER2_END) return TIER2_TOKENS;
        return TIER3_TOKENS;
    }

    /// @notice Referral reward (in KONG) earned per share number: 3% of
    ///         that share's claimable tokens (1,800 / 1,500 / 1,200).
    function referralOfShare(uint256 shareNumber) public pure returns (uint256) {
        if (shareNumber <= TIER1_END) return TIER1_REFERRAL;
        if (shareNumber <= TIER2_END) return TIER2_REFERRAL;
        return TIER3_REFERRAL;
    }

    /// @notice Referral rewards a referrer can claim right now: the accrued
    ///         amount after graduation, 0 before (rewards are void without
    ///         graduation).
    function referralClaimable(address referrer) public view returns (uint256) {
        return graduated ? referralEarned[referrer] : 0;
    }

    /// @notice Total USDT cost of buying `amount` shares right now
    ///         (handles tier boundaries inside one purchase).
    function quote(uint256 amount) public view returns (uint256 total) {
        uint256 first = sharesSold + 1;
        for (uint256 i = 0; i < amount; ++i) {
            total += priceOfShare(first + i);
        }
    }

    /// @notice True while the sale is open for minting.
    function saleActive() public view returns (bool) {
        return block.timestamp >= saleStart && block.timestamp < saleDeadline()
            && sharesSold < MAX_SHARES && !graduated;
    }

    /// @notice True while refunds are open (deadline passed, not graduated,
    ///         inside the 14-day window).
    function refundActive() public view returns (bool) {
        return !graduated && block.timestamp >= saleDeadline()
            && block.timestamp < refundDeadline();
    }

    // ---- Mint ----

    /// @notice Mint `amount` passes (1 pass = 1 share). Buyer must hold an
    ///         Agent ID, must not exceed 10 passes per wallet, and must
    ///         have approved this contract for the USDT total (see quote()).
    ///         Each pass records its tier; tier boundaries inside one
    ///         purchase are priced per share.
    /// @param referrer Address of the referrer, or address(0) for none.
    ///        The referrer earns 3% of this purchase's claimable KONG per
    ///        share (see referralOfShare), accrued at mint time. Rules:
    ///        - referrer == buyer (self-referral) REVERTS.
    ///        - referrer != 0 but holding no pass at mint time is treated
    ///          as no referrer: the mint proceeds, no reward accrues, no
    ///          revert. (Deliberate: a buyer mistyping or pasting a stale
    ///          referral link must never lose their purchase; frontends
    ///          should validate the referrer holds a pass before minting.)
    function mintPass(uint256 amount, address referrer) external nonReentrant {
        if (block.timestamp < saleStart) revert SaleNotStarted();
        if (block.timestamp >= saleDeadline()) revert SaleEnded();
        if (sharesSold >= MAX_SHARES) revert SaleSoldOut();
        if (amount == 0 || amount > MAX_PER_WALLET) revert InvalidAmount();
        if (referrer == msg.sender) revert SelfReferral();
        if (agentId.balanceOf(msg.sender) == 0) revert NoAgentId();
        if (mintedByWallet[msg.sender] + amount > MAX_PER_WALLET) revert ExceedsWalletCap();
        if (sharesSold + amount > MAX_SHARES) revert SaleSoldOut();

        // Referrer is valid only if they hold at least one pass right now
        // (checked before this purchase mints, so the buyer's own new
        // passes can never qualify a referrer).
        bool hasReferrer = referrer != address(0) && pass.balanceOf(referrer) > 0;

        uint256 totalPrice = quote(amount);
        mintedByWallet[msg.sender] += amount;
        sharesSold += amount;
        totalRaised += totalPrice;

        usdt.safeTransferFrom(msg.sender, address(this), totalPrice);

        uint256 referralReward;
        for (uint256 i = 0; i < amount; ++i) {
            uint256 shareNumber = sharesSold - amount + 1 + i;
            uint8 tier = tierOfShare(shareNumber);
            uint256 price = priceOfShare(shareNumber);
            uint256 tokenId = pass.mint(msg.sender, tier);
            paidFor[tokenId] = price;
            if (hasReferrer) referralReward += referralOfShare(shareNumber);
            emit PassMinted(msg.sender, tokenId, tier, price);
        }

        if (hasReferrer && referralReward > 0) {
            referralEarned[referrer] += referralReward;
            totalReferralEarned += referralReward;
            emit ReferralReward(referrer, msg.sender, referralReward);
        }
    }

    // ---- Graduation ----

    /// @notice Graduate the sale once all 10,000 shares are sold. Anyone
    ///         may call it (permissionless — there is no owner).
    ///         - 80% of raised USDT + 250M KONG -> PancakeSwap V2 liquidity
    ///           (LP tokens to the dead address, permanently locked).
    ///         - 20% of raised USDT -> treasury.
    ///         - Both vesting clocks start now.
    ///         - Claims open.
    /// @dev Atomic: if the router call reverts, the whole transaction
    ///      reverts and graduate() can simply be called again.
    function graduate() external nonReentrant {
        if (graduated) revert AlreadyGraduated();
        if (sharesSold < MAX_SHARES) revert NotSoldOut();

        // The sale must hold the full funding (485M claims + 250M
        // liquidity + 15M referral pool) so every post-graduation payout
        // — pass claims and referral claims alike — is covered.
        if (kong.balanceOf(address(this)) < SALE_FUNDING) revert Underfunded();

        graduated = true;

        uint256 liquidityUsdt = (totalRaised * LIQUIDITY_BPS) / 10_000;
        uint256 treasuryUsdt = totalRaised - liquidityUsdt;

        kong.forceApprove(address(router), LIQUIDITY_ALLOCATION);
        usdt.forceApprove(address(router), liquidityUsdt);
        router.addLiquidity(
            address(kong),
            address(usdt),
            LIQUIDITY_ALLOCATION,
            liquidityUsdt,
            0, // amountAMin: initial liquidity, no existing pool to protect against
            0, // amountBMin: same
            LP_BURN,
            block.timestamp
        );

        usdt.safeTransfer(treasury, treasuryUsdt);

        treasuryVesting.start(block.timestamp);
        teamVesting.start(block.timestamp);

        emit Graduated(liquidityUsdt, treasuryUsdt, LIQUIDITY_ALLOCATION);
    }

    // ---- Claims (after graduation) ----

    /// @notice Claim $KONG for one pass. Burns the pass, sends the tier's
    ///         token amount to the caller. The caller must own the pass
    ///         (passes are transferable, so claims follow the current
    ///         owner, not the original minter).
    function claim(uint256 tokenId) external nonReentrant {
        if (!graduated) revert NotGraduated();
        _claim(tokenId, msg.sender);
    }

    /// @notice Claim $KONG for several passes in one transaction.
    function claimMany(uint256[] calldata tokenIds) external nonReentrant {
        if (!graduated) revert NotGraduated();
        for (uint256 i = 0; i < tokenIds.length; ++i) {
            _claim(tokenIds[i], msg.sender);
        }
    }

    function _claim(uint256 tokenId, address holder) internal {
        if (pass.ownerOf(tokenId) != holder) revert NotPassOwner();
        uint256 amount = pass.claimableOf(tokenId);
        pass.burn(tokenId); // burn first (checks-effects-interactions)
        emit Claimed(holder, tokenId, amount);
        kong.safeTransfer(holder, amount);
    }

    // ---- Referral claims (after graduation) ----

    /// @notice Claim all accrued referral rewards. After graduation only;
    ///         reverts before graduation (rewards are void on a failed
    ///         sale — no graduation, no referral claims, same as normal
    ///         claims) and reverts when there is nothing to claim (which
    ///         also makes double-claims revert: the first claim zeroes the
    ///         balance). Paid from the 15M KONG referral pool held by this
    ///         contract. Any leftover pool after all claims stays locked
    ///         (no recovery function — consistent with the no-admin
    ///         design).
    /// @dev The referrer does NOT need to still hold a pass to claim:
    ///      rewards were earned at mint time and belong to the referrer
    ///      regardless of later transfers/claims of their own passes.
    function claimReferral() external nonReentrant {
        if (!graduated) revert NotGraduated();
        uint256 amount = referralEarned[msg.sender];
        if (amount == 0) revert NothingToClaim();
        referralEarned[msg.sender] = 0; // zero first (checks-effects-interactions)
        emit ReferralClaimed(msg.sender, amount);
        kong.safeTransfer(msg.sender, amount);
    }

    // ---- Refunds (failed sale only) ----

    /// @notice Refund one pass during the 14-day refund window. Burns the
    ///         pass, returns 100% of the USDT paid for it.
    function refund(uint256 tokenId) external nonReentrant {
        if (!refundActive()) revert RefundNotActive();
        _refund(tokenId, msg.sender);
    }

    /// @notice Refund several passes in one transaction.
    function refundMany(uint256[] calldata tokenIds) external nonReentrant {
        if (!refundActive()) revert RefundNotActive();
        for (uint256 i = 0; i < tokenIds.length; ++i) {
            _refund(tokenIds[i], msg.sender);
        }
    }

    function _refund(uint256 tokenId, address holder) internal {
        if (pass.ownerOf(tokenId) != holder) revert NotPassOwner();
        uint256 amount = paidFor[tokenId];
        pass.burn(tokenId); // burn first (checks-effects-interactions)
        delete paidFor[tokenId];
        emit Refunded(holder, tokenId, amount);
        usdt.safeTransfer(holder, amount);
    }

    // ---- Sweep (failed sale, after refund window) ----

    /// @notice After the refund window closes on a failed sale, send any
    ///         unclaimed USDT escrow to treasury. Callable once, by anyone.
    ///         Disclosed upfront in the design doc (DESIGN.md section 6).
    /// @dev Only USDT is swept. Unclaimed KONG allocations stay locked in
    ///      their contracts: without graduation there is no pool and the
    ///      tokens have no market, and no admin key exists to move them.
    function sweepUnclaimed() external nonReentrant {
        if (graduated) revert AlreadyGraduated();
        if (block.timestamp < refundDeadline()) revert RefundWindowClosed();
        if (swept) revert AlreadySwept();
        swept = true;
        uint256 amount = usdt.balanceOf(address(this));
        emit Swept(amount);
        if (amount > 0) {
            usdt.safeTransfer(treasury, amount);
        }
    }
}
