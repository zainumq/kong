// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Royalty} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {KongMarket} from "../src/KongMarket.sol";
import {KongMintPass} from "../src/KongMintPass.sol";
import {MockUSDT, MaliciousERC20} from "./mocks/Mocks.sol";

/// @notice Mock pass with adjustable royalty, used ONLY for the live-royalty
///         tests (the real KongMintPass fixes royalty at 5% with no setter).
///         Mirrors the real pass: ERC-721 + ERC-2981 + per-token tier.
contract MockPass is ERC721, ERC721Royalty {
    mapping(uint256 tokenId => uint8 tier) public tierOf;
    uint256 public nextTokenId = 1;

    constructor(address royaltyReceiver) ERC721("Mock Kong Mint Pass", "MKP") {
        _setDefaultRoyalty(royaltyReceiver, 500); // 5%, like the real pass
    }

    function mint(address to, uint8 tier) external returns (uint256 tokenId) {
        tokenId = nextTokenId++;
        tierOf[tokenId] = tier;
        _safeMint(to, tokenId);
    }

    function burn(uint256 tokenId) external {
        _burn(tokenId);
        delete tierOf[tokenId];
    }

    function setRoyalty(address receiver, uint96 bps) external {
        _setDefaultRoyalty(receiver, bps);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Royalty)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

/// @notice Malicious buyer: its onERC721Received hook tries to re-enter
///         `buy` twice — once on the token being bought (must fail: the
///         listing was already deleted, checks-effects-interactions) and
///         once on a second live listing (must fail: ReentrancyGuard).
///         Both attempts use low-level calls and record the outcome
///         instead of reverting, so the outer buy can still complete.
contract MaliciousBuyer is IERC721Receiver {
    KongMarket public market;
    uint256 public targetToken;
    uint256 public attackToken;
    bool public hookRan;
    bool public reenterSameSucceeded;
    bool public reenterOtherSucceeded;

    constructor(address market_) {
        market = KongMarket(payable(market_));
    }

    function setAttack(uint256 target_, uint256 attack_) external {
        targetToken = target_;
        attackToken = attack_;
    }

    function buy(uint256 tokenId) external {
        uint256 price = market.listingOf(tokenId).price;
        market.buy(tokenId, price);
    }

    function onERC721Received(address, address, uint256 tokenId, bytes calldata)
        external
        override
        returns (bytes4)
    {
        if (tokenId == targetToken) {
            hookRan = true;
            (bool okSame,) =
                address(market).call(abi.encodeWithSignature("buy(uint256,uint256)", targetToken, type(uint256).max));
            reenterSameSucceeded = okSame;
            (bool okOther,) =
                address(market).call(abi.encodeWithSignature("buy(uint256,uint256)", attackToken, type(uint256).max));
            reenterOtherSucceeded = okOther;
        }
        return IERC721Receiver.onERC721Received.selector;
    }
}

/// @notice Malicious seller: its receive() hook (triggered when the market
///         pays out the seller's share of a BNB sale) tries to re-enter
///         `buy` on a listing owned by someone else. Must fail
///         (ReentrancyGuard) while the outer buy still completes.
contract MaliciousSeller is IERC721Receiver {
    KongMarket public market;
    KongMintPass public pass;
    uint256 public victimToken;
    uint256 public victimPrice;
    bool public hookRan;
    bool public reenterSucceeded;

    constructor(address market_, address pass_) {
        market = KongMarket(payable(market_));
        pass = KongMintPass(pass_);
    }

    function setVictim(uint256 token_, uint256 price_) external {
        victimToken = token_;
        victimPrice = price_;
    }

    function approveMarket() external {
        pass.setApprovalForAll(address(market), true);
    }

    function list(uint256 tokenId, uint256 price, address paymentToken) external {
        market.list(tokenId, price, paymentToken);
    }

    receive() external payable {
        hookRan = true;
        (bool ok,) = address(market).call{value: victimPrice}(
            abi.encodeWithSignature("buy(uint256,uint256)", victimToken, victimPrice)
        );
        reenterSucceeded = ok;
    }

    function onERC721Received(address, address, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }
}

/// @notice Seller contract that CANNOT receive BNB (no receive/fallback).
///         Used for the audit L-1 / I-4.3 test: a BNB listing from this
///         seller can never be bought (TransferFailed), but cancel +
///         re-list in USDT recovers it.
contract NoReceiveSeller is IERC721Receiver {
    KongMarket public market;
    KongMintPass public pass;

    constructor(address market_, address pass_) {
        market = KongMarket(payable(market_));
        pass = KongMintPass(pass_);
    }

    function approveMarket() external {
        pass.setApprovalForAll(address(market), true);
    }

    function list(uint256 tokenId, uint256 price, address paymentToken) external {
        market.list(tokenId, price, paymentToken);
    }

    function cancel(uint256 tokenId) external {
        market.cancel(tokenId);
    }

    function onERC721Received(address, address, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }
    // NO receive() / fallback() — cannot accept BNB.
}

/// @notice Tests for KongMarket. Uses the REAL KongMintPass (this test
///         contract plays the sale role, so it can mint/burn like a claim)
///         and the REAL 18-decimal MockUSDT — the market is tested against
///         the contracts it will face on mainnet, not lookalikes. A
///         MockPass is used only where the test needs to change the royalty.
contract KongMarketTest is Test {
    KongMarket internal market;
    KongMintPass internal pass;
    MockUSDT internal usdt;

    address internal treasury = makeAddr("treasury");
    address internal seller = makeAddr("seller");
    address internal buyer = makeAddr("buyer");
    address internal other = makeAddr("other");

    string internal constant IMG1 = "https://kong.example/art/tier1.png";
    string internal constant IMG2 = "https://kong.example/art/tier2.png";
    string internal constant IMG3 = "https://kong.example/art/tier3.png";

    // Floors = mint prices. USDT: 1 / 1.5 / 2. BNB: 0.0017 / 0.00254 /
    // 0.00339 ether (BNB ~$589.89, 19 Nov 2026 — test values only; the
    // mainnet deploy sets final BNB floors from the BNB price then).
    uint256 internal constant FLOOR_USDT_T1 = 1 ether;
    uint256 internal constant FLOOR_USDT_T2 = 1.5 ether;
    uint256 internal constant FLOOR_USDT_T3 = 2 ether;
    uint256 internal constant FLOOR_BNB_T1 = 0.0017 ether;
    uint256 internal constant FLOOR_BNB_T2 = 0.00254 ether;
    uint256 internal constant FLOOR_BNB_T3 = 0.00339 ether;

    // Events mirrored for expectEmit.
    event Listed(address indexed seller, uint256 indexed tokenId, uint256 price, address paymentToken);
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

    function setUp() public {
        usdt = new MockUSDT();
        pass = new KongMintPass(address(this), treasury, IMG1, IMG2, IMG3);
        uint256[3] memory floorUsdt = [FLOOR_USDT_T1, FLOOR_USDT_T2, FLOOR_USDT_T3];
        uint256[3] memory floorBnb = [FLOOR_BNB_T1, FLOOR_BNB_T2, FLOOR_BNB_T3];
        market = new KongMarket(address(pass), address(usdt), treasury, floorUsdt, floorBnb);

        // Token 1: tier 1, seller. Token 2: tier 2, seller.
        // Token 3: tier 3, seller. Token 4: tier 1, other.
        pass.mint(seller, 1);
        pass.mint(seller, 2);
        pass.mint(seller, 3);
        pass.mint(other, 1);

        // Seller approves the market for all passes; buyer funds + approves.
        vm.prank(seller);
        pass.setApprovalForAll(address(market), true);
        usdt.mint(buyer, 1_000_000 ether);
        vm.prank(buyer);
        usdt.approve(address(market), type(uint256).max);
        vm.deal(buyer, 100 ether);
    }

    // ---- Helpers ----

    function _listSeller(uint256 tokenId, uint256 price, address paymentToken) internal {
        vm.prank(seller);
        market.list(tokenId, price, paymentToken);
    }

    function _buyBuyer(uint256 tokenId) internal {
        // maxPrice = the listing's current price (the buyer pays exactly
        // what they see; see the maxPrice tests for the protection).
        // Read the price BEFORE prank: vm.prank applies to the next call
        // only, and an argument expression would consume it.
        uint256 price = market.listingOf(tokenId).price;
        vm.prank(buyer);
        market.buy(tokenId, price);
    }

    function _buyBuyerBnb(uint256 tokenId, uint256 value) internal {
        uint256 price = market.listingOf(tokenId).price;
        vm.prank(buyer);
        market.buy{value: value}(tokenId, price);
    }

    // ---- Constructor ----

    function test_ConstructorRevertsZeroAddresses() public {
        uint256[3] memory floorUsdt = [FLOOR_USDT_T1, FLOOR_USDT_T2, FLOOR_USDT_T3];
        uint256[3] memory floorBnb = [FLOOR_BNB_T1, FLOOR_BNB_T2, FLOOR_BNB_T3];
        vm.expectRevert("pass zero");
        new KongMarket(address(0), address(usdt), treasury, floorUsdt, floorBnb);
        vm.expectRevert("usdt zero");
        new KongMarket(address(pass), address(0), treasury, floorUsdt, floorBnb);
        vm.expectRevert("treasury zero");
        new KongMarket(address(pass), address(usdt), address(0), floorUsdt, floorBnb);
    }

    function test_ConstructorRevertsZeroFloor() public {
        uint256[3] memory floorUsdt = [FLOOR_USDT_T1, FLOOR_USDT_T2, FLOOR_USDT_T3];
        uint256[3] memory floorBnb = [FLOOR_BNB_T1, FLOOR_BNB_T2, FLOOR_BNB_T3];
        uint256[3] memory zeroUsdt = [uint256(0), FLOOR_USDT_T2, FLOOR_USDT_T3];
        uint256[3] memory zeroBnb = [FLOOR_BNB_T1, uint256(0), FLOOR_BNB_T3];
        vm.expectRevert("usdt floor zero");
        new KongMarket(address(pass), address(usdt), treasury, zeroUsdt, floorBnb);
        vm.expectRevert("bnb floor zero");
        new KongMarket(address(pass), address(usdt), treasury, floorUsdt, zeroBnb);
    }

    /// @notice Audit L-3: floors must rise with the tier (T1 < T2 < T3)
    ///         per currency — a transposed pair at deploy time is
    ///         permanent (all parameters are immutable), so the
    ///         constructor rejects reversed or equal floors.
    function test_ConstructorRevertsUnorderedFloors() public {
        uint256[3] memory floorUsdt = [FLOOR_USDT_T1, FLOOR_USDT_T2, FLOOR_USDT_T3];
        uint256[3] memory floorBnb = [FLOOR_BNB_T1, FLOOR_BNB_T2, FLOOR_BNB_T3];
        // Reversed USDT floors (the audit L-3 dry-run case: T1=2, T2=1.5,
        // T3=1).
        uint256[3] memory reversedUsdt = [FLOOR_USDT_T3, FLOOR_USDT_T2, FLOOR_USDT_T1];
        vm.expectRevert(KongMarket.InvalidFloor.selector);
        new KongMarket(address(pass), address(usdt), treasury, reversedUsdt, floorBnb);
        // Equal USDT floors (T2 == T3) — not strictly ascending.
        uint256[3] memory equalUsdt = [FLOOR_USDT_T1, FLOOR_USDT_T2, FLOOR_USDT_T2];
        vm.expectRevert(KongMarket.InvalidFloor.selector);
        new KongMarket(address(pass), address(usdt), treasury, equalUsdt, floorBnb);
        // Reversed BNB floors.
        uint256[3] memory reversedBnb = [FLOOR_BNB_T3, FLOOR_BNB_T2, FLOOR_BNB_T1];
        vm.expectRevert(KongMarket.InvalidFloor.selector);
        new KongMarket(address(pass), address(usdt), treasury, floorUsdt, reversedBnb);
    }

    function test_FloorOf() public view {
        assertEq(market.floorOf(1, address(usdt)), FLOOR_USDT_T1);
        assertEq(market.floorOf(2, address(usdt)), FLOOR_USDT_T2);
        assertEq(market.floorOf(3, address(usdt)), FLOOR_USDT_T3);
        assertEq(market.floorOf(1, address(0)), FLOOR_BNB_T1);
        assertEq(market.floorOf(2, address(0)), FLOOR_BNB_T2);
        assertEq(market.floorOf(3, address(0)), FLOOR_BNB_T3);
        assertEq(market.FEE_BPS(), 100);
        assertEq(market.treasury(), treasury);
    }

    function test_FloorOfReverts() public {
        vm.expectRevert(KongMarket.InvalidTier.selector);
        market.floorOf(0, address(usdt));
        vm.expectRevert(KongMarket.InvalidTier.selector);
        market.floorOf(4, address(0));
        vm.expectRevert(KongMarket.InvalidPaymentToken.selector);
        market.floorOf(1, makeAddr("fakeToken"));
    }

    function test_ListingOfEmpty() public view {
        KongMarket.Listing memory listing = market.listingOf(1);
        assertEq(listing.seller, address(0));
        assertEq(listing.price, 0);
        assertEq(listing.paymentToken, address(0));
    }

    // ---- list() ----

    function test_ListUsdtSuccess() public {
        vm.expectEmit(true, true, false, true, address(market));
        emit Listed(seller, 1, 2 ether, address(usdt));
        _listSeller(1, 2 ether, address(usdt));

        KongMarket.Listing memory listing = market.listingOf(1);
        assertEq(listing.seller, seller);
        assertEq(listing.price, 2 ether);
        assertEq(listing.paymentToken, address(usdt));
    }

    function test_ListBnbSuccess() public {
        vm.expectEmit(true, true, false, true, address(market));
        emit Listed(seller, 1, 0.005 ether, address(0));
        _listSeller(1, 0.005 ether, address(0));

        KongMarket.Listing memory listing = market.listingOf(1);
        assertEq(listing.seller, seller);
        assertEq(listing.price, 0.005 ether);
        assertEq(listing.paymentToken, address(0));
    }

    /// @notice Listing at the exact floor (not 1 wei above) succeeds,
    ///         for every tier in both currencies.
    function test_ListAtExactFloor() public {
        uint256[3] memory usdtFloors = [FLOOR_USDT_T1, FLOOR_USDT_T2, FLOOR_USDT_T3];
        uint256[3] memory bnbFloors = [FLOOR_BNB_T1, FLOOR_BNB_T2, FLOOR_BNB_T3];
        for (uint256 i = 0; i < 3; ++i) {
            uint256 tokenId = i + 1; // tokens 1,2,3 are tiers 1,2,3
            _listSeller(tokenId, usdtFloors[i], address(usdt));
            assertEq(market.listingOf(tokenId).price, usdtFloors[i]);
            // Re-list in BNB (overwrite) at the exact BNB floor.
            _listSeller(tokenId, bnbFloors[i], address(0));
            assertEq(market.listingOf(tokenId).price, bnbFloors[i]);
            assertEq(market.listingOf(tokenId).paymentToken, address(0));
        }
    }

    function test_ListRevertsNotOwner() public {
        vm.prank(other);
        vm.expectRevert(KongMarket.NotPassOwner.selector);
        market.list(1, 2 ether, address(usdt));
    }

    function test_ListRevertsZeroPrice() public {
        vm.prank(seller);
        vm.expectRevert(KongMarket.InvalidPrice.selector);
        market.list(1, 0, address(usdt));
    }

    function test_ListRevertsBelowFloorUsdt() public {
        uint256[3] memory usdtFloors = [FLOOR_USDT_T1, FLOOR_USDT_T2, FLOOR_USDT_T3];
        for (uint256 i = 0; i < 3; ++i) {
            vm.prank(seller);
            vm.expectRevert(KongMarket.BelowFloor.selector);
            market.list(i + 1, usdtFloors[i] - 1, address(usdt));
        }
    }

    function test_ListRevertsBelowFloorBnb() public {
        uint256[3] memory bnbFloors = [FLOOR_BNB_T1, FLOOR_BNB_T2, FLOOR_BNB_T3];
        for (uint256 i = 0; i < 3; ++i) {
            vm.prank(seller);
            vm.expectRevert(KongMarket.BelowFloor.selector);
            market.list(i + 1, bnbFloors[i] - 1, address(0));
        }
    }

    function test_ListRevertsInvalidPaymentToken() public {
        vm.prank(seller);
        vm.expectRevert(KongMarket.InvalidPaymentToken.selector);
        market.list(1, 2 ether, makeAddr("fakeToken"));
    }

    function test_ListRevertsNonexistentToken() public {
        vm.prank(seller);
        vm.expectRevert(
            abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 999)
        );
        market.list(999, 2 ether, address(usdt));
    }

    /// @notice No approval is required to list — approval is only checked
    ///         at buy time. `other` never approved the market, yet listing
    ///         their token 4 succeeds.
    function test_ListDoesNotRequireApproval() public {
        vm.prank(other);
        market.list(4, 2 ether, address(usdt));
        assertEq(market.listingOf(4).seller, other);
    }

    /// @notice Re-listing your own already-listed token overwrites the old
    ///         listing (price + currency) — same effect as updatePrice plus
    ///         a currency change.
    function test_ListOverwritesOwnListing() public {
        _listSeller(1, 2 ether, address(usdt));
        _listSeller(1, 0.005 ether, address(0));
        KongMarket.Listing memory listing = market.listingOf(1);
        assertEq(listing.price, 0.005 ether);
        assertEq(listing.paymentToken, address(0));
    }

    // ---- updatePrice() ----

    function test_UpdatePriceSuccess() public {
        _listSeller(1, 2 ether, address(usdt));
        vm.expectEmit(true, false, false, true, address(market));
        emit PriceUpdated(1, 5 ether);
        vm.prank(seller);
        market.updatePrice(1, 5 ether);
        KongMarket.Listing memory listing = market.listingOf(1);
        assertEq(listing.price, 5 ether);
        assertEq(listing.seller, seller);
        assertEq(listing.paymentToken, address(usdt));
    }

    function test_UpdatePriceRevertsNotSeller() public {
        _listSeller(1, 2 ether, address(usdt));
        vm.prank(other);
        vm.expectRevert(KongMarket.NotSeller.selector);
        market.updatePrice(1, 5 ether);
    }

    function test_UpdatePriceRevertsBelowFloor() public {
        _listSeller(1, 2 ether, address(usdt));
        vm.prank(seller);
        vm.expectRevert(KongMarket.BelowFloor.selector);
        market.updatePrice(1, FLOOR_USDT_T1 - 1);
    }

    function test_UpdatePriceRevertsZeroPrice() public {
        _listSeller(1, 2 ether, address(usdt));
        vm.prank(seller);
        vm.expectRevert(KongMarket.InvalidPrice.selector);
        market.updatePrice(1, 0);
    }

    function test_UpdatePriceRevertsNoListing() public {
        vm.prank(seller);
        vm.expectRevert(KongMarket.NoListing.selector);
        market.updatePrice(1, 5 ether);
    }

    /// @notice updatePrice changes the price only — the currency stays.
    function test_UpdatePriceKeepsPaymentToken() public {
        _listSeller(1, 0.005 ether, address(0));
        vm.prank(seller);
        market.updatePrice(1, 0.01 ether);
        assertEq(market.listingOf(1).paymentToken, address(0));
        assertEq(market.listingOf(1).price, 0.01 ether);
    }

    // ---- cancel() ----

    function test_CancelSuccess() public {
        _listSeller(1, 2 ether, address(usdt));
        vm.expectEmit(true, false, false, false, address(market));
        emit Cancelled(1);
        vm.prank(seller);
        market.cancel(1);
        assertEq(market.listingOf(1).seller, address(0));
    }

    function test_CancelRevertsNotSeller() public {
        _listSeller(1, 2 ether, address(usdt));
        vm.prank(other);
        vm.expectRevert(KongMarket.NotSeller.selector);
        market.cancel(1);
        // Listing still there.
        assertEq(market.listingOf(1).seller, seller);
    }

    function test_CancelRevertsNoListing() public {
        vm.prank(seller);
        vm.expectRevert(KongMarket.NoListing.selector);
        market.cancel(1);
    }

    /// @notice A seller can cancel even a stale listing (pass moved or
    ///         burned after listing) — cancel never reads the pass.
    function test_CancelStaleListing() public {
        _listSeller(1, 2 ether, address(usdt));
        vm.prank(seller);
        pass.transferFrom(seller, other, 1);
        vm.prank(seller);
        market.cancel(1);
        assertEq(market.listingOf(1).seller, address(0));
    }

    // ---- buy() USDT ----

    function test_BuyUsdtSuccess() public {
        _listSeller(1, 5 ether, address(usdt));

        uint256 buyerBefore = usdt.balanceOf(buyer);
        uint256 sellerBefore = usdt.balanceOf(seller);
        uint256 treasuryBefore = usdt.balanceOf(treasury);

        vm.expectEmit(true, true, true, true, address(market));
        emit Sold(seller, buyer, 1, 5 ether, address(usdt));
        _buyBuyer(1);

        // 5 USDT: royalty 5% = 0.25, fee 1% = 0.05, seller 94% = 4.70.
        assertEq(usdt.balanceOf(buyer), buyerBefore - 5 ether);
        assertEq(usdt.balanceOf(treasury), treasuryBefore + 0.25 ether);
        assertEq(usdt.balanceOf(address(market)), 0.05 ether); // fee stays
        assertEq(usdt.balanceOf(seller), sellerBefore + 4.70 ether);
        assertEq(pass.ownerOf(1), buyer);
        assertEq(market.listingOf(1).seller, address(0)); // listing deleted
    }

    /// @notice A single-token `approve` (not only setApprovalForAll) is
    ///         enough to buy.
    function test_BuyUsdtWithSingleTokenApproval() public {
        vm.prank(other);
        market.list(4, 2 ether, address(usdt));
        vm.prank(other);
        pass.approve(address(market), 4);
        _buyBuyer(4);
        assertEq(pass.ownerOf(4), buyer);
    }

    function test_BuyUsdtRevertsWithValue() public {
        _listSeller(1, 5 ether, address(usdt));
        vm.prank(buyer);
        vm.expectRevert(KongMarket.ValueNotAllowed.selector);
        market.buy{value: 1}(1, 5 ether);
    }

    function test_BuyRevertsSelfPurchase() public {
        _listSeller(1, 5 ether, address(usdt));
        vm.prank(seller);
        vm.expectRevert(KongMarket.SelfPurchase.selector);
        market.buy(1, 5 ether);
    }

    function test_BuyRevertsNoListing() public {
        vm.prank(buyer);
        vm.expectRevert(KongMarket.NoListing.selector);
        market.buy(1, 5 ether);
    }

    /// @notice Stale listing: the seller moved the pass after listing.
    function test_BuyRevertsStaleOwnership() public {
        _listSeller(1, 5 ether, address(usdt));
        vm.prank(seller);
        pass.transferFrom(seller, other, 1);
        vm.prank(buyer);
        vm.expectRevert(KongMarket.OwnershipChanged.selector);
        market.buy(1, 5 ether);
        // Listing is still recorded (only the seller can cancel it), but
        // it can never be bought.
        assertEq(pass.ownerOf(1), other);
    }

    /// @notice Stale listing: the pass was burned after listing (claim or
    ///         refund burns it — the test contract plays the sale role).
    function test_BuyRevertsBurnedPass() public {
        _listSeller(1, 5 ether, address(usdt));
        pass.burn(1);
        vm.prank(buyer);
        vm.expectRevert(
            abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 1)
        );
        market.buy(1, 5 ether);
    }

    /// @notice Stale listing: the seller revoked approval after listing.
    function test_BuyRevertsApprovalRevoked() public {
        _listSeller(1, 5 ether, address(usdt));
        vm.prank(seller);
        pass.setApprovalForAll(address(market), false);
        vm.prank(buyer);
        vm.expectRevert(KongMarket.NotApproved.selector);
        market.buy(1, 5 ether);
    }

    /// @notice Approval revoked, then re-granted: the same listing becomes
    ///         buyable again.
    function test_BuyAfterApprovalRestored() public {
        _listSeller(1, 5 ether, address(usdt));
        vm.prank(seller);
        pass.setApprovalForAll(address(market), false);
        vm.prank(buyer);
        vm.expectRevert(KongMarket.NotApproved.selector);
        market.buy(1, 5 ether);
        vm.prank(seller);
        pass.setApprovalForAll(address(market), true);
        _buyBuyer(1);
        assertEq(pass.ownerOf(1), buyer);
    }

    // ---- buy() BNB ----

    function test_BuyBnbSuccess() public {
        _listSeller(1, 0.005 ether, address(0));

        uint256 buyerBefore = buyer.balance;
        uint256 sellerBefore = seller.balance;
        uint256 treasuryBefore = treasury.balance;

        _buyBuyerBnb(1, 0.005 ether);

        // 0.005 BNB: royalty 0.00025, fee 0.00005, seller 0.0047.
        assertEq(buyer.balance, buyerBefore - 0.005 ether);
        assertEq(treasury.balance, treasuryBefore + 0.00025 ether);
        assertEq(address(market).balance, 0.00005 ether); // fee stays
        assertEq(seller.balance, sellerBefore + 0.0047 ether);
        assertEq(pass.ownerOf(1), buyer);
        assertEq(market.listingOf(1).seller, address(0));
    }

    function test_BuyBnbRevertsUnderpaid() public {
        _listSeller(1, 0.005 ether, address(0));
        vm.prank(buyer);
        vm.expectRevert(KongMarket.IncorrectValue.selector);
        market.buy{value: 0.005 ether - 1}(1, 0.005 ether);
    }

    function test_BuyBnbRevertsOverpaid() public {
        _listSeller(1, 0.005 ether, address(0));
        vm.prank(buyer);
        vm.expectRevert(KongMarket.IncorrectValue.selector);
        market.buy{value: 0.005 ether + 1}(1, 0.005 ether);
    }

    // ---- buy() maxPrice (audit M-1 regressions) ----

    /// @notice (a) A buy succeeds when the listing price equals the
    ///         buyer's maxPrice.
    function test_BuySucceedsWhenPriceEqualsMaxPrice() public {
        _listSeller(1, 2 ether, address(usdt));
        uint256 buyerBefore = usdt.balanceOf(buyer);
        vm.prank(buyer);
        market.buy(1, 2 ether);
        assertEq(buyerBefore - usdt.balanceOf(buyer), 2 ether);
        assertEq(pass.ownerOf(1), buyer);
    }

    /// @notice (b) Front-run scenario (audit M-1 PoC): the seller lists
    ///         at 2 USDT, the buyer submits buy with maxPrice 2 USDT, and
    ///         the seller front-runs updatePrice to 500 USDT (~Rp9,13
    ///         juta). Before the fix the buy pulled 500 USDT; now it
    ///         reverts and the buyer loses nothing.
    function test_BuyRevertsWhenSellerRaisesPriceAboveMaxPrice() public {
        _listSeller(1, 2 ether, address(usdt));
        vm.prank(seller);
        market.updatePrice(1, 500 ether); // front-run
        uint256 buyerBefore = usdt.balanceOf(buyer);
        uint256 sellerBefore = usdt.balanceOf(seller);
        vm.prank(buyer);
        vm.expectRevert(KongMarket.PriceAboveMax.selector);
        market.buy(1, 2 ether);
        assertEq(usdt.balanceOf(buyer), buyerBefore, "buyer lost nothing");
        assertEq(usdt.balanceOf(seller), sellerBefore, "seller gained nothing");
        assertEq(pass.ownerOf(1), seller);
        assertEq(market.listingOf(1).price, 500 ether, "listing untouched");
    }

    /// @notice (c) BNB listings use maxPrice too: the buy succeeds when
    ///         price <= maxPrice (msg.value still exactly the price), and
    ///         reverts PriceAboveMax when the seller raised the price
    ///         above maxPrice before the buy executes.
    function test_BuyBnbWithMaxPrice() public {
        _listSeller(1, 0.005 ether, address(0));
        vm.prank(buyer);
        market.buy{value: 0.005 ether}(1, 0.01 ether);
        assertEq(pass.ownerOf(1), buyer);

        uint256 token2 = pass.mint(seller, 1);
        _listSeller(token2, 0.005 ether, address(0));
        vm.prank(seller);
        market.updatePrice(token2, 0.05 ether); // front-run
        uint256 buyerBnbBefore = buyer.balance;
        vm.prank(buyer);
        vm.expectRevert(KongMarket.PriceAboveMax.selector);
        market.buy{value: 0.005 ether}(token2, 0.005 ether);
        assertEq(buyer.balance, buyerBnbBefore, "buyer lost no BNB");
        assertEq(pass.ownerOf(token2), seller);
    }

    /// @notice (d) When the seller LOWERS the price below maxPrice, the
    ///         buy succeeds and the buyer pays the new (lower) price —
    ///         not maxPrice.
    function test_BuyPaysLowerPriceWhenSellerLowersPrice() public {
        _listSeller(1, 5 ether, address(usdt));
        vm.prank(seller);
        market.updatePrice(1, 2 ether); // seller lowers the price
        uint256 buyerBefore = usdt.balanceOf(buyer);
        uint256 sellerBefore = usdt.balanceOf(seller);
        vm.prank(buyer);
        market.buy(1, 5 ether);
        assertEq(buyerBefore - usdt.balanceOf(buyer), 2 ether, "buyer pays new price");
        // 2 USDT: royalty 0.10, fee 0.02, seller 1.88.
        assertEq(usdt.balanceOf(seller) - sellerBefore, 1.88 ether, "seller gets 94% of 2");
        assertEq(pass.ownerOf(1), buyer);
    }

    // ---- Exact splits ----

    /// @notice Exact splits at 1 / 1.5 / 2 / 5 / 10 USDT (spec section 4),
    ///         asserted as hardcoded values, not re-derived formulas.
    function test_SplitExactUsdt() public {
        uint256[5] memory prices = [uint256(1 ether), 1.5 ether, 2 ether, 5 ether, 10 ether];
        uint256[5] memory royalties = [
            uint256(0.05 ether),
            0.075 ether,
            0.1 ether,
            0.25 ether,
            0.5 ether
        ];
        uint256[5] memory fees =
            [uint256(0.01 ether), 0.015 ether, 0.02 ether, 0.05 ether, 0.1 ether];
        uint256[5] memory sellerGets =
            [uint256(0.94 ether), 1.41 ether, 1.88 ether, 4.70 ether, 9.40 ether];

        for (uint256 i = 0; i < 5; ++i) {
            uint256 tokenId = pass.mint(seller, 1);
            _listSeller(tokenId, prices[i], address(usdt));

            uint256 treasuryBefore = usdt.balanceOf(treasury);
            uint256 marketBefore = usdt.balanceOf(address(market));
            uint256 sellerBefore = usdt.balanceOf(seller);

            _buyBuyer(tokenId);

            assertEq(usdt.balanceOf(treasury) - treasuryBefore, royalties[i], "royalty");
            assertEq(usdt.balanceOf(address(market)) - marketBefore, fees[i], "fee");
            assertEq(usdt.balanceOf(seller) - sellerBefore, sellerGets[i], "seller");
            assertEq(pass.ownerOf(tokenId), buyer);
        }
    }

    /// @notice Rounding: prices where 5% / 1% do not divide evenly.
    ///         Royalty and fee round DOWN; the seller gets the exact
    ///         remainder, so royalty + fee + seller == price, no dust lost.
    ///         Values computed off-chain (see test comments):
    ///         - 1.234567890123456789 USDT: royalty 61728394506172839,
    ///           fee 12345678901234567, seller 1160493816716049383.
    ///         - 1 USDT + 1 wei: royalty 50000000000000000,
    ///           fee 10000000000000000, seller 940000000000000001.
    function test_SplitRoundingUsdt() public {
        uint256[2] memory prices = [uint256(1_234_567_890_123_456_789), 1 ether + 1];
        uint256[2] memory royalties = [uint256(61_728_394_506_172_839), 50_000_000_000_000_000];
        uint256[2] memory fees = [uint256(12_345_678_901_234_567), 10_000_000_000_000_000];
        uint256[2] memory sellerGets =
            [uint256(1_160_493_816_716_049_383), 940_000_000_000_000_001];

        for (uint256 i = 0; i < 2; ++i) {
            uint256 tokenId = pass.mint(seller, 1);
            _listSeller(tokenId, prices[i], address(usdt));

            uint256 treasuryBefore = usdt.balanceOf(treasury);
            uint256 marketBefore = usdt.balanceOf(address(market));
            uint256 sellerBefore = usdt.balanceOf(seller);

            _buyBuyer(tokenId);

            assertEq(usdt.balanceOf(treasury) - treasuryBefore, royalties[i], "royalty");
            assertEq(usdt.balanceOf(address(market)) - marketBefore, fees[i], "fee");
            assertEq(usdt.balanceOf(seller) - sellerBefore, sellerGets[i], "seller");
            // The three parts always sum to exactly the price.
            assertEq(royalties[i] + fees[i] + sellerGets[i], prices[i], "sum");
        }
    }

    /// @notice Exact splits at the three BNB floors + 0.005 / 0.01 BNB.
    function test_SplitExactBnb() public {
        uint256[5] memory prices = [
            uint256(FLOOR_BNB_T1),
            FLOOR_BNB_T2,
            FLOOR_BNB_T3,
            0.005 ether,
            0.01 ether
        ];
        // 5% of each price.
        uint256[5] memory royalties = [
            uint256(85_000_000_000_000),
            127_000_000_000_000,
            169_500_000_000_000,
            250_000_000_000_000,
            500_000_000_000_000
        ];
        // 1% of each price.
        uint256[5] memory fees = [
            uint256(17_000_000_000_000),
            25_400_000_000_000,
            33_900_000_000_000,
            50_000_000_000_000,
            100_000_000_000_000
        ];
        // 94% of each price.
        uint256[5] memory sellerGets = [
            uint256(1_598_000_000_000_000),
            2_387_600_000_000_000,
            3_186_600_000_000_000,
            4_700_000_000_000_000,
            9_400_000_000_000_000
        ];

        for (uint256 i = 0; i < 5; ++i) {
            uint256 tokenId = pass.mint(seller, 1);
            _listSeller(tokenId, prices[i], address(0));

            uint256 treasuryBefore = treasury.balance;
            uint256 marketBefore = address(market).balance;
            uint256 sellerBefore = seller.balance;

            _buyBuyerBnb(tokenId, prices[i]);

            assertEq(treasury.balance - treasuryBefore, royalties[i], "royalty");
            assertEq(address(market).balance - marketBefore, fees[i], "fee");
            assertEq(seller.balance - sellerBefore, sellerGets[i], "seller");
            assertEq(royalties[i] + fees[i] + sellerGets[i], prices[i], "sum");
            assertEq(pass.ownerOf(tokenId), buyer);
        }
    }

    /// @notice Fuzz: for any price >= the floor, royalty + fee + seller
    ///         == price exactly, with royalty = 5% (live from the real
    ///         pass) and fee = 1%, both rounding down.
    function testFuzz_SplitSumsToPrice(uint256 price) public {
        price = bound(price, 1 ether, 100_000 ether);
        uint256 tokenId = pass.mint(seller, 1);
        _listSeller(tokenId, price, address(usdt));

        uint256 treasuryBefore = usdt.balanceOf(treasury);
        uint256 marketBefore = usdt.balanceOf(address(market));
        uint256 sellerBefore = usdt.balanceOf(seller);

        _buyBuyer(tokenId);

        uint256 royalty = usdt.balanceOf(treasury) - treasuryBefore;
        uint256 fee = usdt.balanceOf(address(market)) - marketBefore;
        uint256 sellerGot = usdt.balanceOf(seller) - sellerBefore;
        assertEq(royalty, (price * 500) / 10_000, "royalty 5%");
        assertEq(fee, (price * 100) / 10_000, "fee 1%");
        assertEq(sellerGot, price - royalty - fee, "seller remainder");
        assertEq(royalty + fee + sellerGot, price, "sum");
    }

    // ---- Live royalty ----

    /// @notice The royalty is read LIVE from the pass at buy time: changing
    ///         the royalty rate AND the receiver between list and buy
    ///         changes what the buy pays. A hardcoded 5%-to-treasury would
    ///         fail both halves of this test.
    function test_RoyaltyLive() public {
        MockPass mockPass = new MockPass(treasury);
        uint256[3] memory floorUsdt = [FLOOR_USDT_T1, FLOOR_USDT_T2, FLOOR_USDT_T3];
        uint256[3] memory floorBnb = [FLOOR_BNB_T1, FLOOR_BNB_T2, FLOOR_BNB_T3];
        KongMarket mockMarket =
            new KongMarket(address(mockPass), address(usdt), treasury, floorUsdt, floorBnb);

        vm.prank(seller);
        mockPass.setApprovalForAll(address(mockMarket), true);
        vm.prank(buyer);
        usdt.approve(address(mockMarket), type(uint256).max);

        // Half 1: list at the default 5%, then raise royalty to 10%
        // BEFORE the buy — the buy must pay 10%.
        uint256 token1 = mockPass.mint(seller, 1);
        vm.prank(seller);
        mockMarket.list(token1, 10 ether, address(usdt));
        mockPass.setRoyalty(treasury, 1000); // 10%

        uint256 treasuryBefore = usdt.balanceOf(treasury);
        uint256 marketBefore = usdt.balanceOf(address(mockMarket));
        uint256 sellerBefore = usdt.balanceOf(seller);
        vm.prank(buyer);
        mockMarket.buy(token1, 10 ether);
        assertEq(usdt.balanceOf(treasury) - treasuryBefore, 1 ether, "royalty 10%");
        assertEq(usdt.balanceOf(address(mockMarket)) - marketBefore, 0.1 ether, "fee 1%");
        assertEq(usdt.balanceOf(seller) - sellerBefore, 8.9 ether, "seller 89%");

        // Half 2: change the RECEIVER (still 5%) — the royalty must go to
        // the new receiver, not to treasury.
        mockPass.setRoyalty(other, 500);
        uint256 token2 = mockPass.mint(seller, 1);
        vm.prank(seller);
        mockMarket.list(token2, 10 ether, address(usdt));

        uint256 otherBefore = usdt.balanceOf(other);
        treasuryBefore = usdt.balanceOf(treasury);
        vm.prank(buyer);
        mockMarket.buy(token2, 10 ether);
        assertEq(usdt.balanceOf(other) - otherBefore, 0.5 ether, "royalty to new receiver");
        assertEq(usdt.balanceOf(treasury) - treasuryBefore, 0, "treasury gets nothing");
    }

    /// @notice A pass whose royalty + fee would exceed the price makes the
    ///         buy revert with a named error (not a bare panic).
    function test_BuyRevertsInvalidRoyalty() public {
        MockPass mockPass = new MockPass(treasury);
        uint256[3] memory floorUsdt = [FLOOR_USDT_T1, FLOOR_USDT_T2, FLOOR_USDT_T3];
        uint256[3] memory floorBnb = [FLOOR_BNB_T1, FLOOR_BNB_T2, FLOOR_BNB_T3];
        KongMarket mockMarket =
            new KongMarket(address(mockPass), address(usdt), treasury, floorUsdt, floorBnb);

        uint256 tokenId = mockPass.mint(seller, 1);
        vm.prank(seller);
        mockPass.setApprovalForAll(address(mockMarket), true);
        vm.prank(seller);
        mockMarket.list(tokenId, 10 ether, address(usdt));
        mockPass.setRoyalty(treasury, 10_000); // 100% royalty + 1% fee > price

        vm.prank(buyer);
        usdt.approve(address(mockMarket), type(uint256).max);
        vm.prank(buyer);
        vm.expectRevert(KongMarket.InvalidRoyalty.selector);
        mockMarket.buy(tokenId, 10 ether);
    }

    // ---- Reentrancy ----

    /// @notice Malicious buyer re-enters from onERC721Received during a
    ///         USDT buy. Both re-entries fail (same token: listing already
    ///         deleted; other live listing: ReentrancyGuard), the outer
    ///         buy completes, and the second listing is untouched.
    function test_ReentrancyMaliciousBuyerUsdt() public {
        MaliciousBuyer attacker = new MaliciousBuyer(address(market));
        usdt.mint(address(attacker), 1_000 ether);
        vm.prank(address(attacker));
        usdt.approve(address(market), type(uint256).max);

        _listSeller(1, 5 ether, address(usdt));
        _listSeller(2, 5 ether, address(usdt));
        attacker.setAttack(1, 2);

        uint256 treasuryBefore = usdt.balanceOf(treasury);
        uint256 sellerBefore = usdt.balanceOf(seller);
        attacker.buy(1);

        assertTrue(attacker.hookRan(), "hook ran");
        assertFalse(attacker.reenterSameSucceeded(), "same-token reentry failed");
        assertFalse(attacker.reenterOtherSucceeded(), "other-token reentry failed");
        // Outer buy completed exactly once.
        assertEq(pass.ownerOf(1), address(attacker));
        assertEq(usdt.balanceOf(treasury) - treasuryBefore, 0.25 ether);
        assertEq(usdt.balanceOf(seller) - sellerBefore, 4.70 ether);
        assertEq(usdt.balanceOf(address(market)), 0.05 ether);
        // Second listing untouched: still listed, still seller's.
        assertEq(market.listingOf(2).seller, seller);
        assertEq(pass.ownerOf(2), seller);
    }

    /// @notice Malicious seller re-enters from receive() during a BNB buy,
    ///         trying to buy a listing owned by someone else. The re-entry
    ///         fails (ReentrancyGuard) while the outer buy completes.
    function test_ReentrancyMaliciousSellerBnb() public {
        MaliciousSeller evilSeller = new MaliciousSeller(address(market), address(pass));
        vm.deal(address(evilSeller), 1 ether);

        // Evil seller owns token 5, listed for BNB. The victim listing is
        // token 2, owned by the honest seller, also BNB.
        uint256 evilToken = pass.mint(address(evilSeller), 1);
        evilSeller.approveMarket();
        evilSeller.list(evilToken, 0.005 ether, address(0));
        _listSeller(2, 0.005 ether, address(0));
        evilSeller.setVictim(2, 0.005 ether);

        _buyBuyerBnb(evilToken, 0.005 ether);

        assertTrue(evilSeller.hookRan(), "hook ran");
        assertFalse(evilSeller.reenterSucceeded(), "reentry failed");
        // Outer buy completed exactly once.
        assertEq(pass.ownerOf(evilToken), buyer);
        // Victim listing untouched: still listed, still seller's.
        assertEq(market.listingOf(2).seller, seller);
        assertEq(pass.ownerOf(2), seller);
    }

    /// @notice Malicious USDT token re-enters `buy` on a second live
    ///         listing during the transferFrom of the first buy. The
    ///         re-entry fails (ReentrancyGuard), the token reverts the
    ///         whole transaction, and NOTHING moves: both listings intact,
    ///         no funds moved, no NFT moved.
    function test_ReentrancyMaliciousUsdt() public {
        MaliciousERC20 evilUsdt = new MaliciousERC20("Tether USD", "USDT");
        uint256[3] memory floorUsdt = [FLOOR_USDT_T1, FLOOR_USDT_T2, FLOOR_USDT_T3];
        uint256[3] memory floorBnb = [FLOOR_BNB_T1, FLOOR_BNB_T2, FLOOR_BNB_T3];
        KongMarket evilMarket =
            new KongMarket(address(pass), address(evilUsdt), treasury, floorUsdt, floorBnb);

        vm.prank(seller);
        pass.setApprovalForAll(address(evilMarket), true);
        evilUsdt.mint(buyer, 1_000 ether);
        vm.prank(buyer);
        evilUsdt.approve(address(evilMarket), type(uint256).max);

        vm.prank(seller);
        evilMarket.list(1, 5 ether, address(evilUsdt));
        vm.prank(seller);
        evilMarket.list(2, 5 ether, address(evilUsdt));

        // Arm: during the transferFrom of buy(1), re-enter buy(2).
        evilUsdt.arm(address(evilMarket), abi.encodeWithSignature("buy(uint256,uint256)", 2, 5 ether));
        vm.prank(buyer);
        vm.expectRevert("reenter failed");
        evilMarket.buy(1, 5 ether);

        // Attack failed: nothing moved.
        assertEq(evilMarket.listingOf(1).seller, seller);
        assertEq(evilMarket.listingOf(2).seller, seller);
        assertEq(pass.ownerOf(1), seller);
        assertEq(pass.ownerOf(2), seller);
        assertEq(evilUsdt.balanceOf(buyer), 1_000 ether);
        assertEq(evilUsdt.balanceOf(address(evilMarket)), 0);
    }

    // ---- sweepFees() ----

    function test_SweepFeesUsdt() public {
        _listSeller(1, 5 ether, address(usdt));
        _buyBuyer(1); // 0.05 USDT fee now sits in the market
        assertEq(usdt.balanceOf(address(market)), 0.05 ether);

        uint256 treasuryBefore = usdt.balanceOf(treasury);
        vm.expectEmit(true, false, false, true, address(market));
        emit FeesSwept(address(usdt), 0.05 ether);
        vm.prank(treasury);
        market.sweepFees(address(usdt));

        assertEq(usdt.balanceOf(treasury), treasuryBefore + 0.05 ether);
        assertEq(usdt.balanceOf(address(market)), 0);
    }

    function test_SweepFeesBnb() public {
        _listSeller(1, 0.005 ether, address(0));
        _buyBuyerBnb(1, 0.005 ether); // 0.00005 BNB fee now sits in the market
        assertEq(address(market).balance, 0.00005 ether);

        uint256 treasuryBefore = treasury.balance;
        vm.expectEmit(true, false, false, true, address(market));
        emit FeesSwept(address(0), 0.00005 ether);
        vm.prank(treasury);
        market.sweepFees(address(0));

        assertEq(treasury.balance, treasuryBefore + 0.00005 ether);
        assertEq(address(market).balance, 0);
    }

    /// @notice Sweeping one currency leaves the other currency's fees in
    ///         place.
    function test_SweepFeesOnlySweepsChosenToken() public {
        _listSeller(1, 5 ether, address(usdt));
        _buyBuyer(1);
        uint256 token2 = pass.mint(seller, 1);
        _listSeller(token2, 0.005 ether, address(0));
        _buyBuyerBnb(token2, 0.005 ether);

        vm.prank(treasury);
        market.sweepFees(address(usdt));
        assertEq(usdt.balanceOf(address(market)), 0);
        assertEq(address(market).balance, 0.00005 ether); // BNB fee remains

        vm.prank(treasury);
        market.sweepFees(address(0));
        assertEq(address(market).balance, 0);
    }

    function test_SweepFeesRevertsNotTreasury() public {
        _listSeller(1, 5 ether, address(usdt));
        _buyBuyer(1);
        vm.prank(seller);
        vm.expectRevert(KongMarket.NotTreasury.selector);
        market.sweepFees(address(usdt));
        vm.prank(buyer);
        vm.expectRevert(KongMarket.NotTreasury.selector);
        market.sweepFees(address(0));
        // Fees still in the contract.
        assertEq(usdt.balanceOf(address(market)), 0.05 ether);
    }

    function test_SweepFeesRevertsInvalidToken() public {
        vm.prank(treasury);
        vm.expectRevert(KongMarket.InvalidPaymentToken.selector);
        market.sweepFees(makeAddr("fakeToken"));
    }

    function test_SweepFeesRevertsNothingToSweep() public {
        vm.prank(treasury);
        vm.expectRevert(KongMarket.NothingToSweep.selector);
        market.sweepFees(address(usdt));
        vm.prank(treasury);
        vm.expectRevert(KongMarket.NothingToSweep.selector);
        market.sweepFees(address(0));
    }

    /// @notice Sweeping twice: the second sweep finds nothing and reverts.
    function test_SweepFeesTwice() public {
        _listSeller(1, 5 ether, address(usdt));
        _buyBuyer(1);
        vm.prank(treasury);
        market.sweepFees(address(usdt));
        vm.prank(treasury);
        vm.expectRevert(KongMarket.NothingToSweep.selector);
        market.sweepFees(address(usdt));
    }

    // ---- Re-listing & independence ----

    function test_RelistAfterCancel() public {
        _listSeller(1, 2 ether, address(usdt));
        vm.prank(seller);
        market.cancel(1);
        _listSeller(1, 5 ether, address(usdt));
        _buyBuyer(1);
        assertEq(pass.ownerOf(1), buyer);
    }

    function test_RelistAfterBuy() public {
        _listSeller(1, 2 ether, address(usdt));
        _buyBuyer(1);
        // Buyer is the new owner and can list the same token again.
        vm.prank(buyer);
        pass.setApprovalForAll(address(market), true);
        vm.prank(buyer);
        market.list(1, 3 ether, address(usdt));
        assertEq(market.listingOf(1).seller, buyer);
        // `other` buys it.
        usdt.mint(other, 100 ether);
        vm.prank(other);
        usdt.approve(address(market), type(uint256).max);
        vm.prank(other);
        market.buy(1, 3 ether);
        assertEq(pass.ownerOf(1), other);
    }

    function test_TwoListingsIndependent() public {
        _listSeller(1, 2 ether, address(usdt));
        _listSeller(2, 5 ether, address(usdt));

        // Buy token 1: token 2's listing is untouched.
        _buyBuyer(1);
        assertEq(pass.ownerOf(1), buyer);
        KongMarket.Listing memory listing2 = market.listingOf(2);
        assertEq(listing2.seller, seller);
        assertEq(listing2.price, 5 ether);
        assertEq(listing2.paymentToken, address(usdt));

        // Cancel token 2: token 1 stays sold (no listing to disturb).
        vm.prank(seller);
        market.cancel(2);
        assertEq(market.listingOf(2).seller, address(0));
        assertEq(pass.ownerOf(1), buyer);
    }

    // ---- I-4 coverage gaps (adapted from the audit PoC, Lampiran A) ----

    /// @notice I-4.1: a new owner can overwrite a stale listing left
    ///         behind by the previous owner; the old seller can no longer
    ///         cancel it; the new owner is paid on the sale.
    function test_StaleListingOverwrittenByNewOwner() public {
        _listSeller(1, 5 ether, address(usdt));
        vm.prank(seller);
        pass.transferFrom(seller, other, 1);
        vm.prank(other);
        pass.setApprovalForAll(address(market), true);
        vm.prank(other);
        market.list(1, 3 ether, address(usdt));
        KongMarket.Listing memory listing = market.listingOf(1);
        assertEq(listing.seller, other);
        assertEq(listing.price, 3 ether);
        vm.prank(seller);
        vm.expectRevert(KongMarket.NotSeller.selector);
        market.cancel(1);
        uint256 otherBefore = usdt.balanceOf(other);
        vm.prank(buyer);
        market.buy(1, 3 ether);
        assertEq(pass.ownerOf(1), buyer);
        assertEq(usdt.balanceOf(other) - otherBefore, 2.82 ether);
    }

    /// @notice I-4.2: updatePrice on a listing whose pass was burned
    ///         reverts InvalidTier (the tier reads 0); cancel still works.
    function test_UpdatePriceBurnedPassRevertsInvalidTier() public {
        _listSeller(1, 5 ether, address(usdt));
        pass.burn(1);
        vm.prank(seller);
        vm.expectRevert(KongMarket.InvalidTier.selector);
        market.updatePrice(1, 6 ether);
        vm.prank(seller);
        market.cancel(1);
        assertEq(market.listingOf(1).seller, address(0));
    }

    /// @notice I-4.3 / L-1: a seller contract that cannot receive BNB
    ///         bricks its BNB listing (every buy reverts TransferFailed);
    ///         the seller recovers by cancelling and re-listing in USDT.
    function test_BnbRejectingSellerBlocksBuyButCancelAndRelistUsdtWorks() public {
        NoReceiveSeller noReceive = new NoReceiveSeller(address(market), address(pass));
        uint256 tokenId = pass.mint(address(noReceive), 1);
        noReceive.approveMarket();
        noReceive.list(tokenId, 0.005 ether, address(0));
        vm.prank(buyer);
        vm.expectRevert(KongMarket.TransferFailed.selector);
        market.buy{value: 0.005 ether}(tokenId, 0.005 ether);
        noReceive.cancel(tokenId);
        noReceive.list(tokenId, 2 ether, address(usdt));
        vm.prank(buyer);
        market.buy(tokenId, 2 ether);
        assertEq(pass.ownerOf(tokenId), buyer);
    }

    /// @notice I-4.5: fuzz the split on the BNB side (mirror of the USDT
    ///         fuzz). Buyer holds 100 BNB, so prices are bounded to 50.
    function testFuzz_SplitSumsToPriceBnb(uint256 price) public {
        price = bound(price, FLOOR_BNB_T1, 50 ether);
        uint256 tokenId = pass.mint(seller, 1);
        _listSeller(tokenId, price, address(0));

        uint256 treasuryBefore = treasury.balance;
        uint256 marketBefore = address(market).balance;
        uint256 sellerBefore = seller.balance;

        _buyBuyerBnb(tokenId, price);

        uint256 royalty = treasury.balance - treasuryBefore;
        uint256 fee = address(market).balance - marketBefore;
        uint256 sellerGot = seller.balance - sellerBefore;
        assertEq(royalty, (price * 500) / 10_000, "royalty 5%");
        assertEq(fee, (price * 100) / 10_000, "fee 1%");
        assertEq(sellerGot, price - royalty - fee, "seller remainder");
        assertEq(royalty + fee + sellerGot, price, "sum");
    }

    /// @notice I-4.5 / I-1: USDT sent directly to the market is swept to
    ///         treasury with the fees; a foreign token cannot be swept
    ///         and stays locked in the market.
    function test_SweepFeesSweepsDirectUsdtDonation() public {
        usdt.mint(address(this), 3 ether);
        usdt.transfer(address(market), 3 ether);
        uint256 treasuryBefore = usdt.balanceOf(treasury);
        vm.prank(treasury);
        market.sweepFees(address(usdt));
        assertEq(usdt.balanceOf(treasury) - treasuryBefore, 3 ether);

        MockUSDT foreign = new MockUSDT();
        foreign.mint(address(this), 7 ether);
        foreign.transfer(address(market), 7 ether);
        vm.prank(treasury);
        vm.expectRevert(KongMarket.InvalidPaymentToken.selector);
        market.sweepFees(address(foreign));
        assertEq(foreign.balanceOf(address(market)), 7 ether);
    }

    // ---- Direct BNB transfers ----

    /// @notice Plain BNB transfers to the market revert (BNB may only
    ///         enter as exact `msg.value` in `buy`), so a mistaken direct
    ///         transfer fails at the sender instead of landing in the fee
    ///         pot.
    function test_ReceiveRevertsDirectBnb() public {
        (bool ok,) = address(market).call{value: 1 ether}("");
        assertFalse(ok);
        assertEq(address(market).balance, 0);
    }
}
