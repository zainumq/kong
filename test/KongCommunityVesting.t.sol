// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {KongToken} from "../src/KongToken.sol";
import {KongCommunityVesting} from "../src/KongCommunityVesting.sol";

/// @notice Tests for KongCommunityVesting with the parameterised schedule.
///         Main instance mirrors the mainnet plan (user decision 23 Nov
///         2026): cliff 14 days + linear 16 days = fully vested at
///         deploy + 30 days; allocation 10,000,000 KONG (the vested
///         portion of the 17M community remainder; the other 7M stays
///         liquid). Release rate after the cliff: 625,000 KONG/day.
///         A second instance proves the schedule is genuinely
///         parameterised (cliff 0, duration 30 days).
contract KongCommunityVestingTest is Test {
    KongToken internal token;
    KongCommunityVesting internal vesting;
    address internal beneficiary = makeAddr("beneficiary");
    address internal other = makeAddr("other");

    uint256 internal constant ALLOCATION = 10_000_000 ether;
    uint256 internal constant CLIFF = 14 days;
    uint256 internal constant DURATION = 16 days;
    uint256 internal start;

    function setUp() public {
        vm.warp(1_800_000_000);
        token = new KongToken();
        vesting = new KongCommunityVesting(address(token), beneficiary, CLIFF, DURATION);
        token.transfer(address(vesting), ALLOCATION);
        start = block.timestamp;
    }

    function test_DeploySetsStartAndImmutables() public view {
        assertEq(vesting.startTimestamp(), start);
        assertEq(address(vesting.token()), address(token));
        assertEq(vesting.beneficiary(), beneficiary);
        assertEq(vesting.cliff(), 14 days);
        assertEq(vesting.duration(), 16 days);
    }

    function test_ConstructorRejectsZeroAddressesAndZeroDuration() public {
        vm.expectRevert("token zero");
        new KongCommunityVesting(address(0), beneficiary, CLIFF, DURATION);
        vm.expectRevert("beneficiary zero");
        new KongCommunityVesting(address(token), address(0), CLIFF, DURATION);
        vm.expectRevert("duration zero");
        new KongCommunityVesting(address(token), beneficiary, CLIFF, 0);
    }

    function test_NothingVestedDuringCliff() public {
        // At the deploy block: inside the cliff, nothing vested.
        assertEq(block.timestamp, start);
        assertEq(vesting.vested(), 0);
        assertEq(vesting.releasable(), 0);
        vm.expectRevert(KongCommunityVesting.NothingToRelease.selector);
        vesting.release();

        // One day before the cliff ends: still nothing.
        vm.warp(start + 13 days);
        assertEq(vesting.vested(), 0);
        assertEq(vesting.releasable(), 0);
        vm.expectRevert(KongCommunityVesting.NothingToRelease.selector);
        vesting.release();

        // Exactly at the end of the cliff: elapsed == 0, still nothing.
        vm.warp(start + 14 days);
        assertEq(vesting.vested(), 0);
        assertEq(vesting.releasable(), 0);
        vm.expectRevert(KongCommunityVesting.NothingToRelease.selector);
        vesting.release();

        // One second after the cliff: the linear fraction of one second.
        vm.warp(start + 14 days + 1);
        assertEq(vesting.vested(), ALLOCATION / DURATION);
    }

    function test_LinearDay15FirstDayRate() public {
        // One day into the 16-day linear period: 625,000 KONG.
        vm.warp(start + 15 days);
        assertEq(vesting.vested(), 625_000 ether);
        assertEq(vesting.releasable(), 625_000 ether);
    }

    function test_LinearDay22Halfway() public {
        // Halfway through the linear period (cliff + 8 days): exactly
        // 5,000,000 KONG.
        vm.warp(start + 22 days);
        assertEq(vesting.vested(), 5_000_000 ether);
        assertEq(vesting.releasable(), 5_000_000 ether);
        vesting.release();
        assertEq(token.balanceOf(beneficiary), 5_000_000 ether);
        assertEq(vesting.released(), 5_000_000 ether);
        assertEq(vesting.releasable(), 0);
    }

    function test_LinearDay18Quarter() public {
        // A quarter through the linear period (cliff + 4 days): exactly
        // 2,500,000 KONG.
        vm.warp(start + 18 days);
        assertEq(vesting.vested(), 2_500_000 ether);
        assertEq(vesting.releasable(), 2_500_000 ether);
    }

    function test_PartialThenFull() public {
        // Day 22: release the first 5M.
        vm.warp(start + 22 days);
        assertEq(vesting.releasable(), 5_000_000 ether);
        vesting.release();
        assertEq(token.balanceOf(beneficiary), 5_000_000 ether);
        // Day 30 (cliff + 16 days): the remaining 5M.
        vm.warp(start + 30 days);
        assertEq(vesting.vested(), ALLOCATION);
        assertEq(vesting.releasable(), 5_000_000 ether);
        vesting.release();
        assertEq(token.balanceOf(beneficiary), ALLOCATION);
        assertEq(token.balanceOf(address(vesting)), 0);
        // Nothing left to release.
        vm.expectRevert(KongCommunityVesting.NothingToRelease.selector);
        vesting.release();
    }

    function test_FullVestAtEndAndBeyond() public {
        // Way past the end: vested stays capped at the allocation.
        vm.warp(start + 30 days + 365 days);
        assertEq(vesting.vested(), ALLOCATION);
        assertEq(vesting.releasable(), ALLOCATION);
        vesting.release();
        assertEq(token.balanceOf(beneficiary), ALLOCATION);
    }

    function test_ReleaseCallableByAnyone() public {
        vm.warp(start + 30 days);
        vm.prank(other);
        vesting.release();
        assertEq(token.balanceOf(beneficiary), ALLOCATION);
        assertEq(token.balanceOf(other), 0);
    }

    function test_TotalAllocatedAccounting() public {
        assertEq(vesting.totalAllocated(), ALLOCATION);
        // After a partial release, totalAllocated is unchanged.
        vm.warp(start + 22 days);
        vesting.release();
        assertEq(vesting.totalAllocated(), ALLOCATION);
        assertEq(token.balanceOf(address(vesting)) + vesting.released(), ALLOCATION);
        // After full release, totalAllocated is still the allocation.
        vm.warp(start + 30 days);
        vesting.release();
        assertEq(vesting.totalAllocated(), ALLOCATION);
    }

    function test_ParameterisedScheduleSecondInstance() public {
        // A second instance with a DIFFERENT schedule proves the
        // cliff/duration are genuine deploy-time parameters, not
        // constants: cliff 0, duration 30 days, 9,000,000 KONG.
        uint256 secondAllocation = 9_000_000 ether;
        KongCommunityVesting second = new KongCommunityVesting(
            address(token), beneficiary, 0, 30 days
        );
        token.transfer(address(second), secondAllocation);
        assertEq(second.cliff(), 0);
        assertEq(second.duration(), 30 days);
        assertEq(second.startTimestamp(), start);

        // At the deploy block with cliff 0: elapsed == 0, nothing vested.
        assertEq(second.vested(), 0);
        vm.expectRevert(KongCommunityVesting.NothingToRelease.selector);
        second.release();

        // Halfway through its 30-day linear period: exactly 4,500,000.
        vm.warp(start + 15 days);
        assertEq(second.vested(), 4_500_000 ether);
        assertEq(second.releasable(), 4_500_000 ether);

        // End of its schedule: the full 9,000,000.
        vm.warp(start + 30 days);
        assertEq(second.vested(), secondAllocation);
        second.release();
        assertEq(token.balanceOf(beneficiary), secondAllocation);
        assertEq(token.balanceOf(address(second)), 0);

        // The main instance is unaffected by the second one.
        assertEq(vesting.cliff(), 14 days);
        assertEq(vesting.duration(), 16 days);
    }
}
