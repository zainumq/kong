// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title IKongMintPass — minimal interface KongMarket needs from the pass
/// @notice Only the ERC-721 transfer/approval reads, the ERC-2981 royalty
///         read, and the per-token tier. The market never mints or burns.
interface IKongMintPass is IERC721, IERC2981 {
    function tierOf(uint256 tokenId) external view returns (uint8);
}

/// @title KongMarket — fixed-price marketplace for KongMintPass (BSC)
/// @notice Non-custodial: the seller keeps the pass and only approves this
///         contract (`approve` per token or `setApprovalForAll`). The pass
///         and the payment move in a single `buy` transaction.
///
///         Payment is USDT (18 decimals on BSC) or native BNB, chosen per
///         listing (`paymentToken` = USDT address or `address(0)`).
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
///         Listings have a per-tier price floor (the mint price of the
///         tier: 1 / 1.5 / 2 USDT, and the BNB equivalents fixed at deploy
///         time). The tier is read LIVE from `pass.tierOf(tokenId)`.
///
///         Listings can go STALE: because the seller keeps the pass, they
///         can transfer or burn (claim/refund) it while listed. `buy`
///         re-checks ownership and approval at execution time and reverts
///         on a stale listing; frontends must also verify live before
///         showing a Buy button. A stale listing can always be cancelled
///         by its seller.
///
/// @dev NO owner/admin/pause/upgrade. Pass, USDT, treasury, fee and both
///      floor schedules are immutable (constructor-set). The only special
///      role is treasury calling `sweepFees()` — it cannot change the fee,
///      the royalty, or any other parameter.
///
///      The only funds ever held by this contract are the accumulated 1%
///      fees (USDT and BNB). It never holds NFTs.
contract KongMarket is ReentrancyGuard {
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

    // Price floors per tier (1/2/3), per currency. Immutable: Solidity
    // does not allow `immutable` arrays, so the six values are stored as
    // individual immutables (same pattern as KongSale's per-tier price
    // constants). Read them via `floorOf(tier, paymentToken)`.
    uint256 private immutable _floorUsdtTier1;
    uint256 private immutable _floorUsdtTier2;
    uint256 private immutable _floorUsdtTier3;
    uint256 private immutable _floorBnbTier1;
    uint256 private immutable _floorBnbTier2;
    uint256 private immutable _floorBnbTier3;

    /// @notice One active listing. Inactive when `seller == address(0)`.
    struct Listing {
        address seller;
        uint256 price;
        address paymentToken; // USDT address, or address(0) for BNB
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
    error IncorrectValue();
    error ValueNotAllowed();
    error PriceAboveMax();
    error InvalidRoyalty();
    error NotTreasury();
    error NothingToSweep();
    error TransferFailed();

    constructor(
        address pass_,
        address usdt_,
        address treasury_,
        uint256[3] memory floorUsdt_,
        uint256[3] memory floorBnb_
    ) {
        require(pass_ != address(0), "pass zero");
        require(usdt_ != address(0), "usdt zero");
        require(treasury_ != address(0), "treasury zero");
        // A zero floor would let a pass be listed for dust (1 wei),
        // defeating the floor's purpose (protect sellers from panic
        // selling below their mint cost). Floors are the mint prices,
        // always > 0.
        require(floorUsdt_[0] > 0 && floorUsdt_[1] > 0 && floorUsdt_[2] > 0, "usdt floor zero");
        require(floorBnb_[0] > 0 && floorBnb_[1] > 0 && floorBnb_[2] > 0, "bnb floor zero");
        // Floors must rise with the tier (T1 < T2 < T3, per currency):
        // a transposed pair at deploy time is permanent (all parameters
        // are immutable) and would silently weaken the floor protection
        // for one tier. Audit L-3.
        if (!(floorUsdt_[0] < floorUsdt_[1] && floorUsdt_[1] < floorUsdt_[2])) {
            revert InvalidFloor();
        }
        if (!(floorBnb_[0] < floorBnb_[1] && floorBnb_[1] < floorBnb_[2])) {
            revert InvalidFloor();
        }

        pass = IKongMintPass(pass_);
        usdt = IERC20(usdt_);
        treasury = treasury_;
        _floorUsdtTier1 = floorUsdt_[0];
        _floorUsdtTier2 = floorUsdt_[1];
        _floorUsdtTier3 = floorUsdt_[2];
        _floorBnbTier1 = floorBnb_[0];
        _floorBnbTier2 = floorBnb_[1];
        _floorBnbTier3 = floorBnb_[2];
    }

    // ---- Views ----

    /// @notice Price floor for a tier (1/2/3) in a currency (USDT address
    ///         or `address(0)` for BNB).
    function floorOf(uint8 tier, address paymentToken) public view returns (uint256) {
        if (tier < 1 || tier > 3) revert InvalidTier();
        if (paymentToken == address(usdt)) {
            if (tier == 1) return _floorUsdtTier1;
            if (tier == 2) return _floorUsdtTier2;
            return _floorUsdtTier3;
        }
        if (paymentToken == address(0)) {
            if (tier == 1) return _floorBnbTier1;
            if (tier == 2) return _floorBnbTier2;
            return _floorBnbTier3;
        }
        revert InvalidPaymentToken();
    }

    /// @notice The active listing for a tokenId, or an empty listing
    ///         (`seller == address(0)`) when nothing is listed.
    function listingOf(uint256 tokenId) public view returns (Listing memory) {
        return _listings[tokenId];
    }

    // ---- Listing ----

    /// @notice List a pass for sale at `price` in `paymentToken` (USDT
    ///         address or `address(0)` for BNB). Caller must own the pass;
    ///         `price` must be > 0 and >= the floor of the pass's tier
    ///         (tier read live from the pass contract).
    /// @dev No approval is required to list — approval is checked at buy
    ///      time. Re-listing an already-listed token overwrites the old
    ///      listing (same effect as `updatePrice` plus a currency change);
    ///      only the current owner can do so, which also lets a new owner
    ///      replace a stale listing left behind by a previous owner.
    function list(uint256 tokenId, uint256 price, address paymentToken) external {
        if (paymentToken != address(usdt) && paymentToken != address(0)) {
            revert InvalidPaymentToken();
        }
        if (price == 0) revert InvalidPrice();
        // ownerOf reverts for a nonexistent (never minted / burned) token.
        if (pass.ownerOf(tokenId) != msg.sender) revert NotPassOwner();
        uint8 tier = pass.tierOf(tokenId);
        if (price < floorOf(tier, paymentToken)) revert BelowFloor();

        _listings[tokenId] = Listing({seller: msg.sender, price: price, paymentToken: paymentToken});
        emit Listed(msg.sender, tokenId, price, paymentToken);
    }

    /// @notice Change the price of your own active listing. The new price
    ///         must be > 0 and >= the floor of the pass's tier, in the
    ///         listing's own currency (the currency cannot be changed —
    ///         cancel and re-list to switch currency).
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
    ///         went stale (pass transferred or burned after listing).
    function cancel(uint256 tokenId) external {
        Listing storage listing = _listings[tokenId];
        if (listing.seller == address(0)) revert NoListing();
        if (listing.seller != msg.sender) revert NotSeller();

        delete _listings[tokenId];
        emit Cancelled(tokenId);
    }

    // ---- Buying ----

    /// @notice Buy a listed pass. For a BNB listing, send exactly `price`
    ///         as `msg.value`; for a USDT listing, send no BNB and approve
    ///         this contract for `price` USDT first.
    /// @param tokenId The listed pass to buy.
    /// @param maxPrice The highest price the buyer is willing to pay, in
    ///        the listing's currency. The buy reverts with `PriceAboveMax`
    ///        if the listing's current price exceeds it — this protects
    ///        the buyer from a seller front-running `updatePrice` between
    ///        the moment the buyer reads the price and the buy executes
    ///        (audit M-1). Pass the price shown in the UI; if the seller
    ///        LOWERED the price since, the buyer pays the new (lower)
    ///        price, not `maxPrice`. For a BNB listing, `msg.value` must
    ///        still equal the (current) price exactly, AND the price must
    ///        be <= `maxPrice`.
    /// @dev Checks-effects-interactions: the listing is deleted BEFORE any
    ///      transfer, and the function is nonReentrant, so a malicious
    ///      buyer/seller/royalty-receiver contract cannot re-enter `buy`
    ///      (or any other guarded function) mid-sale.
    ///
    ///      Split (all in the listing's currency):
    ///      - royalty = `pass.royaltyInfo(tokenId, price)` (live), paid to
    ///        the returned receiver;
    ///      - fee = price * 100 / 10_000 (rounds down), stays in this
    ///        contract until treasury sweeps it;
    ///      - seller = price - royalty - fee (the remainder, so no dust
    ///        is lost to rounding).
    function buy(uint256 tokenId, uint256 maxPrice) external payable nonReentrant {
        Listing memory listing = _listings[tokenId];
        if (listing.seller == address(0)) revert NoListing();
        if (listing.price == 0) revert InvalidPrice();
        // Price protection (audit M-1): the seller may have raised the
        // price after the buyer read it — never charge more than the
        // buyer agreed to. Checked before the value checks so a
        // front-run price hike fails here with a clear error instead of
        // a misleading IncorrectValue.
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
        // Value checks up front (before any effects): a BNB listing must
        // be paid with exactly `price` as msg.value (no over/under-payment,
        // so no refund logic and no stuck dust); a USDT listing must carry
        // no BNB at all (it would otherwise be stuck in the contract —
        // nothing here could return it).
        if (listing.paymentToken == address(0)) {
            if (msg.value != price) revert IncorrectValue();
        } else {
            if (msg.value != 0) revert ValueNotAllowed();
        }

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

        if (listing.paymentToken == address(0)) {
            if (royaltyAmount > 0) {
                _sendBnb(royaltyReceiver, royaltyAmount);
            }
            if (sellerAmount > 0) {
                _sendBnb(listing.seller, sellerAmount);
            }
            // feeAmount stays in this contract.
        } else {
            // Pull the full price, then pay out royalty + seller; the fee
            // stays in this contract.
            usdt.safeTransferFrom(msg.sender, address(this), price);
            if (royaltyAmount > 0) {
                usdt.safeTransfer(royaltyReceiver, royaltyAmount);
            }
            if (sellerAmount > 0) {
                usdt.safeTransfer(listing.seller, sellerAmount);
            }
        }

        // NFT last: a malicious buyer contract's onERC721Received hook
        // runs after all funds have moved and the listing is gone, and
        // re-entry is blocked by the guard.
        pass.safeTransferFrom(listing.seller, msg.sender, tokenId);
    }

    // ---- Fee sweep ----

    /// @notice Send ALL accumulated fees in `token` (USDT address or
    ///         `address(0)` for BNB) to treasury. Treasury only.
    /// @dev Sweeps the whole balance rather than a tracked fee total: the
    ///      contract never receives these tokens any other way in normal
    ///      operation (USDT only enters via `buy`, BNB only as exact
    ///      `msg.value` in `buy`, and plain BNB transfers revert — see
    ///      `receive()`), so the whole balance IS the accumulated fee.
    ///      USDT sent here directly by mistake is swept to treasury as
    ///      well — that is the intended recovery, not a bug. (BNB can
    ///      still be force-sent via `selfdestruct`; sweeping recovers it
    ///      the same way.)
    function sweepFees(address token) external nonReentrant {
        if (msg.sender != treasury) revert NotTreasury();
        if (token == address(0)) {
            uint256 amount = address(this).balance;
            if (amount == 0) revert NothingToSweep();
            emit FeesSwept(token, amount);
            _sendBnb(treasury, amount);
        } else if (token == address(usdt)) {
            uint256 amount = usdt.balanceOf(address(this));
            if (amount == 0) revert NothingToSweep();
            emit FeesSwept(token, amount);
            usdt.safeTransfer(treasury, amount);
        } else {
            revert InvalidPaymentToken();
        }
    }

    // ---- Internal ----

    /// @notice Send BNB with a plain call (no gas stipend — the receiver
    ///         may be a contract) and revert if it fails.
    function _sendBnb(address to, uint256 amount) internal {
        (bool ok,) = to.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    /// @notice Reject plain BNB transfers: BNB may only enter via `buy`
    ///         (exact `msg.value`). Without this, a mistaken direct
    ///         transfer would be swept to treasury as if it were a fee
    ///         instead of reverting at the sender.
    receive() external payable {
        revert TransferFailed();
    }
}
