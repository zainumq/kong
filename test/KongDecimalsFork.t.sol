// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {KongToken} from "../src/KongToken.sol";
import {KongSale} from "../src/KongSale.sol";
import {MockUSDT, MockAgentID, MockRouter} from "./mocks/Mocks.sol";

interface IERC20Decimals {
    function decimals() external view returns (uint8);
}

/// @notice Fork test: pins the sale's prices against the REAL mainnet USDT
///         contract on BSC — the check whose absence let the v2 decimals
///         bug (6 assumed, 18 real) reach mainnet.
///
///         Run with:
///           BSC_RPC_URL=https://bsc-dataseed2.bnbchain.org forge test --match-contract KongDecimalsForkTest
///         (any BSC public RPC works; dataseed1 / publicnode.com are
///         fallbacks if dataseed2 is rate-limited.)
///
///         Skipped automatically when BSC_RPC_URL is not set, so the
///         default `forge test` never depends on network access. The
///         unit suite (KongDecimalsTest) is the mandatory gate; this fork
///         test is the live cross-check against mainnet reality.
contract KongDecimalsForkTest is Test {
    address internal constant MAINNET_USDT = 0x55d398326f99059fF775485246999027B3197955;

    function setUp() public {
        string memory rpc = vm.envOr("BSC_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            vm.skip(true, "BSC_RPC_URL not set; fork test skipped");
        }
        vm.createSelectFork(rpc);
    }

    /// @notice Real BSC USDT decimals() == 18, and the mock used by the
    ///         unit suite must match it exactly.
    function test_MainnetUsdtDecimals() public {
        uint8 dec = IERC20Decimals(MAINNET_USDT).decimals();
        assertEq(dec, 18, "real BSC USDT must have 18 decimals");
        assertEq(new MockUSDT().decimals(), dec, "mock decimals must equal mainnet");
    }

    /// @notice A fresh sale wired to the REAL mainnet USDT token prices
    ///         shares at exactly 1 / 1.5 / 2 USDT at the token's own
    ///         decimals. (Deploying the sale on the fork also proves the
    ///         constructor works against the real token address.)
    function test_SalePricesAgainstMainnetUsdt() public {
        uint256 dec = IERC20Decimals(MAINNET_USDT).decimals();
        uint256 unit = 10 ** dec; // 1 USDT in raw units at mainnet decimals
        KongToken token = new KongToken();
        MockAgentID agentId = new MockAgentID();
        MockRouter router = new MockRouter();
        KongSale sale = new KongSale(
            address(token),
            MAINNET_USDT,
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
        assertEq(address(sale.usdt()), MAINNET_USDT);
        assertEq(sale.TIER1_PRICE(), 1 * unit, "T1 must be 1 USDT at mainnet decimals");
        assertEq(sale.TIER2_PRICE(), (15 * unit) / 10, "T2 must be 1.5 USDT");
        assertEq(sale.TIER3_PRICE(), 2 * unit, "T3 must be 2 USDT");
        assertEq(sale.FULL_RAISE_USDT(), 15_750 * unit, "full raise must be 15,750 USDT");
        assertEq(sale.quote(1), 1 * unit);
    }
}
