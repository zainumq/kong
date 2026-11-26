// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {KongMarketOracle} from "../src/KongMarketOracle.sol";
import {MockPass} from "./KongMarket.t.sol";
import {MockUSDT} from "./mocks/Mocks.sol";

/// @notice KongMarketOracle is USDT-ONLY since 26 Nov 2026: the Chainlink
///         BNB/USD feed and every BNB payment path were removed because a
///         BNB sale's 1% fee could never be swept (proven on testnet
///         26 Nov 2026). This suite covers the USDT-only market: fixed
///         USDT floors, USDT listings/buys, and the explicit rejection of
///         every BNB entry point (list / floorOf / buy with value /
///         sweepFees) with InvalidPaymentToken (or a non-payable revert
///         for buy).
contract KongMarketOracleTest is Test {
    KongMarketOracle public market;
    MockPass public pass;
    MockUSDT public usdt;

    address public seller = makeAddr("seller");
    address public buyer = makeAddr("buyer");
    address public treasury = makeAddr("treasury");

    function setUp() public {
        pass = new MockPass(treasury); // 5% royalty to treasury
        usdt = new MockUSDT();
        market = new KongMarketOracle(
            address(pass),
            address(usdt),
            treasury,
            [uint256(1 ether), uint256(1.5 ether), uint256(2 ether)]
        );

        // Seller holds one pass of each tier; market pre-approved.
        pass.mint(seller, 1);
        pass.mint(seller, 2);
        pass.mint(seller, 3);
        vm.prank(seller);
        pass.setApprovalForAll(address(market), true);

        usdt.mint(buyer, 1000 ether);
    }

    // ---- Floor math (USDT fixed) ----

    function test_FloorUsdtFixed() public view {
        assertEq(market.floorOf(1, address(usdt)), 1 ether);
        assertEq(market.floorOf(2, address(usdt)), 1.5 ether);
        assertEq(market.floorOf(3, address(usdt)), 2 ether);
    }

    function test_FloorOf_InvalidTierAndToken() public {
        vm.expectRevert(KongMarketOracle.InvalidTier.selector);
        market.floorOf(0, address(usdt));
        vm.expectRevert(KongMarketOracle.InvalidTier.selector);
        market.floorOf(4, address(usdt));
        // Any non-USDT token — including address(0) (BNB) — is rejected.
        vm.expectRevert(KongMarketOracle.InvalidPaymentToken.selector);
        market.floorOf(1, address(0));
        vm.expectRevert(KongMarketOracle.InvalidPaymentToken.selector);
        market.floorOf(1, address(0x1234));
    }

    // ---- BNB is rejected everywhere ----

    function test_ListBnb_RevertsInvalidPaymentToken() public {
        vm.prank(seller);
        vm.expectRevert(KongMarketOracle.InvalidPaymentToken.selector);
        market.list(1, 1 ether, address(0));
    }

    function test_BuyWithValueReverts_NonPayable() public {
        vm.prank(seller);
        market.list(1, 2 ether, address(usdt));
        vm.prank(buyer);
        usdt.approve(address(market), 2 ether);
        // buy() is non-payable, so `{value: ...}` cannot even be written
        // against its typed interface — call it low-level instead. Any BNB
        // sent with a buy reverts at the function entry.
        vm.deal(address(this), 2 ether);
        vm.prank(buyer);
        (bool ok,) = address(market).call{value: 2 ether}(
            abi.encodeWithSelector(market.buy.selector, uint256(1), uint256(2 ether))
        );
        assertFalse(ok, "buy with value must revert");
        // The listing is untouched after the revert.
        assertEq(market.listingOf(1).seller, seller);
    }

    function test_SweepFeesBnb_RevertsInvalidPaymentToken() public {
        vm.prank(treasury);
        vm.expectRevert(KongMarketOracle.InvalidPaymentToken.selector);
        market.sweepFees(address(0));
        vm.prank(treasury);
        vm.expectRevert(KongMarketOracle.InvalidPaymentToken.selector);
        market.sweepFees(address(0x1234));
    }

    // ---- USDT listing against the fixed floor ----

    function test_ListUsdt_AtFloorOk_BelowFloorReverts() public {
        vm.prank(seller);
        vm.expectRevert(KongMarketOracle.BelowFloor.selector);
        market.list(1, 1 ether - 1, address(usdt));

        vm.prank(seller);
        market.list(1, 1 ether, address(usdt));
        assertEq(market.listingOf(1).price, 1 ether);
        assertEq(market.listingOf(1).paymentToken, address(usdt));
    }

    function test_UpdatePriceUsdt_EnforcesFloor() public {
        vm.prank(seller);
        market.list(1, 2 ether, address(usdt));

        vm.prank(seller);
        vm.expectRevert(KongMarketOracle.BelowFloor.selector);
        market.updatePrice(1, 1 ether - 1);

        vm.prank(seller);
        market.updatePrice(1, 3 ether);
        assertEq(market.listingOf(1).price, 3 ether);
    }

    function test_CancelWorks() public {
        vm.prank(seller);
        market.list(1, 2 ether, address(usdt));

        vm.prank(seller);
        market.cancel(1);
        assertEq(market.listingOf(1).seller, address(0));
    }

    // ---- End-to-end USDT buy + sweep ----

    function test_UsdtBuyE2E() public {
        vm.prank(seller);
        market.list(1, 2 ether, address(usdt));

        vm.prank(buyer);
        usdt.approve(address(market), 2 ether);

        uint256 sellerBefore = usdt.balanceOf(seller);
        uint256 treasuryBefore = usdt.balanceOf(treasury);

        vm.prank(buyer);
        market.buy(1, 2 ether);

        assertEq(pass.ownerOf(1), buyer);
        assertEq(usdt.balanceOf(seller), sellerBefore + 1.88 ether);
        assertEq(usdt.balanceOf(treasury), treasuryBefore + 0.1 ether);
        assertEq(usdt.balanceOf(address(market)), 0.02 ether);

        // Treasury sweeps the accumulated USDT fee.
        vm.prank(treasury);
        market.sweepFees(address(usdt));
        assertEq(usdt.balanceOf(address(market)), 0);
        assertEq(usdt.balanceOf(treasury), treasuryBefore + 0.1 ether + 0.02 ether);
    }

    function test_UsdtBuyE2E_Tier2() public {
        vm.prank(seller);
        market.list(2, 3 ether, address(usdt));

        vm.prank(buyer);
        usdt.approve(address(market), 3 ether);

        uint256 sellerBefore = usdt.balanceOf(seller);
        uint256 treasuryBefore = usdt.balanceOf(treasury);

        vm.prank(buyer);
        market.buy(2, 3 ether);

        assertEq(pass.ownerOf(2), buyer);
        // 5% royalty = 0.15, 1% fee = 0.03, seller nets 2.82.
        assertEq(usdt.balanceOf(seller), sellerBefore + 2.82 ether);
        assertEq(usdt.balanceOf(treasury), treasuryBefore + 0.15 ether);
        assertEq(usdt.balanceOf(address(market)), 0.03 ether);
    }

    // ---- Constructor validation ----

    function test_Constructor_NonAscendingUsdtFloorsRevert() public {
        vm.expectRevert(KongMarketOracle.InvalidFloor.selector);
        new KongMarketOracle(
            address(pass),
            address(usdt),
            treasury,
            [uint256(2 ether), uint256(1.5 ether), uint256(1 ether)]
        );
    }

    function test_Constructor_ZeroUsdtFloorReverts() public {
        vm.expectRevert("usdt floor zero");
        new KongMarketOracle(
            address(pass),
            address(usdt),
            treasury,
            [uint256(0), uint256(1.5 ether), uint256(2 ether)]
        );
    }
}
