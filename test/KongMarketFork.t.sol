// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {KongMarket} from "../src/KongMarket.sol";

interface IKongMintPassReal is IERC721, IERC2981 {
    function mint(address to, uint8 tier) external returns (uint256 tokenId);
    function tierOf(uint256 tokenId) external view returns (uint8);
    function sale() external view returns (address);
}

/// @notice Fork test: end-to-end KongMarket against the REAL mainnet
///         contracts on BSC — the real KongMintPass (0x615A…) and the real
///         18-decimal USDT (0x55d3…). This is the fallback for a real
///         testnet deploy when the testnet faucet is unreachable: the
///         fork runs entirely locally and sends NO real transaction.
///
///         The sale has not opened yet (1 Dec 2026), so no real pass
///         exists on mainnet — the test pranks the KongSale address
///         (the pass contract's immutable `sale` role) to mint the two
///         test passes. USDT is funded with `deal` (no whale needed).
///
///         Run with:
///           BSC_RPC_URL=https://bsc-dataseed2.bnbchain.org forge test --match-contract KongMarketForkTest -vv
///         (any BSC public RPC works; dataseed1 / publicnode.com are
///         fallbacks if dataseed2 is rate-limited.)
///
///         Skipped automatically when BSC_RPC_URL is not set, so the
///         default `forge test` never depends on network access.
contract KongMarketForkTest is Test {
    address internal constant MAINNET_PASS = 0x615AAaFF423f1005B7bF51e3dEC6BbF5958Af89B;
    address internal constant MAINNET_USDT = 0x55d398326f99059fF775485246999027B3197955;
    address internal constant MAINNET_SALE = 0x2F3728AABD454530302B9d2B66e9986f3ac1A3e3;
    // Royalty receiver configured on the real pass (Account 16 treasury).
    address internal constant PASS_TREASURY = 0xed1A29F81a61029089Ad8D641670baD47bDced3A;

    // Test floors (same as the unit suite / testnet plan): USDT 1 / 1.5 /
    // 2 ether; BNB 0.0017 / 0.00254 / 0.00339 ether.
    uint256[3] internal FLOOR_USDT = [uint256(1 ether), 1.5 ether, 2 ether];
    uint256[3] internal FLOOR_BNB =
        [uint256(0.0017 ether), 0.00254 ether, 0.00339 ether];

    KongMarket internal market;
    IKongMintPassReal internal pass;
    IERC20 internal usdt;

    address internal seller = makeAddr("fork-seller");
    address internal buyer = makeAddr("fork-buyer");
    address internal marketTreasury = makeAddr("fork-market-treasury");

    uint256 internal passT1;
    uint256 internal passT2;

    function setUp() public {
        string memory rpc = vm.envOr("BSC_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            vm.skip(true, "BSC_RPC_URL not set; fork test skipped");
        }
        vm.createSelectFork(rpc);

        pass = IKongMintPassReal(MAINNET_PASS);
        usdt = IERC20(MAINNET_USDT);

        // Sanity: the fork really points at the live mainnet contracts.
        assertEq(pass.sale(), MAINNET_SALE, "pass sale role must be KongSale v3");
        assertGt(MAINNET_PASS.code.length, 0, "pass must have code");
        assertGt(MAINNET_USDT.code.length, 0, "usdt must have code");

        market = new KongMarket(
            MAINNET_PASS, MAINNET_USDT, marketTreasury, FLOOR_USDT, FLOOR_BNB
        );

        // Mint the two test passes by pranking the sale role (the sale
        // has not opened, so no real pass exists to buy).
        vm.startPrank(MAINNET_SALE);
        passT1 = pass.mint(seller, 1);
        passT2 = pass.mint(seller, 2);
        vm.stopPrank();

        // Fund the buyer: 100 USDT (deal) + 1 BNB (vm.deal).
        deal(MAINNET_USDT, buyer, 100 ether);
        vm.deal(buyer, 1 ether);
        vm.deal(seller, 1 ether);
    }

    /// @notice Full e2e: USDT sale (2 USDT) then BNB sale (0.00254 BNB),
    ///         then fee sweeps — asserting the exact 5% / 1% / 94% split
    ///         at every step against the REAL pass royalty + REAL USDT.
    function test_ForkE2E_UsdtThenBnbThenSweep() public {
        // ---- Preconditions: tiers + live royalty on the real pass ----
        assertEq(pass.tierOf(passT1), 1, "passT1 must be tier 1");
        assertEq(pass.tierOf(passT2), 2, "passT2 must be tier 2");
        (address royaltyReceiver, uint256 royalty2) = pass.royaltyInfo(passT1, 2 ether);
        assertEq(royaltyReceiver, PASS_TREASURY, "royalty receiver must be pass treasury");
        assertEq(royalty2, 0.1 ether, "live royalty on 2 USDT must be 5% = 0.1 USDT");
        assertEq(market.floorOf(1, MAINNET_USDT), 1 ether, "USDT T1 floor");
        assertEq(market.floorOf(2, address(0)), 0.00254 ether, "BNB T2 floor");

        uint256 sellerUsdt0 = usdt.balanceOf(seller);
        uint256 passTreasuryUsdt0 = usdt.balanceOf(PASS_TREASURY);
        uint256 sellerBnb0 = seller.balance;
        uint256 passTreasuryBnb0 = PASS_TREASURY.balance;

        // ---- Sale 1 (USDT): list T1 @ 2 USDT, buy with maxPrice 2 ----
        vm.prank(seller);
        pass.setApprovalForAll(address(market), true);
        vm.prank(seller);
        market.list(passT1, 2 ether, MAINNET_USDT);
        vm.prank(buyer);
        usdt.approve(address(market), 2 ether);
        vm.prank(buyer);
        market.buy(passT1, 2 ether);

        assertEq(pass.ownerOf(passT1), buyer, "T1 pass must move to buyer");
        // Royalty 5% = 0.1 USDT to the PASS treasury (live royaltyInfo).
        assertEq(
            usdt.balanceOf(PASS_TREASURY) - passTreasuryUsdt0,
            0.1 ether,
            "royalty 0.1 USDT to pass treasury"
        );
        // Fee 1% = 0.02 USDT stays in the market contract.
        assertEq(
            usdt.balanceOf(address(market)), 0.02 ether, "fee 0.02 USDT held in market"
        );
        // Seller nets 94% = 1.88 USDT.
        assertEq(
            usdt.balanceOf(seller) - sellerUsdt0, 1.88 ether, "seller nets 1.88 USDT"
        );
        // Buyer paid exactly 2 USDT.
        assertEq(usdt.balanceOf(buyer), 98 ether, "buyer paid exactly 2 USDT");
        // Listing is gone.
        assertEq(market.listingOf(passT1).seller, address(0), "listing deleted after sale");

        // ---- Sale 2 (BNB): list T2 @ 0.00254 BNB (exact T2 floor) ----
        vm.prank(seller);
        market.list(passT2, 0.00254 ether, address(0));
        vm.prank(buyer);
        market.buy{value: 0.00254 ether}(passT2, 0.00254 ether);

        assertEq(pass.ownerOf(passT2), buyer, "T2 pass must move to buyer");
        // 5% of 0.00254 BNB = 0.000127 BNB royalty to pass treasury.
        assertEq(
            PASS_TREASURY.balance - passTreasuryBnb0,
            0.000127 ether,
            "royalty 0.000127 BNB to pass treasury"
        );
        // 1% of 0.00254 BNB = 0.0000254 BNB fee held in market.
        assertEq(
            address(market).balance, 0.0000254 ether, "fee 0.0000254 BNB held in market"
        );
        // Seller nets 94% = 0.0023876 BNB.
        assertEq(
            seller.balance - sellerBnb0, 0.0023876 ether, "seller nets 0.0023876 BNB"
        );
        assertEq(market.listingOf(passT2).seller, address(0), "listing deleted after sale");

        // ---- Sweep: market treasury pulls both accumulated fees ----
        vm.prank(marketTreasury);
        market.sweepFees(MAINNET_USDT);
        assertEq(usdt.balanceOf(marketTreasury), 0.02 ether, "swept 0.02 USDT fee");
        assertEq(usdt.balanceOf(address(market)), 0, "market USDT balance 0 after sweep");

        vm.prank(marketTreasury);
        market.sweepFees(address(0));
        assertEq(marketTreasury.balance, 0.0000254 ether, "swept 0.0000254 BNB fee");
        assertEq(address(market).balance, 0, "market BNB balance 0 after sweep");
    }

    /// @notice The market's M-1 price protection works against the real
    ///         pass: a buy with maxPrice below the (raised) listing price
    ///         reverts instead of overcharging.
    function test_Fork_MaxPriceProtection() public {
        vm.prank(seller);
        pass.setApprovalForAll(address(market), true);
        vm.prank(seller);
        market.list(passT1, 2 ether, MAINNET_USDT);
        vm.prank(seller);
        market.updatePrice(passT1, 3 ether); // seller raises the price
        vm.prank(buyer);
        usdt.approve(address(market), 3 ether);
        vm.prank(buyer);
        vm.expectRevert(KongMarket.PriceAboveMax.selector);
        market.buy(passT1, 2 ether); // buyer only agreed to 2 USDT
        assertEq(pass.ownerOf(passT1), seller, "pass stays with seller after revert");
    }

    /// @notice A below-floor listing reverts against the real pass tiers.
    function test_Fork_BelowFloorReverts() public {
        vm.prank(seller);
        vm.expectRevert(KongMarket.BelowFloor.selector);
        market.list(passT2, 1 ether, MAINNET_USDT); // T2 floor is 1.5 USDT
    }
}
