// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {KongToken} from "../src/KongToken.sol";
import {KongMintPass} from "../src/KongMintPass.sol";
import {KongSale} from "../src/KongSale.sol";
import {MockUSDT, MockAgentID, MockRouter, MaliciousERC20, MaliciousRouter} from "./mocks/Mocks.sol";

/// @notice Reentrancy tests: an attacker token/router that calls back into
///         the sale mid-transfer must not be able to steal funds. The
///         attack transaction reverts (ReentrancyGuard) and state is
///         unchanged.
contract KongReentrancyTest is Test {
    address internal treasury = makeAddr("treasury");
    address internal team = makeAddr("team");
    address internal community = makeAddr("community");
    address internal attacker = makeAddr("attacker");

    string internal constant IMG1 = "https://kong.example/art/tier1.png";
    string internal constant IMG2 = "https://kong.example/art/tier2.png";
    string internal constant IMG3 = "https://kong.example/art/tier3.png";

    MockAgentID internal agentId;

    function setUp() public {
        vm.warp(1_800_000_000);
        agentId = new MockAgentID();
        agentId.setBalance(attacker, 1);
    }

    function deploySale(address kong, address usdt, address router) internal returns (KongSale) {
        return new KongSale(
            kong, usdt, address(agentId), router, treasury, team, community, block.timestamp, IMG1, IMG2, IMG3
        );
    }

    /// @notice Malicious $KONG re-enters claim() during the token transfer.
    ///         The reentrant claim must fail and the whole tx must revert.
    function test_ReentrancyClaim() public {
        MaliciousERC20 evilKong = new MaliciousERC20("Kong", "KONG");
        MockUSDT usdt = new MockUSDT();
        MockRouter router = new MockRouter();
        KongSale sale = deploySale(address(evilKong), address(usdt), address(router));
        evilKong.mint(address(sale), 750_000_000 ether);

        usdt.mint(attacker, 1_000_000e18);
        vm.prank(attacker);
        usdt.approve(address(sale), type(uint256).max);
        vm.prank(attacker);
        sale.mintPass(2, address(0)); // tokens 1,2

        // Fill + graduate with the hook disarmed (normal operation).
        uint256 n = 0;
        while (sale.sharesSold() < 10_000) {
            uint256 remaining = 10_000 - sale.sharesSold();
            uint256 amount = remaining > 10 ? 10 : remaining;
            address b = address(uint160(0x20000 + (++n)));
            usdt.mint(b, 1_000_000e18);
            agentId.setBalance(b, 1);
            vm.prank(b);
            usdt.approve(address(sale), type(uint256).max);
            vm.prank(b);
            sale.mintPass(amount, address(0));
        }
        sale.graduate();

        // Arm: during the KONG transfer of claim(1), re-enter claim(2).
        evilKong.arm(address(sale), abi.encodeWithSignature("claim(uint256)", 2));
        vm.prank(attacker);
        vm.expectRevert();
        sale.claim(1);

        // Attack failed: no tokens stolen, both passes still owned.
        assertEq(evilKong.balanceOf(attacker), 0);
        assertEq(sale.pass().ownerOf(1), attacker);
        assertEq(sale.pass().ownerOf(2), attacker);
    }

    /// @notice Malicious USDT re-enters refund() during the refund transfer.
    function test_ReentrancyRefund() public {
        KongToken token = new KongToken();
        MaliciousERC20 evilUsdt = new MaliciousERC20("Tether USD", "USDT");
        MockRouter router = new MockRouter();
        KongSale sale = deploySale(address(token), address(evilUsdt), address(router));
        token.transfer(address(sale), 750_000_000 ether);

        evilUsdt.mint(attacker, 1_000_000e18);
        vm.prank(attacker);
        evilUsdt.approve(address(sale), type(uint256).max);
        vm.prank(attacker);
        sale.mintPass(2, address(0)); // tokens 1,2 @ 1 USDT each (raw units)

        vm.warp(sale.saleDeadline() + 1);
        assertTrue(sale.refundActive());

        // Arm: during the USDT transfer of refund(1), re-enter refund(2).
        evilUsdt.arm(address(sale), abi.encodeWithSignature("refund(uint256)", 2));
        uint256 balBefore = evilUsdt.balanceOf(attacker);
        vm.prank(attacker);
        vm.expectRevert();
        sale.refund(1);

        // Attack failed: no refund paid, both passes still owned.
        assertEq(evilUsdt.balanceOf(attacker), balBefore);
        assertEq(sale.pass().ownerOf(1), attacker);
        assertEq(sale.pass().ownerOf(2), attacker);
    }

    /// @notice Malicious router re-enters graduate() during addLiquidity.
    function test_ReentrancyGraduate() public {
        KongToken token = new KongToken();
        MockUSDT usdt = new MockUSDT();
        MaliciousRouter evilRouter = new MaliciousRouter();
        KongSale sale = deploySale(address(token), address(usdt), address(evilRouter));
        evilRouter.setSale(address(sale));
        token.transfer(address(sale), 750_000_000 ether);

        uint256 n = 0;
        while (sale.sharesSold() < 10_000) {
            uint256 remaining = 10_000 - sale.sharesSold();
            uint256 amount = remaining > 10 ? 10 : remaining;
            address b = address(uint160(0x30000 + (++n)));
            usdt.mint(b, 1_000_000e18);
            agentId.setBalance(b, 1);
            vm.prank(b);
            usdt.approve(address(sale), type(uint256).max);
            vm.prank(b);
            sale.mintPass(amount, address(0));
        }

        vm.expectRevert();
        sale.graduate();

        // Attack failed: not graduated, funds intact.
        assertFalse(sale.graduated());
        assertEq(usdt.balanceOf(address(sale)), 15_750e18);
        assertEq(token.balanceOf(address(sale)), 750_000_000 ether);
    }

    /// @notice Malicious $KONG re-enters claimReferral() during the
    ///         referral transfer. The reentrant claim must fail and the
    ///         whole tx must revert.
    function test_ReentrancyClaimReferral() public {
        MaliciousERC20 evilKong = new MaliciousERC20("Kong", "KONG");
        MockUSDT usdt = new MockUSDT();
        MockRouter router = new MockRouter();
        KongSale sale = deploySale(address(evilKong), address(usdt), address(router));
        evilKong.mint(address(sale), 750_000_000 ether);

        address referred = makeAddr("referred");
        agentId.setBalance(referred, 1);
        usdt.mint(referred, 1_000_000e18);
        vm.prank(referred);
        usdt.approve(address(sale), type(uint256).max);

        usdt.mint(attacker, 1_000_000e18);
        vm.prank(attacker);
        usdt.approve(address(sale), type(uint256).max);
        vm.prank(attacker);
        sale.mintPass(2, address(0)); // tokens 1,2 — attacker holds passes

        // Referred buyer mints 2 with attacker as referrer: 2 x 1,800.
        vm.prank(referred);
        sale.mintPass(2, attacker);
        assertEq(sale.referralEarned(attacker), 3_600 ether);

        // Fill + graduate with the hook disarmed (normal operation).
        uint256 n = 0;
        while (sale.sharesSold() < 10_000) {
            uint256 remaining = 10_000 - sale.sharesSold();
            uint256 amount = remaining > 10 ? 10 : remaining;
            address b = address(uint160(0x50000 + (++n)));
            usdt.mint(b, 1_000_000e18);
            agentId.setBalance(b, 1);
            vm.prank(b);
            usdt.approve(address(sale), type(uint256).max);
            vm.prank(b);
            sale.mintPass(amount, address(0));
        }
        sale.graduate();

        // Arm: during the KONG transfer of claimReferral(), re-enter it.
        evilKong.arm(address(sale), abi.encodeWithSignature("claimReferral()"));
        vm.prank(attacker);
        vm.expectRevert();
        sale.claimReferral();

        // Attack failed: no tokens stolen, accrued reward intact.
        assertEq(evilKong.balanceOf(attacker), 0);
        assertEq(sale.referralEarned(attacker), 3_600 ether);
    }
}
