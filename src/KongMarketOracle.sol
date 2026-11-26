// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title IKongMintPass — minimal interface KongMarketOracle needs from the pass
/// @notice Only the ERC-721 transfer/approval reads, the ERC-2981 royalty
///         read, and the per-token tier. The market never mints or burns.
interface IKongMintPass is IERC721, IERC2981 {
    function tierOf(uint256 tokenId) external view returns (uint8);
}

/// @title KongMarketOracle — fixed-price marketplace for KongMintPass (BSC)
/// @notice Same marketplace as KongMarket (v1), except it is USDT-ONLY.
///
///         USDT-ONLY SINCE 26 NOV 2026. The contract keeps the name
///         KongMarketOracle for continuity (it was deployed under that
///         name on BSC testnet), but the Chainlink BNB/USD feed and every
///         BNB payment path were removed. Reason, proven on testnet
///         26 Nov 2026 (random fee-flow test): a BNB-denominated sale
///         left its 1% fee in BNB inside the market, and the fee could
///         never be swept — FeeDistributor.sweep() only sweeps USDT, and
///         market.sweepFees(BNB) can only be called by the distributor,
///         which never calls it. Rather than strand 1% of every BNB
///         sale forever, BNB was removed from the market entirely.
///
///         Non-custodial: the seller keeps the pass and only approves this
///         contract (`approve` per token or `setApprovalForAll`). The pass
///         and the payment move in a single `buy` transaction.
///
///         Payment is USDT only (18 decimals on BSC). Any other
///         `paymentToken` — including `address(0)` (BNB) — reverts with
///         `InvalidPaymentToken()` in `floorOf`, `list` and `sweepFees`,
///         and `buy` is non-payable, so a BNB payment reverts.
///
///         Every sale splits the price three ways, enforced on-chain:
///         - royalty, read LIVE from `pass.royaltyInfo(tokenId, price)`
///           and paid to the receiver it returns (5% to treasury on the
///           real KongMintPass — never hardcoded here);
///         - fee, 1% (100 bps), kept in this contract and withdrawable
///           only by treasury via `sweepFees()`;
///         - the remainder (price - royalty - fee) to the seller, so no
///           rounding dust is ever lost.
///
///         Price floors (per tier, read live from `pass.tierOf(tokenId)`):
///         USDT floor: FIXED, immutable per tier (1 / 1.5 / 2 USDT).
///
///         The floor is enforced at LIST / UPDATE-PRICE time, not at BUY
///         time (same as v1). A listing is a firm offer at the price the
///         seller set.
///
/// @dev NO owner/admin/pause/upgrade. Pass, USDT, treasury, fee and USDT
///      floors are immutable (constructor-set). The only special role is
///      treasury calling `sweepFees()` — it cannot change the fee, the
///      royalty, or any other parameter.
///
///      The only funds ever held by this contract are the accumulated 1%
///      fees in USDT. It never holds NFTs and never holds BNB (buy is
///      non-payable and plain BNB transfers revert — see `receive()`).
contract KongMarketOracle is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Marketplace fee in basis points: 100 = 1%.
    uint256 public constant FEE_BPS = 100;
    /// @notice Basis-points denominator.
    uint256 public constant BPS_DENOMINATOR = 10_000;

    /// @notice The pass collection traded here.
    IKongMintPass public immutable pass;
    /// @notice BSC USDT (18 decimals).
    IERC20 public immutable usdt;
    /// @notice Only this address may call `sweepFees()`.
    address public immutable treasury;

    // USDT price floors per tier (1/2/3). Immutable: Solidity does not
    // allow `immutable` arrays, so the three values are stored as
    // individual immutables (same pattern as KongMarket's floors).
    uint256 private immutable _floorUsdtTier1;
    uint256 private immutable _floorUsdtTier2;
    uint256 private immutable _floorUsdtTier3;

    /// @notice One active listing. Inactive when `seller == address(0)`.
    struct Listing {
        address seller;
        uint256 price;
        address paymentToken; // always the USDT address (USDT-only market)
    }

    mapping(uint256 tokenId => Listing listing) private _listings;

    event Listed(
        address indexed seller, uint256 indexed tokenId, uint256 price, address paymentToken
    );
    event PriceUpdated(uint256 indexed tokenId, uint256 newPrice);
    event Cancelled(uint256 indexed tokenId);
    event Sold(
        address indexed seller,
        address indexed buyer,
        uint256 indexed tokenId,
        uint256 price,
        address paymentToken
    );
    event FeesSwept(address indexed token, uint256 amount);

    error InvalidTier();
    error InvalidPaymentToken();
    error InvalidPrice();
    error InvalidFloor();
    error BelowFloor();
    error NotPassOwner();
    error NotSeller();
    error NoListing();
    error SelfPurchase();
    error OwnershipChanged();
    error NotApproved();
    error PriceAboveMax();
    error InvalidRoyalty();
    error NotTreasury();
    error NothingToSweep();
    error TransferFailed();

    constructor(address pass_, address usdt_, address treasury_, uint256[3] memory floorUsdt_) {
        require(pass_ != address(0), "pass zero");
        require(usdt_ != address(0), "usdt zero");
        require(treasury_ != address(0), "treasury zero");
        // A zero floor would let a pass be listed for dust (1 wei),
        // defeating the floor's purpose (protect sellers from panic
        // selling below their mint cost). Floors are the mint prices,
        // always > 0.
        require(floorUsdt_[0] > 0 && floorUsdt_[1] > 0 && floorUsdt_[2] > 0, "usdt floor zero");
        // Floors must rise with the tier (T1 < T2 < T3): a transposed
        // pair at deploy time is permanent (all parameters are
        // immutable) and would silently weaken the floor protection
        // for one tier. Audit L-3 (carried over from v1).
        if (!(floorUsdt_[0] < floorUsdt_[1] && floorUsdt_[1] < floorUsdt_[2])) {
            revert InvalidFloor();
        }

        pass = IKongMintPass(pass_);
        usdt = IERC20(usdt_);
        treasury = treasury_;
        _floorUsdtTier1 = floorUsdt_[0];
        _floorUsdtTier2 = floorUsdt_[1];
        _floorUsdtTier3 = floorUsdt_[2];
    }

    // ---- Views ----

    /// @notice Price floor for a tier (1/2/3). Only the USDT address is
    ///         accepted as `paymentToken`; anything else — including
    ///         `address(0)` (BNB) — reverts with `InvalidPaymentToken()`.
    function floorOf(uint8 tier, address paymentToken) public view returns (uint256) {
        if (tier < 1 || tier > 3) revert InvalidTier();
        if (paymentToken != address(usdt)) revert InvalidPaymentToken();
        if (tier == 1) return _floorUsdtTier1;
        if (tier == 2) return _floorUsdtTier2;
        return _floorUsdtTier3;
    }

    /// @notice The active listing for a tokenId, or an empty listing
    ///         (`seller == address(0)`) when nothing is listed.
    function listingOf(uint256 tokenId) public view returns (Listing memory) {
        return _listings[tokenId];
    }

    // ---- Listing ----

    /// @notice List a pass for sale at `price` in USDT. Caller must own
    ///         the pass; `price` must be > 0 and >= the floor of the
    ///         pass's tier (tier read live from the pass contract).
    ///         Any `paymentToken` other than the USDT address — including
    ///         `address(0)` (BNB) — reverts with `InvalidPaymentToken()`.
    /// @dev No approval is required to list — approval is checked at buy
    ///      time. Re-listing an already-listed token overwrites the old
    ///      listing (same effect as `updatePrice` plus a currency change);
    ///      only the current owner can do so, which also lets a new owner
    ///      replace a stale listing left behind by a previous owner.
    function list(uint256 tokenId, uint256 price, address paymentToken) external {
        if (paymentToken != address(usdt)) revert InvalidPaymentToken();
        if (price == 0) revert InvalidPrice();
        // ownerOf reverts for a nonexistent (never minted / burned) token.
        if (pass.ownerOf(tokenId) != msg.sender) revert NotPassOwner();
        uint8 tier = pass.tierOf(tokenId);
        if (price < floorOf(tier, paymentToken)) revert BelowFloor();

        _listings[tokenId] = Listing({seller: msg.sender, price: price, paymentToken: paymentToken});
        emit Listed(msg.sender, tokenId, price, paymentToken);
    }

    /// @notice Change the price of your own active listing. The new price
    ///         must be > 0 and >= the floor of the pass's tier, in USDT.
    /// @dev Reads the tier live, so this reverts on a listing whose pass
    ///      was burned after listing (its tier reads 0). Cancel such a
    ///      listing instead — `cancel` does not read the tier.
    function updatePrice(uint256 tokenId, uint256 newPrice) external {
        Listing storage listing = _listings[tokenId];
        if (listing.seller == address(0)) revert NoListing();
        if (listing.seller != msg.sender) revert NotSeller();
        if (newPrice == 0) revert InvalidPrice();
        uint8 tier = pass.tierOf(tokenId);
        if (newPrice < floorOf(tier, listing.paymentToken)) revert BelowFloor();

        listing.price = newPrice;
        emit PriceUpdated(tokenId, newPrice);
    }

    /// @notice Cancel your own active listing. Works even if the listing
    ///         went stale (pass transferred or burned after listing) — it
    ///         never reads the tier or the price.
    function cancel(uint256 tokenId) external {
        Listing storage listing = _listings[tokenId];
        if (listing.seller == address(0)) revert NoListing();
        if (listing.seller != msg.sender) revert NotSeller();

        delete _listings[tokenId];
        emit Cancelled(tokenId);
    }

    // ---- Buying ----

    /// @notice Buy a listed pass with USDT. Send no BNB — this function
    ///         is non-payable, so any `msg.value` reverts. Approve this
    ///         contract for `price` USDT first.
    /// @param tokenId The listed pass to buy.
    /// @param maxPrice The highest price the buyer is willing to pay, in
    ///        USDT. The buy reverts with `PriceAboveMax` if the listing's
    ///        current price exceeds it — this protects the buyer from a
    ///        seller front-running `updatePrice` between the moment the
    ///        buyer reads the price and the buy executes (audit M-1,
    ///        carried over from v1). Pass the price shown in the UI; if
    ///        the seller LOWERED the price since, the buyer pays the new
    ///        (lower) price, not `maxPrice`.
    /// @dev The floor is NOT re-checked at buy time (same as v1): a
    ///      listing is a firm offer at the price the seller set.
    ///
    ///      Checks-effects-interactions: the listing is deleted BEFORE any
    ///      transfer, and the function is nonReentrant, so a malicious
    ///      buyer/seller/royalty-receiver contract cannot re-enter `buy`
    ///      (or any other guarded function) mid-sale.
    ///
    ///      Split (all in USDT):
    ///      - royalty = `pass.royaltyInfo(tokenId, price)` (live), paid to
    ///        the returned receiver;
    ///      - fee = price * 100 / 10_000 (rounds down), stays in this
    ///        contract until treasury sweeps it;
    ///      - seller = price - royalty - fee (the remainder, so no dust
    ///        is lost to rounding).
    function buy(uint256 tokenId, uint256 maxPrice) external nonReentrant {
        Listing memory listing = _listings[tokenId];
        if (listing.seller == address(0)) revert NoListing();
        if (listing.price == 0) revert InvalidPrice();
        // Price protection (audit M-1): the seller may have raised the
        // price after the buyer read it — never charge more than the
        // buyer agreed to. Checked before the value checks so a
        // front-run price hike fails here with a clear error.
        if (listing.price > maxPrice) revert PriceAboveMax();
        if (msg.sender == listing.seller) revert SelfPurchase();
        // Stale-listing guards: the seller must still own the pass
        // (ownerOf reverts if the pass was burned, e.g. claimed) and the
        // market must still be approved to move it.
        if (pass.ownerOf(tokenId) != listing.seller) revert OwnershipChanged();
        if (
            pass.getApproved(tokenId) != address(this)
                && !pass.isApprovedForAll(listing.seller, address(this))
        ) revert NotApproved();

        uint256 price = listing.price;

        (address royaltyReceiver, uint256 royaltyAmount) = pass.royaltyInfo(tokenId, price);
        uint256 feeAmount = (price * FEE_BPS) / BPS_DENOMINATOR;
        // The real pass charges 5%, so this can only trigger on a pass
        // contract whose royalty was (mis)configured above 99% — but a
        // checked-math underflow would revert with a bare panic, so fail
        // with a named error instead.
        if (royaltyAmount + feeAmount > price) revert InvalidRoyalty();
        uint256 sellerAmount = price - royaltyAmount - feeAmount;

        // Effects first: delete the listing before any external call.
        delete _listings[tokenId];
        emit Sold(listing.seller, msg.sender, tokenId, price, listing.paymentToken);

        // Pull the full price, then pay out royalty + seller; the fee
        // stays in this contract.
        usdt.safeTransferFrom(msg.sender, address(this), price);
        if (royaltyAmount > 0) {
            usdt.safeTransfer(royaltyReceiver, royaltyAmount);
        }
        if (sellerAmount > 0) {
            usdt.safeTransfer(listing.seller, sellerAmount);
        }

        // NFT last: a malicious buyer contract's onERC721Received hook
        // runs after all funds have moved and the listing is gone, and
        // re-entry is blocked by the guard.
        pass.safeTransferFrom(listing.seller, msg.sender, tokenId);
    }

    // ---- Fee sweep ----

    /// @notice Send ALL accumulated USDT fees to treasury. Treasury only.
    ///         Any `token` other than the USDT address — including
    ///         `address(0)` (BNB) — reverts with `InvalidPaymentToken()`.
    /// @dev Sweeps the whole balance rather than a tracked fee total: the
    ///      contract never receives USDT any other way in normal operation
    ///      (USDT only enters via `buy`, and plain BNB transfers revert —
    ///      see `receive()`), so the whole balance IS the accumulated fee.
    ///      USDT sent here directly by mistake is swept to treasury as
    ///      well — that is the intended recovery, not a bug.
    function sweepFees(address token) external nonReentrant {
        if (msg.sender != treasury) revert NotTreasury();
        if (token != address(usdt)) revert InvalidPaymentToken();
        uint256 amount = usdt.balanceOf(address(this));
        if (amount == 0) revert NothingToSweep();
        emit FeesSwept(token, amount);
        usdt.safeTransfer(treasury, amount);
    }

    /// @notice Reject plain BNB transfers: the market is USDT-only, so
    ///         BNB has no legitimate way in. Without this, a mistaken
    ///         direct transfer would sit in the contract forever with no
    ///         sweep path (sweepFees only handles USDT).
    receive() external payable {
        revert TransferFailed();
    }
}
