// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {KongToken} from "../src/KongToken.sol";
import {KongMintPass} from "../src/KongMintPass.sol";
import {KongSale} from "../src/KongSale.sol";
import {KongVesting} from "../src/KongVesting.sol";
import {MockUSDT, MockAgentID, MockRouter} from "./mocks/Mocks.sol";

/// @notice Main test suite for the $KONG bonding-curve sale.
contract KongSaleTest is Test {
    KongToken internal token;
    MockUSDT internal usdt;
    MockAgentID internal agentId;
    MockRouter internal router;
    KongSale internal sale;
    KongMintPass internal pass;
    KongVesting internal treasuryVesting;
    KongVesting internal teamVesting;

    address internal treasury = makeAddr("treasury");
    address internal team = makeAddr("team");
    address internal community = makeAddr("community");
    address internal buyer1 = makeAddr("buyer1");
    address internal buyer2 = makeAddr("buyer2");
    address internal buyer3 = makeAddr("buyer3");
    address internal noId = makeAddr("noId");

    string internal constant IMG1 = "https://kong.example/art/tier1.png";
    string internal constant IMG2 = "https://kong.example/art/tier2.png";
    string internal constant IMG3 = "https://kong.example/art/tier3.png";

    uint256 internal buyerNonce;

    function setUp() public {
        vm.warp(1_800_000_000); // fixed start time
        token = new KongToken();
        usdt = new MockUSDT();
        agentId = new MockAgentID();
        router = new MockRouter();
        sale = new KongSale(
            address(token),
            address(usdt),
            address(agentId),
            address(router),
            treasury,
            team,
            community,
            block.timestamp,
            IMG1,
            IMG2,
            IMG3
        );
        pass = sale.pass();
        treasuryVesting = sale.treasuryVesting();
        teamVesting = sale.teamVesting();

        // Deployer funding step (mirrors the README deploy steps).
        token.transfer(address(sale), 750_000_000 ether);
        token.transfer(address(treasuryVesting), 100_000_000 ether);
        token.transfer(address(teamVesting), 100_000_000 ether);
        token.transfer(community, 50_000_000 ether);

        // Fund the named buyers: USDT + Agent ID + approval.
        address[3] memory buyers = [buyer1, buyer2, buyer3];
        for (uint256 i = 0; i < buyers.length; ++i) {
            usdt.mint(buyers[i], 1_000_000e18);
            agentId.setBalance(buyers[i], 1);
            vm.prank(buyers[i]);
            usdt.approve(address(sale), type(uint256).max);
        }
        // noId gets USDT + approval but NO Agent ID.
        usdt.mint(noId, 1_000_000e18);
        vm.prank(noId);
        usdt.approve(address(sale), type(uint256).max);
    }

    // ---- Helpers ----

    function freshBuyer() internal returns (address b) {
        buyerNonce += 1;
        b = address(uint160(0x10000 + buyerNonce));
        usdt.mint(b, 1_000_000e18);
        agentId.setBalance(b, 1);
        vm.prank(b);
        usdt.approve(address(sale), type(uint256).max);
    }

    /// @notice Mint from fresh wallets (10 each) until `target` shares sold.
    function fillTo(uint256 target) internal {
        while (sale.sharesSold() < target) {
            uint256 remaining = target - sale.sharesSold();
            uint256 amount = remaining > 10 ? 10 : remaining;
            address b = freshBuyer();
            vm.prank(b);
            sale.mintPass(amount, address(0));
        }
    }

    function buy(address buyer, uint256 amount) internal {
        vm.prank(buyer);
        sale.mintPass(amount, address(0));
    }

    // ---- Deployment & wiring ----

    function test_DeploymentWiring() public view {
        assertEq(address(sale.kong()), address(token));
        assertEq(address(sale.usdt()), address(usdt));
        assertEq(address(sale.agentId()), address(agentId));
        assertEq(address(sale.router()), address(router));
        assertEq(sale.treasury(), treasury);
        assertEq(sale.team(), team);
        assertEq(sale.community(), community);
        assertEq(sale.saleStart(), block.timestamp);
        assertEq(sale.saleDeadline(), block.timestamp + 30 days);
        assertEq(sale.refundDeadline(), block.timestamp + 44 days);
        assertEq(pass.sale(), address(sale));
        assertEq(pass.nextTokenId(), 1);
        assertEq(token.balanceOf(address(sale)), 750_000_000 ether);
        assertEq(token.balanceOf(address(treasuryVesting)), 100_000_000 ether);
        assertEq(token.balanceOf(address(teamVesting)), 100_000_000 ether);
        assertEq(token.balanceOf(community), 50_000_000 ether);
        assertEq(token.balanceOf(address(this)), 0);
        assertTrue(sale.saleActive());
        assertFalse(sale.graduated());
    }

    // ---- Tier pricing & boundaries ----

    function test_PriceOfShareBoundaries() public view {
        assertEq(sale.priceOfShare(1), 1e18);
        assertEq(sale.priceOfShare(2_500), 1e18);
        assertEq(sale.priceOfShare(2_501), 1.5e18);
        assertEq(sale.priceOfShare(6_000), 1.5e18);
        assertEq(sale.priceOfShare(6_001), 2e18);
        assertEq(sale.priceOfShare(10_000), 2e18);
        assertEq(sale.tierOfShare(1), 1);
        assertEq(sale.tierOfShare(2_500), 1);
        assertEq(sale.tierOfShare(2_501), 2);
        assertEq(sale.tierOfShare(6_000), 2);
        assertEq(sale.tierOfShare(6_001), 3);
        assertEq(sale.tierOfShare(10_000), 3);
        assertEq(sale.tokensOfShare(1), 60_000 ether);
        assertEq(sale.tokensOfShare(2_501), 50_000 ether);
        assertEq(sale.tokensOfShare(6_001), 40_000 ether);
    }

    function testFuzz_PriceOfShare(uint256 n) public view {
        n = bound(n, 1, 10_000);
        uint256 price = sale.priceOfShare(n);
        if (n <= 2_500) assertEq(price, 1e18);
        else if (n <= 6_000) assertEq(price, 1.5e18);
        else assertEq(price, 2e18);
    }

    function test_Quote() public view {
        assertEq(sale.quote(1), 1e18);
        assertEq(sale.quote(10), 10e18);
    }

    /// @notice A single purchase spanning the Tier 1 -> Tier 2 boundary is
    ///         priced per share, and each pass records its own tier.
    function test_MintSpanningTierBoundary() public {
        fillTo(2_498);
        assertEq(sale.quote(5), 2 * 1e18 + 3 * 1.5e18); // 6.5 USDT
        uint256 balBefore = usdt.balanceOf(buyer1);
        buy(buyer1, 5);
        assertEq(balBefore - usdt.balanceOf(buyer1), 6.5e18);
        assertEq(sale.sharesSold(), 2_503);
        // Shares 2499, 2500 = Tier 1; 2501, 2502, 2503 = Tier 2.
        assertEq(pass.tierOf(2_499), 1);
        assertEq(pass.tierOf(2_500), 1);
        assertEq(pass.tierOf(2_501), 2);
        assertEq(pass.tierOf(2_502), 2);
        assertEq(pass.tierOf(2_503), 2);
        assertEq(sale.paidFor(2_499), 1e18);
        assertEq(sale.paidFor(2_500), 1e18);
        assertEq(sale.paidFor(2_501), 1.5e18);
        assertEq(sale.paidFor(2_503), 1.5e18);
    }

    /// @notice Actual mint at the Tier 2 -> Tier 3 boundary (share 6001).
    function test_MintAtTier3Boundary() public {
        fillTo(6_000);
        buy(buyer1, 1);
        assertEq(pass.tierOf(6_001), 3);
        assertEq(sale.paidFor(6_001), 2e18);
        assertEq(sale.sharesSold(), 6_001);
    }

    // ---- Mint rules ----

    function test_MintBasic() public {
        buy(buyer1, 1);
        assertEq(sale.sharesSold(), 1);
        assertEq(sale.totalRaised(), 1e18);
        assertEq(pass.ownerOf(1), buyer1);
        assertEq(pass.tierOf(1), 1);
        assertEq(sale.paidFor(1), 1e18);
        assertEq(sale.mintedByWallet(buyer1), 1);
        assertEq(usdt.balanceOf(address(sale)), 1e18);
    }

    function test_MaxPerWallet() public {
        buy(buyer1, 10);
        vm.prank(buyer1);
        vm.expectRevert(KongSale.ExceedsWalletCap.selector);
        sale.mintPass(1, address(0));
        vm.prank(buyer2);
        vm.expectRevert(KongSale.InvalidAmount.selector);
        sale.mintPass(11, address(0));
        vm.prank(buyer2);
        vm.expectRevert(KongSale.InvalidAmount.selector);
        sale.mintPass(0, address(0));
    }

    function test_AgentIdGate() public {
        vm.prank(noId);
        vm.expectRevert(KongSale.NoAgentId.selector);
        sale.mintPass(1, address(0));
    }

    function test_MintBeforeStart() public {
        KongSale future = new KongSale(
            address(token),
            address(usdt),
            address(agentId),
            address(router),
            treasury,
            team,
            community,
            block.timestamp + 1 days,
            IMG1,
            IMG2,
            IMG3
        );
        vm.prank(buyer1);
        usdt.approve(address(future), type(uint256).max);
        vm.prank(buyer1);
        vm.expectRevert(KongSale.SaleNotStarted.selector);
        future.mintPass(1, address(0));
        vm.warp(block.timestamp + 1 days);
        vm.prank(buyer1);
        future.mintPass(1, address(0));
        assertEq(future.sharesSold(), 1);
    }

    function test_MintAfterDeadline() public {
        vm.warp(sale.saleDeadline());
        vm.prank(buyer1);
        vm.expectRevert(KongSale.SaleEnded.selector);
        sale.mintPass(1, address(0));
    }

    // ---- Graduation ----

    function test_GraduateBeforeSoldOut() public {
        buy(buyer1, 10);
        vm.expectRevert(KongSale.NotSoldOut.selector);
        sale.graduate();
    }

    function test_GraduationSplit() public {
        buy(buyer1, 10); // tokens 1-10, Tier 1
        fillTo(10_000);
        assertEq(sale.sharesSold(), 10_000);
        assertEq(sale.totalRaised(), 15_750e18); // full raise, exact

        sale.graduate();

        assertTrue(sale.graduated());
        // Router received exactly 250M KONG + 12,600 USDT for the pool.
        assertEq(router.calls(), 1);
        assertEq(router.lastTokenA(), address(token));
        assertEq(router.lastTokenB(), address(usdt));
        assertEq(router.lastAmountA(), 250_000_000 ether);
        assertEq(router.lastAmountB(), 12_600e18);
        assertEq(router.lastTo(), 0x000000000000000000000000000000000000dEaD);
        assertEq(token.balanceOf(address(router)), 250_000_000 ether);
        assertEq(usdt.balanceOf(address(router)), 12_600e18);
        // Treasury received exactly 20% = 3,150 USDT.
        assertEq(usdt.balanceOf(treasury), 3_150e18);
        assertEq(usdt.balanceOf(address(sale)), 0);
        // Claims reserve + referral pool untouched: 485M + 15M = 500M KONG
        // still in the sale (250M went to the pool).
        assertEq(token.balanceOf(address(sale)), 500_000_000 ether);
        // Vesting clocks started at graduation.
        assertEq(treasuryVesting.startTimestamp(), block.timestamp);
        assertEq(teamVesting.startTimestamp(), block.timestamp);

        // Graduate is one-shot; minting is closed; refunds are closed.
        vm.expectRevert(KongSale.AlreadyGraduated.selector);
        sale.graduate();
        vm.prank(buyer2);
        vm.expectRevert(KongSale.SaleSoldOut.selector);
        sale.mintPass(1, address(0));
        vm.warp(sale.saleDeadline() + 1);
        vm.prank(buyer1);
        vm.expectRevert(KongSale.RefundNotActive.selector);
        sale.refund(1);
    }

    // ---- Claims ----

    function test_ClaimBeforeGraduation() public {
        buy(buyer1, 1);
        vm.prank(buyer1);
        vm.expectRevert(KongSale.NotGraduated.selector);
        sale.claim(1);
    }

    /// @notice Full happy path: fill, graduate, claim T1/T2/T3 passes with
    ///         exact token amounts, transfer-then-claim, batch claim.
    function test_ClaimAfterGraduation() public {
        buy(buyer1, 10); // tokens 1-10, Tier 1
        fillTo(2_500);
        buy(buyer2, 10); // tokens 2501-2510, Tier 2
        fillTo(6_000);
        buy(buyer3, 10); // tokens 6001-6010, Tier 3
        fillTo(10_000);
        sale.graduate();

        // Tier 1 claim: 60,000 KONG.
        vm.prank(buyer1);
        sale.claim(1);
        assertEq(token.balanceOf(buyer1), 60_000 ether);
        // Tier 2 claim: 50,000 KONG.
        vm.prank(buyer2);
        sale.claim(2_501);
        assertEq(token.balanceOf(buyer2), 50_000 ether);
        // Tier 3 claim: 40,000 KONG.
        vm.prank(buyer3);
        sale.claim(6_001);
        assertEq(token.balanceOf(buyer3), 40_000 ether);

        // Double-claim reverts (pass burned).
        vm.prank(buyer1);
        vm.expectRevert();
        sale.claim(1);
        // Non-owner cannot claim.
        vm.prank(buyer2);
        vm.expectRevert(KongSale.NotPassOwner.selector);
        sale.claim(2);

        // Transfer then claim: the new owner claims, not the minter.
        vm.prank(buyer1);
        pass.transferFrom(buyer1, buyer2, 2);
        vm.prank(buyer2);
        sale.claim(2);
        assertEq(token.balanceOf(buyer2), 50_000 ether + 60_000 ether);

        // Batch claim: buyer1 claims tokens 3..10 (8 x 60,000).
        uint256[] memory ids = new uint256[](8);
        for (uint256 i = 0; i < 8; ++i) ids[i] = 3 + i;
        vm.prank(buyer1);
        sale.claimMany(ids);
        assertEq(token.balanceOf(buyer1), 9 * 60_000 ether);
    }

    // ---- Refunds ----

    function test_RefundBeforeDeadline() public {
        buy(buyer1, 1);
        vm.prank(buyer1);
        vm.expectRevert(KongSale.RefundNotActive.selector);
        sale.refund(1);
    }

    /// @notice Full refund path: partial sale, deadline passes, exact 100%
    ///         refunds per tier, window closes, sweep to treasury.
    function test_RefundFlow() public {
        buy(buyer1, 10); // tokens 1-10, Tier 1 @ 1 USDT
        fillTo(2_500);
        buy(buyer2, 10); // tokens 2501-2510, Tier 2 @ 1.5 USDT
        assertEq(sale.totalRaised(), 2_500e18 + 15e18); // 2,515 USDT

        // Sweep too early reverts (window not closed).
        vm.warp(sale.saleDeadline() + 1);
        vm.expectRevert(KongSale.RefundWindowClosed.selector);
        sale.sweepUnclaimed();
        assertTrue(sale.refundActive());

        // Tier 1 refund: exactly 1 USDT back.
        uint256 b1Before = usdt.balanceOf(buyer1);
        vm.prank(buyer1);
        sale.refund(1);
        assertEq(usdt.balanceOf(buyer1) - b1Before, 1e18);
        // Tier 2 refund: exactly 1.5 USDT back.
        uint256 b2Before = usdt.balanceOf(buyer2);
        vm.prank(buyer2);
        sale.refund(2_501);
        assertEq(usdt.balanceOf(buyer2) - b2Before, 1.5e18);
        // Batch refund: tokens 2,3 -> 2 USDT.
        uint256[] memory ids = new uint256[](2);
        ids[0] = 2;
        ids[1] = 3;
        vm.prank(buyer1);
        sale.refundMany(ids);
        assertEq(usdt.balanceOf(buyer1) - b1Before, 3e18);

        // Double-refund reverts (pass burned).
        vm.prank(buyer1);
        vm.expectRevert();
        sale.refund(1);

        // Window closes: refunds revert, sweep sends the rest to treasury.
        vm.warp(sale.refundDeadline());
        assertFalse(sale.refundActive());
        vm.prank(buyer1);
        vm.expectRevert(KongSale.RefundNotActive.selector);
        sale.refund(4);

        // Refunded so far: 1 + 1.5 + 2 = 4.5 USDT. Rest: 2,510.5 USDT.
        sale.sweepUnclaimed();
        assertTrue(sale.swept());
        assertEq(usdt.balanceOf(treasury), 2510.5e18);
        assertEq(usdt.balanceOf(address(sale)), 0);
        vm.expectRevert(KongSale.AlreadySwept.selector);
        sale.sweepUnclaimed();
    }

    /// @notice A sale that sells out exactly at the deadline edge still
    ///         graduates (deadline only blocks minting, not graduation).
    function test_GraduateAfterDeadline() public {
        fillTo(10_000);
        vm.warp(sale.saleDeadline() + 1 days);
        sale.graduate();
        assertTrue(sale.graduated());
    }
}
