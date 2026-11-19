// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {KongToken} from "../src/KongToken.sol";
import {KongSale} from "../src/KongSale.sol";
import {MockUSDT, MockAgentID, MockRouter} from "./mocks/Mocks.sol";

/// @notice REGRESSION tests for the v2 USDT decimals bug (found 19 Nov 2026
///         by the frontend builder, verified on-chain the same day).
///
///         The v2 sale priced shares at 1e6 raw units, assuming BSC USDT
///         has 6 decimals like Ethereum USDT. It does NOT: BSC USDT
///         (0x55d398326f99059fF775485246999027B3197955) returns
///         decimals() == 18, so the v2 prices were worth 1e-12 USDT per
///         share and the sale would have been effectively free. All 51 v2
///         tests passed anyway because the mock USDT baked in the same
///         wrong 6-decimal assumption. The v2 contracts were abandoned
///         (immutable; 750M KONG locked in the old sale + 100M in each old
///         vesting cannot be recovered) and v3 prices at 18 decimals.
///
///         These tests fail against the old 6-decimal code in two
///         independent ways:
///         (1) the mock's decimals() is pinned to 18 (the v2 mock
///             returned 6, so test_MockDecimalsMatchMainnet fails there);
///         (2) every tier price is asserted against the payment token's
///             OWN decimals(), read live — so a price/decimals mismatch
///         in either direction fails, even if the mock is fixed alone.
contract KongDecimalsTest is Test {
    KongSale internal sale;
    MockUSDT internal usdt;

    function setUp() public {
        vm.warp(1_800_000_000); // fixed start time
        KongToken token = new KongToken();
        usdt = new MockUSDT();
        MockAgentID agentId = new MockAgentID();
        MockRouter router = new MockRouter();
        sale = new KongSale(
            address(token),
            address(usdt),
            address(agentId),
            address(router),
            makeAddr("treasury"),
            makeAddr("team"),
            makeAddr("community"),
            block.timestamp,
            "https://kong.example/art/tier1.png",
            "https://kong.example/art/tier2.png",
            "https://kong.example/art/tier3.png"
        );
    }

    /// @notice The mock MUST match mainnet: real BSC USDT decimals() == 18
    ///         (verified on-chain 19 Nov 2026; see KongDecimalsForkTest
    ///         for the live fork check). Fails against the v2 mock (6).
    function test_MockDecimalsMatchMainnet() public view {
        assertEq(usdt.decimals(), 18, "mock USDT must be 18 decimals like mainnet BSC USDT");
    }

    /// @notice Tier prices equal exactly 1 / 1.5 / 2 USDT in raw units at
    ///         the payment token's OWN decimals — decimals are read from
    ///         the token, never hardcoded, so this fails if the prices and
    ///         the token ever disagree again.
    function test_TierPricesMatchTokenDecimals() public view {
        uint256 dec = usdt.decimals();
        uint256 unit = 10 ** dec; // 1 USDT in raw units
        assertEq(sale.TIER1_PRICE(), 1 * unit, "T1 must be 1 USDT");
        assertEq(sale.TIER2_PRICE(), (15 * unit) / 10, "T2 must be 1.5 USDT");
        assertEq(sale.TIER3_PRICE(), 2 * unit, "T3 must be 2 USDT");
        assertEq(sale.FULL_RAISE_USDT(), 15_750 * unit, "full raise must be 15,750 USDT");
        // The views must agree with the constants.
        assertEq(sale.priceOfShare(1), sale.TIER1_PRICE());
        assertEq(sale.priceOfShare(2_501), sale.TIER2_PRICE());
        assertEq(sale.priceOfShare(6_001), sale.TIER3_PRICE());
        assertEq(sale.quote(1), 1 * unit);
        assertEq(sale.quote(10), 10 * unit);
    }

    /// @notice Sanity: one Tier 1 share costs a whole USDT, not dust.
    ///         The v2 price (1e6 raw = 1e-12 USDT) fails this by 6 orders
    ///         of magnitude.
    function test_Tier1PriceIsNotDust() public view {
        assertGt(sale.TIER1_PRICE(), 1e12, "T1 price must exceed 1e12 raw units");
        assertEq(sale.TIER1_PRICE(), 1 ether, "T1 price is exactly 1 USDT at 18 decimals");
    }
}
