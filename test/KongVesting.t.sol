// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {KongToken} from "../src/KongToken.sol";
import {KongVesting} from "../src/KongVesting.sol";

/// @notice Tests for KongVesting: 90-day cliff, then linear over 365 days.
contract KongVestingTest is Test {
    KongToken internal token;
    KongVesting internal vesting;
    address internal beneficiary = makeAddr("beneficiary");
    address internal other = makeAddr("other");

    uint256 internal constant ALLOCATION = 100_000_000 ether;
    uint256 internal start;

    function setUp() public {
        vm.warp(1_800_000_000);
        token = new KongToken();
        // This test contract plays the sale role.
        vesting = new KongVesting(address(token), beneficiary, address(this));
        token.transfer(address(vesting), ALLOCATION);
        start = block.timestamp;
    }

    function test_NotStarted() public {
        assertEq(vesting.startTimestamp(), 0);
        assertEq(vesting.releasable(), 0);
        assertEq(vesting.vested(), 0);
        vm.expectRevert(KongVesting.NotStarted.selector);
        vesting.release();
    }

    function test_StartAccess() public {
        vm.prank(other);
        vm.expectRevert(KongVesting.OnlySale.selector);
        vesting.start(block.timestamp);
        vesting.start(block.timestamp);
        assertEq(vesting.startTimestamp(), start);
        vm.expectRevert(KongVesting.AlreadyStarted.selector);
        vesting.start(block.timestamp);
    }

    function test_CliffReleasesNothing() public {
        vesting.start(start);
        // Just before the cliff ends: nothing vested.
        vm.warp(start + 90 days - 1);
        assertEq(vesting.releasable(), 0);
        vm.expectRevert(KongVesting.NothingToRelease.selector);
        vesting.release();
        // Exactly at the cliff: still nothing (linear starts after cliff).
        vm.warp(start + 90 days);
        assertEq(vesting.releasable(), 0);
    }

    function test_LinearHalfway() public {
        vesting.start(start);
        // Halfway through the 365-day linear period: exactly 50%.
        vm.warp(start + 90 days + 182 days + 12 hours);
        assertEq(vesting.vested(), 50_000_000 ether);
        assertEq(vesting.releasable(), 50_000_000 ether);
        vesting.release();
        assertEq(token.balanceOf(beneficiary), 50_000_000 ether);
        assertEq(vesting.released(), 50_000_000 ether);
        assertEq(vesting.releasable(), 0);
    }

    function test_PartialThenFull() public {
        vesting.start(start);
        // 25% through: 25M releasable.
        vm.warp(start + 90 days + 91 days + 6 hours); // 91.25 days = 1/4 of 365
        assertEq(vesting.releasable(), 25_000_000 ether);
        vesting.release();
        assertEq(token.balanceOf(beneficiary), 25_000_000 ether);
        // End of vesting: the remaining 75M.
        vm.warp(start + 90 days + 365 days);
        assertEq(vesting.vested(), ALLOCATION);
        assertEq(vesting.releasable(), 75_000_000 ether);
        vesting.release();
        assertEq(token.balanceOf(beneficiary), ALLOCATION);
        assertEq(token.balanceOf(address(vesting)), 0);
        // Nothing left to release.
        vm.expectRevert(KongVesting.NothingToRelease.selector);
        vesting.release();
    }

    function test_ReleaseCallableByAnyone() public {
        vesting.start(start);
        vm.warp(start + 90 days + 365 days);
        vm.prank(other);
        vesting.release();
        assertEq(token.balanceOf(beneficiary), ALLOCATION);
    }
}
