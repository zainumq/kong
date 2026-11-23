// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {KongToken} from "../src/KongToken.sol";
import {KongMerkleDistributor} from "../src/KongMerkleDistributor.sol";

/// @title KongMerkleDistributor tests
/// @notice Builds a real 4-leaf Merkle tree in-test with the SAME
///         sorted-pair hashing OpenZeppelin's MerkleProof uses, so the
///         tests prove the on-chain verification matches the documented
///         leaf format:
///           leaf = keccak256(abi.encodePacked(index, account,
///                                             airdrop, bonus, streak))
///         parent = keccak256(min(a,b) ++ max(a,b))
contract KongMerkleDistributorTest is Test {
    KongToken internal token;
    KongMerkleDistributor internal distributor;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal carol = address(0xCA901);
    address internal dave = address(0xDA9E);

    // Leaf amounts (in whole KONG, 18 decimals): index, account, airdrop, bonus, streak
    uint256[4] internal airdrops = [uint256(10_000 ether), 20_000 ether, 5_000 ether, 0];
    uint256[4] internal bonuses = [uint256(120_000 ether), 0, 80_000 ether, 40_000 ether];
    uint256[4] internal streaks = [uint256(3_000 ether), 1_500 ether, 0, 2_500 ether];

    bytes32 internal root;
    bytes32[4] internal leaves;
    bytes32 internal h01;
    bytes32 internal h23;

    uint256 internal constant FUNDING = 33_000_000 ether;

    function setUp() public {
        token = new KongToken();
        distributor = new KongMerkleDistributor(address(token));
        // Fund the distributor with the full 33M, as on mainnet.
        token.transfer(address(distributor), FUNDING);

        // Build the 4-leaf tree.
        address[4] memory accounts = [alice, bob, carol, dave];
        for (uint256 i = 0; i < 4; i++) {
            leaves[i] = _leaf(i, accounts[i], airdrops[i], bonuses[i], streaks[i]);
        }
        h01 = _pair(leaves[0], leaves[1]);
        h23 = _pair(leaves[2], leaves[3]);
        root = _pair(h01, h23);
    }

    // --- tree helpers (mirror OZ MerkleProof sorted-pair hashing) ---

    function _leaf(
        uint256 index,
        address account,
        uint256 airdrop,
        uint256 bonus,
        uint256 streak
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(index, account, airdrop, bonus, streak));
    }

    function _pair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b
            ? keccak256(abi.encodePacked(a, b))
            : keccak256(abi.encodePacked(b, a));
    }

    /// @dev Proof for a leaf in our 4-leaf tree.
    function _proof(uint256 index) internal view returns (bytes32[] memory proof) {
        proof = new bytes32[](2);
        if (index == 0) {
            proof[0] = leaves[1];
            proof[1] = h23;
        } else if (index == 1) {
            proof[0] = leaves[0];
            proof[1] = h23;
        } else if (index == 2) {
            proof[0] = leaves[3];
            proof[1] = h01;
        } else {
            proof[0] = leaves[2];
            proof[1] = h01;
        }
    }

    function _accounts(uint256 index) internal view returns (address) {
        if (index == 0) return alice;
        if (index == 1) return bob;
        if (index == 2) return carol;
        return dave;
    }

    function _claim(uint256 index) internal {
        distributor.claim(
            index,
            _accounts(index),
            airdrops[index],
            bonuses[index],
            streaks[index],
            _proof(index)
        );
    }

    // --- happy path ---

    function testClaimHappyPath() public {
        distributor.setRoot(root);
        uint256 before = token.balanceOf(alice);
        _claim(0);
        uint256 expected = airdrops[0] + bonuses[0] + streaks[0]; // 133,000 KONG
        assertEq(token.balanceOf(alice) - before, expected);
        assertTrue(distributor.isClaimed(0));
        assertFalse(distributor.isClaimed(1));
        assertEq(token.balanceOf(address(distributor)), FUNDING - expected);
    }

    function testClaimAllFour() public {
        distributor.setRoot(root);
        uint256 totalExpected;
        for (uint256 i = 0; i < 4; i++) {
            _claim(i);
            totalExpected += airdrops[i] + bonuses[i] + streaks[i];
        }
        assertEq(token.balanceOf(alice), airdrops[0] + bonuses[0] + streaks[0]);
        assertEq(token.balanceOf(bob), airdrops[1] + bonuses[1] + streaks[1]);
        assertEq(token.balanceOf(carol), airdrops[2] + bonuses[2] + streaks[2]);
        assertEq(token.balanceOf(dave), airdrops[3] + bonuses[3] + streaks[3]);
        assertEq(token.balanceOf(address(distributor)), FUNDING - totalExpected);
    }

    /// @dev Anyone may pay gas for a claim; tokens always go to `account`.
    function testClaimByThirdParty() public {
        distributor.setRoot(root);
        vm.prank(bob); // bob pays gas for alice's claim
        distributor.claim(0, alice, airdrops[0], bonuses[0], streaks[0], _proof(0));
        assertEq(token.balanceOf(alice), airdrops[0] + bonuses[0] + streaks[0]);
        assertEq(token.balanceOf(bob), 0);
    }

    // --- claim reverts ---

    function testDoubleClaimReverts() public {
        distributor.setRoot(root);
        _claim(0);
        vm.expectRevert(KongMerkleDistributor.AlreadyClaimed.selector);
        _claim(0);
    }

    function testWrongAmountReverts() public {
        distributor.setRoot(root);
        // Tampered bonus: the proof no longer matches the leaf.
        vm.expectRevert(KongMerkleDistributor.InvalidProof.selector);
        distributor.claim(0, alice, airdrops[0], bonuses[0] + 1, streaks[0], _proof(0));
    }

    function testWrongAccountReverts() public {
        distributor.setRoot(root);
        vm.expectRevert(KongMerkleDistributor.InvalidProof.selector);
        distributor.claim(0, bob, airdrops[0], bonuses[0], streaks[0], _proof(0));
    }

    function testWrongIndexReverts() public {
        distributor.setRoot(root);
        vm.expectRevert(KongMerkleDistributor.InvalidProof.selector);
        distributor.claim(1, alice, airdrops[0], bonuses[0], streaks[0], _proof(0));
    }

    function testClaimBeforeRootReverts() public {
        vm.expectRevert(KongMerkleDistributor.RootNotSet.selector);
        _claim(0);
    }

    /// @dev GAS-ONLY: claim() is nonpayable — sending ETH reverts.
    ///      (The compiler forbids {value:} on a nonpayable call, so this
    ///      uses a low-level call to prove the on-chain behaviour.)
    function testClaimWithValueReverts() public {
        distributor.setRoot(root);
        vm.deal(address(this), 1 ether);
        (bool success, ) = address(distributor).call{value: 1 ether}(
            abi.encodeWithSelector(
                KongMerkleDistributor.claim.selector,
                0,
                alice,
                airdrops[0],
                bonuses[0],
                streaks[0],
                _proof(0)
            )
        );
        assertFalse(success, "claim with ETH value must revert");
        assertFalse(distributor.isClaimed(0));
    }

    // --- setRoot ---

    function testSetRootTwiceReverts() public {
        distributor.setRoot(root);
        vm.expectRevert(KongMerkleDistributor.RootAlreadySet.selector);
        distributor.setRoot(bytes32(uint256(1)));
    }

    function testSetRootNonOwnerReverts() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice)
        );
        distributor.setRoot(root);
    }

    function testSetRootZeroReverts() public {
        vm.expectRevert("KongMerkleDistributor: zero root");
        distributor.setRoot(bytes32(0));
    }

    function testSetRootRecordsTime() public {
        vm.warp(1_800_000_000);
        distributor.setRoot(root);
        assertEq(distributor.merkleRoot(), root);
        assertEq(distributor.rootSetTime(), 1_800_000_000);
    }

    // --- sweep (root set) ---

    function testSweepBeforeDeadlineReverts() public {
        distributor.setRoot(root);
        // Even at exactly the deadline, sweep is not available (strict >).
        vm.warp(block.timestamp + 180 days);
        vm.expectRevert(KongMerkleDistributor.SweepNotAvailable.selector);
        distributor.sweepUnclaimed();
    }

    function testSweepAfterDeadlineWorks() public {
        distributor.setRoot(root);
        _claim(0); // one claim first, so the sweep amount is partial
        uint256 claimedTotal = airdrops[0] + bonuses[0] + streaks[0];
        vm.warp(block.timestamp + 180 days + 1);
        uint256 ownerBefore = token.balanceOf(address(this));
        distributor.sweepUnclaimed();
        assertEq(token.balanceOf(address(this)) - ownerBefore, FUNDING - claimedTotal);
        assertEq(token.balanceOf(address(distributor)), 0);
    }

    function testSweepNonOwnerReverts() public {
        distributor.setRoot(root);
        vm.warp(block.timestamp + 181 days);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice)
        );
        distributor.sweepUnclaimed();
    }

    // --- sweep (no root: sale-failed reclaim) ---

    function testNoRootReclaimBeforeDateReverts() public {
        // 2027-02-28, one day before the reclaim date.
        vm.warp(1803859200 - 1 days);
        vm.expectRevert(KongMerkleDistributor.SweepNotAvailable.selector);
        distributor.sweepUnclaimed();
    }

    function testNoRootReclaimAtDateReverts() public {
        // Exactly 2027-03-01 00:00 UTC: not yet available (strict >).
        vm.warp(1803859200);
        vm.expectRevert(KongMerkleDistributor.SweepNotAvailable.selector);
        distributor.sweepUnclaimed();
    }

    function testNoRootReclaimAfterDateWorks() public {
        vm.warp(1803859200 + 1);
        uint256 ownerBefore = token.balanceOf(address(this));
        distributor.sweepUnclaimed();
        assertEq(token.balanceOf(address(this)) - ownerBefore, FUNDING);
        assertEq(token.balanceOf(address(distributor)), 0);
    }

    /// @dev The no-root reclaim is unreachable once a root exists: the
    ///      root-set path (180-day window) is the only sweep route.
    function testRootSetBlocksNoRootReclaim() public {
        // Root set 10 days before the reclaim date...
        vm.warp(1803859200 - 10 days);
        distributor.setRoot(root);
        // ...then time passes the reclaim date, but the 180-day window
        // from rootSetTime is still open, so the sweep must revert.
        vm.warp(1803859200 + 1);
        vm.expectRevert(KongMerkleDistributor.SweepNotAvailable.selector);
        distributor.sweepUnclaimed();
    }
}
