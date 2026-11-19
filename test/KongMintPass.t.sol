// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {KongMintPass} from "../src/KongMintPass.sol";

/// @notice Tests for KongMintPass: per-tier artwork in tokenURI, royalty,
///         mint/burn access control. The test contract plays the sale role.
contract KongMintPassTest is Test {
    KongMintPass internal pass;
    address internal treasury = makeAddr("treasury");
    address internal holder = makeAddr("holder");
    address internal other = makeAddr("other");

    string internal constant IMG1 = "https://kong.example/art/tier1.png";
    string internal constant IMG2 = "https://kong.example/art/tier2.png";
    string internal constant IMG3 = "https://kong.example/art/tier3.png";

    function setUp() public {
        pass = new KongMintPass(address(this), treasury, IMG1, IMG2, IMG3);
    }

    function test_MintRecordsTier() public {
        uint256 t1 = pass.mint(holder, 1);
        uint256 t2 = pass.mint(holder, 2);
        uint256 t3 = pass.mint(holder, 3);
        assertEq(t1, 1);
        assertEq(t2, 2);
        assertEq(t3, 3);
        assertEq(pass.tierOf(1), 1);
        assertEq(pass.tierOf(2), 2);
        assertEq(pass.tierOf(3), 3);
        assertEq(pass.ownerOf(1), holder);
        assertEq(pass.nextTokenId(), 4);
    }

    function test_OnlySale() public {
        vm.prank(other);
        vm.expectRevert(KongMintPass.OnlySale.selector);
        pass.mint(holder, 1);
        pass.mint(holder, 1);
        vm.prank(other);
        vm.expectRevert(KongMintPass.OnlySale.selector);
        pass.burn(1);
    }

    function test_InvalidTier() public {
        vm.expectRevert(KongMintPass.InvalidTier.selector);
        pass.mint(holder, 0);
        vm.expectRevert(KongMintPass.InvalidTier.selector);
        pass.mint(holder, 4);
        vm.expectRevert(KongMintPass.InvalidTier.selector);
        pass.tierImageURI(0);
    }

    function test_TierImageURIs() public view {
        assertEq(pass.tierImageURI(1), IMG1);
        assertEq(pass.tierImageURI(2), IMG2);
        assertEq(pass.tierImageURI(3), IMG3);
    }

    function test_ClaimableOf() public {
        pass.mint(holder, 1);
        pass.mint(holder, 2);
        pass.mint(holder, 3);
        assertEq(pass.claimableOf(1), 60_000 ether);
        assertEq(pass.claimableOf(2), 50_000 ether);
        assertEq(pass.claimableOf(3), 40_000 ether);
    }

    /// @notice Each tier's tokenURI is different (different image + tier
    ///         attributes). The URIs are also logged so the base64 JSON can
    ///         be decoded off-chain and the image fields verified.
    function test_TokenURIPerTier() public {
        pass.mint(holder, 1);
        pass.mint(holder, 2);
        pass.mint(holder, 3);
        string memory uri1 = pass.tokenURI(1);
        string memory uri2 = pass.tokenURI(2);
        string memory uri3 = pass.tokenURI(3);
        assertTrue(bytes(uri1).length > 0);
        assertTrue(keccak256(bytes(uri1)) != keccak256(bytes(uri2)));
        assertTrue(keccak256(bytes(uri2)) != keccak256(bytes(uri3)));
        assertTrue(keccak256(bytes(uri1)) != keccak256(bytes(uri3)));
        console.log("TOKENURI_T1:", uri1);
        console.log("TOKENURI_T2:", uri2);
        console.log("TOKENURI_T3:", uri3);
    }

    function test_Royalty5Percent() public {
        pass.mint(holder, 1);
        (address receiver, uint256 amount) = pass.royaltyInfo(1, 100 ether);
        assertEq(receiver, treasury);
        assertEq(amount, 5 ether); // 5% of 100
        (receiver, amount) = pass.royaltyInfo(1, 1 ether);
        assertEq(amount, 0.05 ether);
        // ERC-2981 interface supported.
        assertTrue(pass.supportsInterface(0x2a55205a));
    }

    function test_Burn() public {
        pass.mint(holder, 1);
        pass.burn(1);
        vm.expectRevert();
        pass.ownerOf(1);
        vm.expectRevert();
        pass.tokenURI(1);
    }

    function test_Transferable() public {
        pass.mint(holder, 1);
        vm.prank(holder);
        pass.transferFrom(holder, other, 1);
        assertEq(pass.ownerOf(1), other);
        assertEq(pass.tierOf(1), 1); // tier survives transfer
    }
}
