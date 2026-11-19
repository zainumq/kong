// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {KongToken} from "../src/KongToken.sol";
import {KongMintPass} from "../src/KongMintPass.sol";
import {KongSale} from "../src/KongSale.sol";
import {KongVesting} from "../src/KongVesting.sol";
import {MockUSDT, MockAgentID, MockRouter} from "./mocks/Mocks.sol";

/// @notice Referral test suite: on-chain referral rewards (3% of the
///         referred buyer's claimable KONG per share), paid from a 15M
///         KONG pool after graduation only.
contract KongReferralTest is Test {
    KongToken internal token;
    MockUSDT internal usdt;
    MockAgentID internal agentId;
    MockRouter internal router;
    KongSale internal sale;
    KongMintPass internal pass;

    address internal treasury = makeAddr("treasury");
    address internal team = makeAddr("team");
    address internal community = makeAddr("community");
    address internal referrer = makeAddr("referrer");
    address internal buyer1 = makeAddr("buyer1");
    address internal buyer2 = makeAddr("buyer2");
    address internal noPass = makeAddr("noPass");

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

        // Deployer funding step (mirrors the README deploy steps):
        // 750M to the sale (485M claims + 250M liquidity + 15M referral
        // pool), 100M to each vesting, 50M to community.
        token.transfer(address(sale), 750_000_000 ether);
        token.transfer(address(sale.treasuryVesting()), 100_000_000 ether);
        token.transfer(address(sale.teamVesting()), 100_000_000 ether);
        token.transfer(community, 50_000_000 ether);

        // Fund the named wallets: USDT + Agent ID + approval.
        address[4] memory wallets = [referrer, buyer1, buyer2, noPass];
        for (uint256 i = 0; i < wallets.length; ++i) {
            usdt.mint(wallets[i], 1_000_000e18);
            agentId.setBalance(wallets[i], 1);
            vm.prank(wallets[i]);
            usdt.approve(address(sale), type(uint256).max);
        }
    }

    // ---- Helpers ----

    function freshBuyer() internal returns (address b) {
        buyerNonce += 1;
        b = address(uint160(0x40000 + buyerNonce));
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

    /// @notice Same as fillTo, but every purchase names `ref` as referrer.
    function fillToWithReferrer(uint256 target, address ref) internal {
        while (sale.sharesSold() < target) {
            uint256 remaining = target - sale.sharesSold();
            uint256 amount = remaining > 10 ? 10 : remaining;
            address b = freshBuyer();
            vm.prank(b);
            sale.mintPass(amount, ref);
        }
    }

    function buy(address buyer, uint256 amount) internal {
        vm.prank(buyer);
        sale.mintPass(amount, address(0));
    }

    function buyRef(address buyer, uint256 amount, address ref) internal {
        vm.prank(buyer);
        sale.mintPass(amount, ref);
    }

    // ---- Per-tier rewards ----

    function test_ReferralOfShareViews() public view {
        assertEq(sale.referralOfShare(1), 1_800 ether);
        assertEq(sale.referralOfShare(2_500), 1_800 ether);
        assertEq(sale.referralOfShare(2_501), 1_500 ether);
        assertEq(sale.referralOfShare(6_000), 1_500 ether);
        assertEq(sale.referralOfShare(6_001), 1_200 ether);
        assertEq(sale.referralOfShare(10_000), 1_200 ether);
        assertEq(sale.REFERRAL_POOL(), 15_000_000 ether);
        assertEq(sale.SALE_FUNDING(), 750_000_000 ether);
    }

    /// @notice Referrer with a pass earns the exact per-tier amounts:
    ///         1,800 (T1) / 1,500 (T2) / 1,200 (T3) KONG per share.
    function test_ReferralEarnsPerTier() public {
        buy(referrer, 1); // share 1, Tier 1 — referrer now holds a pass
        assertEq(sale.referralEarned(referrer), 0); // own mint earns nothing

        buyRef(buyer1, 1, referrer); // share 2, Tier 1
        assertEq(sale.referralEarned(referrer), 1_800 ether);
        assertEq(sale.totalReferralEarned(), 1_800 ether);
        assertEq(sale.referralClaimable(referrer), 0); // not graduated

        fillTo(2_500);
        buyRef(buyer2, 1, referrer); // share 2501, Tier 2
        assertEq(sale.referralEarned(referrer), 1_800 ether + 1_500 ether);
        assertEq(sale.totalReferralEarned(), 3_300 ether);

        fillTo(6_000);
        address b = freshBuyer();
        buyRef(b, 1, referrer); // share 6001, Tier 3
        assertEq(sale.referralEarned(referrer), 4_500 ether);
        assertEq(sale.totalReferralEarned(), 4_500 ether);
    }

    // ---- Referrer rules ----

    function test_SelfReferralReverts() public {
        buy(referrer, 1);
        vm.prank(referrer);
        vm.expectRevert(KongSale.SelfReferral.selector);
        sale.mintPass(1, referrer);
        // Self-referral reverts even for a buyer who holds no pass yet.
        vm.prank(buyer1);
        vm.expectRevert(KongSale.SelfReferral.selector);
        sale.mintPass(1, buyer1);
        assertEq(sale.sharesSold(), 1); // no state change
    }

    /// @notice A referrer holding no pass is silently ignored: the mint
    ///         succeeds, no reward accrues, no revert.
    function test_ReferrerWithoutPass() public {
        buyRef(buyer1, 1, noPass); // noPass holds no pass
        assertEq(sale.sharesSold(), 1);
        assertEq(pass.ownerOf(1), buyer1);
        assertEq(sale.referralEarned(noPass), 0);
        assertEq(sale.totalReferralEarned(), 0);

        // Same for a referrer who HELD a pass but transferred it away:
        // balanceOf 0 at mint time means no reward.
        buy(referrer, 1);
        vm.prank(referrer);
        pass.transferFrom(referrer, buyer2, 2);
        assertEq(pass.balanceOf(referrer), 0);
        buyRef(buyer2, 1, referrer);
        assertEq(sale.referralEarned(referrer), 0);
    }

    function test_ZeroAddressReferrer() public {
        buy(buyer1, 2);
        assertEq(sale.referralEarned(address(0)), 0);
        assertEq(sale.totalReferralEarned(), 0);
    }

    /// @notice A purchase spanning the Tier 1 -> Tier 2 boundary accrues
    ///         per share: 2 x 1,800 + 3 x 1,500 = 8,100 KONG.
    function test_ReferralSpanningTiers() public {
        buy(referrer, 1); // share 1
        fillTo(2_498);
        buyRef(buyer1, 5, referrer); // shares 2499-2503
        assertEq(sale.referralEarned(referrer), 8_100 ether);
        assertEq(sale.totalReferralEarned(), 8_100 ether);
    }

    /// @notice Multi-share purchase in one tier accrues per share.
    function test_ReferralMultiShare() public {
        buy(referrer, 1);
        buyRef(buyer1, 10, referrer); // 10 x Tier 1
        assertEq(sale.referralEarned(referrer), 18_000 ether);
    }

    // ---- Fuzz: accrual matches the per-share schedule ----

    function testFuzz_ReferralAccrual(uint256 fillLevel, uint256 amount) public {
        fillLevel = bound(fillLevel, 0, 100);
        amount = bound(amount, 1, 10);
        buy(referrer, 1); // share 1, referrer established
        fillTo(fillLevel);
        uint256 start = sale.sharesSold();
        uint256 expected;
        for (uint256 i = 0; i < amount; ++i) {
            expected += sale.referralOfShare(start + 1 + i);
        }
        buyRef(buyer1, amount, referrer);
        assertEq(sale.referralEarned(referrer), expected);
        assertEq(sale.totalReferralEarned(), expected);
    }

    // ---- Claims ----

    function test_ClaimReferralBeforeGraduation() public {
        buy(referrer, 1);
        buyRef(buyer1, 1, referrer);
        assertEq(sale.referralEarned(referrer), 1_800 ether);
        vm.prank(referrer);
        vm.expectRevert(KongSale.NotGraduated.selector);
        sale.claimReferral();
        assertEq(sale.referralEarned(referrer), 1_800 ether); // unchanged
    }

    /// @notice Full happy path: referrer earns, sale graduates, exact payout.
    function test_ClaimReferralAfterGraduation() public {
        buy(referrer, 10); // shares 1-10
        buyRef(buyer1, 10, referrer); // shares 11-20, Tier 1: 10 x 1,800
        assertEq(sale.referralEarned(referrer), 18_000 ether);
        fillTo(10_000);
        sale.graduate();

        assertEq(sale.referralClaimable(referrer), 18_000 ether);
        vm.prank(referrer);
        sale.claimReferral();
        assertEq(token.balanceOf(referrer), 18_000 ether);
        assertEq(sale.referralEarned(referrer), 0);
        assertEq(sale.referralClaimable(referrer), 0);
        // totalReferralEarned is ever-accrued accounting: unchanged by claims.
        assertEq(sale.totalReferralEarned(), 18_000 ether);

        // A wallet with nothing accrued cannot claim.
        vm.prank(buyer2);
        vm.expectRevert(KongSale.NothingToClaim.selector);
        sale.claimReferral();
    }

    /// @notice Double-claim reverts (first claim zeroes the balance).
    function test_ClaimReferralDoubleClaim() public {
        buy(referrer, 1);
        buyRef(buyer1, 1, referrer);
        fillTo(10_000);
        sale.graduate();
        vm.prank(referrer);
        sale.claimReferral();
        assertEq(token.balanceOf(referrer), 1_800 ether);
        vm.prank(referrer);
        vm.expectRevert(KongSale.NothingToClaim.selector);
        sale.claimReferral();
    }

    /// @notice The referrer does NOT need to still hold a pass to claim:
    ///         rewards were earned at mint time.
    function test_ClaimReferralAfterSellingPass() public {
        buy(referrer, 1);
        buyRef(buyer1, 1, referrer);
        vm.prank(referrer);
        pass.transferFrom(referrer, buyer2, 1);
        assertEq(pass.balanceOf(referrer), 0);
        fillTo(10_000);
        sale.graduate();
        vm.prank(referrer);
        sale.claimReferral();
        assertEq(token.balanceOf(referrer), 1_800 ether);
    }

    // ---- Failed sale: referral rewards are void ----

    function test_ReferralVoidOnFailedSale() public {
        buy(referrer, 1);
        buyRef(buyer1, 1, referrer);
        assertEq(sale.referralEarned(referrer), 1_800 ether);

        // Deadline passes without selling out: referral claim still closed.
        vm.warp(sale.saleDeadline() + 1);
        vm.prank(referrer);
        vm.expectRevert(KongSale.NotGraduated.selector);
        sale.claimReferral();
        assertEq(sale.referralClaimable(referrer), 0);

        // Even after the refund window + sweep, referral claims stay closed.
        vm.warp(sale.refundDeadline());
        sale.sweepUnclaimed();
        vm.prank(referrer);
        vm.expectRevert(KongSale.NotGraduated.selector);
        sale.claimReferral();
    }

    // ---- Pool accounting: maximum possible payout ----

    /// @notice Worst case: every share except the referrer's own first 10
    ///         is bought with a referrer. Total earned must be exactly
    ///         14.55M - 18,000 = 14,532,000 KONG, below the 15M pool, and
    ///         graduation + the full referral claim must still succeed.
    function test_ReferralPoolMaxPayout() public {
        buy(referrer, 10); // shares 1-10, no referrer
        fillToWithReferrer(10_000, referrer); // shares 11-10,000 referred
        assertEq(sale.sharesSold(), 10_000);
        assertEq(sale.totalReferralEarned(), 14_532_000 ether);
        assertTrue(sale.totalReferralEarned() <= sale.REFERRAL_POOL());

        sale.graduate();
        // Sale holds 500M after graduation (485M claims + 15M pool).
        assertEq(token.balanceOf(address(sale)), 500_000_000 ether);

        vm.prank(referrer);
        sale.claimReferral();
        assertEq(token.balanceOf(referrer), 14_532_000 ether);
        // Leftover pool (15M - 14.532M = 468,000) stays in the sale,
        // locked with the unclaimed claim reserve.
        assertEq(token.balanceOf(address(sale)), 500_000_000 ether - 14_532_000 ether);
    }
}
