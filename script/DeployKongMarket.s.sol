// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {KongMarket} from "../src/KongMarket.sol";

/// @title DeployKongMarket — deploy KongMarket to BSC testnet or mainnet
/// @notice All parameters come from environment variables, so the same
///         script deploys to testnet (pointing at mock addresses from
///         DeployMocks.s.sol) and to mainnet (pointing at the real
///         contracts):
///
///         PASS_ADDRESS            KongMintPass (mainnet 0x615AAaFF423f1005B7bF51e3dEC6BbF5958Af89B)
///         USDT_ADDRESS            BSC USDT (mainnet 0x55d398326f99059fF775485246999027B3197955, 18 decimals)
///         TREASURY_ADDRESS        fee-sweep recipient (0xed1A29F81a61029089Ad8D641670baD47bDced3A)
///         FLOOR_USDT_T1/T2/T3     USDT floors in wei (1 / 1.5 / 2 USDT = 1e18 / 1.5e18 / 2e18)
///         FLOOR_BNB_T1/T2/T3      BNB floors in wei — set from the BNB price
///                                 AT DEPLOY TIME (test values at BNB ~$589.89:
///                                 0.0017 / 0.00254 / 0.00339 ether). Immutable
///                                 after deploy, so double-check before running.
///         DEPLOYER_PRIVATE_KEY    deployer key (never commit it)
///         EXPECTED_CHAIN_ID       optional: pin the exact chain (56 mainnet
///                                 / 97 testnet). When unset, any of 56/97 is
///                                 accepted and anything else is rejected.
///
///         Testnet first, then mainnet only after the first pass exists
///         (sale opens 1 Dec 2026). Example:
///
///         forge script script/DeployKongMarket.s.sol:DeployKongMarket \
///           --rpc-url $BSC_TESTNET_RPC --broadcast --verify
///
/// @dev NEVER run against mainnet without re-checking the BNB floors
///      against the live BNB price — they are immutable once deployed.
///
///      Audit L-3: every parameter is validated BEFORE broadcast, because
///      all of them are immutable — a wrong deploy cannot be fixed, only
///      redeployed (new address, lost seller approvals). The checks:
///      chain id (56/97, or EXPECTED_CHAIN_ID), pass/USDT have code,
///      USDT decimals == 18 (read live), treasury non-zero, floors > 0
///      and strictly ascending per currency (T1 < T2 < T3). After the
///      deploy, all six floors plus the three addresses are read back
///      from the deployed contract and compared with the intended values.
contract DeployKongMarket is Script {
    function run() public returns (KongMarket market) {
        address pass = vm.envAddress("PASS_ADDRESS");
        address usdt = vm.envAddress("USDT_ADDRESS");
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        uint256[3] memory floorUsdt = [
            vm.envUint("FLOOR_USDT_T1"),
            vm.envUint("FLOOR_USDT_T2"),
            vm.envUint("FLOOR_USDT_T3")
        ];
        uint256[3] memory floorBnb = [
            vm.envUint("FLOOR_BNB_T1"),
            vm.envUint("FLOOR_BNB_T2"),
            vm.envUint("FLOOR_BNB_T3")
        ];
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        console.log("Deployer:", vm.addr(deployerKey));
        console.log("Pass:", pass);
        console.log("USDT:", usdt);
        console.log("Treasury:", treasury);
        console.log("Floor USDT T1/T2/T3 (wei):", floorUsdt[0], floorUsdt[1], floorUsdt[2]);
        console.log("Floor BNB  T1/T2/T3 (wei):", floorBnb[0], floorBnb[1], floorBnb[2]);

        // ---- Validation (audit L-3) — everything before broadcast ----

        // (e) Chain: only BSC mainnet (56) or testnet (97). An optional
        // EXPECTED_CHAIN_ID env var pins the exact chain instead.
        uint256 chainId = block.chainid;
        console.log("Chain ID detected:", chainId);
        uint256 expectedChainId = vm.envOr("EXPECTED_CHAIN_ID", uint256(0));
        if (expectedChainId != 0) {
            require(chainId == expectedChainId, "chainid != EXPECTED_CHAIN_ID");
        } else {
            require(
                chainId == 56 || chainId == 97,
                "chainid must be BSC mainnet (56) or testnet (97)"
            );
        }
        if (chainId == 56) {
            console.log("WARNING: deploying to BSC MAINNET - verify every parameter above!");
        }

        // (d) Treasury must be a real address (also checked by the
        // constructor, but fail here with a clear message first).
        require(treasury != address(0), "TREASURY_ADDRESS is zero");
        require(pass != address(0), "PASS_ADDRESS is zero");
        require(usdt != address(0), "USDT_ADDRESS is zero");

        // (a) Pass and USDT must be deployed contracts, not EOAs or
        // typos — an address without code would brick the market.
        require(pass.code.length > 0, "PASS_ADDRESS has no code");
        require(usdt.code.length > 0, "USDT_ADDRESS has no code");

        // (b) The payment token must be 18-decimal USDT (read live).
        // A 6-decimal token would silently misprice every floor by 1e12
        // (the v2 KONG decimals bug class).
        uint8 usdtDecimals = IERC20Metadata(usdt).decimals();
        console.log("USDT decimals (live):", usdtDecimals);
        require(usdtDecimals == 18, "USDT decimals must be 18");

        // (c) Floors must be > 0 and strictly ascending per currency
        // (T1 < T2 < T3). The constructor enforces the same, but failing
        // here names the misconfigured currency before any gas is spent.
        require(
            floorUsdt[0] > 0 && floorUsdt[1] > 0 && floorUsdt[2] > 0,
            "USDT floors must be > 0"
        );
        require(
            floorBnb[0] > 0 && floorBnb[1] > 0 && floorBnb[2] > 0, "BNB floors must be > 0"
        );
        require(
            floorUsdt[0] < floorUsdt[1] && floorUsdt[1] < floorUsdt[2],
            "USDT floors must ascend T1 < T2 < T3"
        );
        require(
            floorBnb[0] < floorBnb[1] && floorBnb[1] < floorBnb[2],
            "BNB floors must ascend T1 < T2 < T3"
        );
        console.log("All pre-deploy validations passed.");

        vm.startBroadcast(deployerKey);
        market = new KongMarket(pass, usdt, treasury, floorUsdt, floorBnb);
        vm.stopBroadcast();

        // Post-deploy read-back: verify the immutable parameters on-chain
        // match the intended values.
        require(address(market.pass()) == pass, "read-back: pass mismatch");
        require(address(market.usdt()) == usdt, "read-back: usdt mismatch");
        require(market.treasury() == treasury, "read-back: treasury mismatch");
        require(market.floorOf(1, usdt) == floorUsdt[0], "read-back: USDT T1 floor mismatch");
        require(market.floorOf(2, usdt) == floorUsdt[1], "read-back: USDT T2 floor mismatch");
        require(market.floorOf(3, usdt) == floorUsdt[2], "read-back: USDT T3 floor mismatch");
        require(market.floorOf(1, address(0)) == floorBnb[0], "read-back: BNB T1 floor mismatch");
        require(market.floorOf(2, address(0)) == floorBnb[1], "read-back: BNB T2 floor mismatch");
        require(market.floorOf(3, address(0)) == floorBnb[2], "read-back: BNB T3 floor mismatch");
        console.log("Post-deploy read-back verified.");

        console.log("KongMarket deployed at:", address(market));
        console.log("Fee (bps):", market.FEE_BPS());
    }
}
