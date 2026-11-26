// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {KongMarketOracle} from "../src/KongMarketOracle.sol";

/// @title DeployKongMarketOracle — deploy KongMarketOracle to BSC testnet or mainnet
/// @notice USDT-ONLY market since 26 Nov 2026 (the Chainlink BNB/USD feed
///         and every BNB payment path were removed — a BNB sale's 1% fee
///         could never be swept, proven on testnet 26 Nov 2026). Same
///         env-var pattern as DeployKongMarket.s.sol:
///
///         PASS_ADDRESS            KongMintPass (mainnet 0x615AAaFF423f1005B7bF51e3dEC6BbF5958Af89B)
///         USDT_ADDRESS            BSC USDT (mainnet 0x55d398326f99059fF775485246999027B3197955, 18 decimals)
///         TREASURY_ADDRESS        fee-sweep recipient — the NEW FeeDistributor
///                                 (deployed separately; its address goes here.
///                                 NEVER the retired 0x418FF609… distributor,
///                                 which is wired to the old BNB market)
///         FLOOR_USDT_T1/T2/T3     USDT floors in wei (1 / 1.5 / 2 USDT = 1e18 / 1.5e18 / 2e18)
///         DEPLOYER_PRIVATE_KEY    deployer key (never commit it)
///         EXPECTED_CHAIN_ID       optional: pin the exact chain (56 mainnet
///                                 / 97 testnet). When unset, any of 56/97 is
///                                 accepted and anything else is rejected.
///
///         Testnet first (this script's first run deploys to 97), mainnet
///         only after the testnet deployment is verified end-to-end AND the
///         first pass exists (sale opens 1 Dec 2026). Example:
///
///         forge script script/DeployKongMarketOracle.s.sol:DeployKongMarketOracle \
///           --rpc-url $BSC_TESTNET_RPC --broadcast --legacy --gas-price 1000000000
///
///         NOTE: --legacy --gas-price 1000000000 is REQUIRED on the public
///         testnet RPC — EIP-1559 estimation returns 1 wei and the tx
///         stalls in the mempool (see testnet-deploy-20261119.md §5).
///
/// @dev Audit L-3 (carried over from v1): every parameter is validated
///      BEFORE broadcast, because all of them are immutable — a wrong
///      deploy cannot be fixed, only redeployed (new address, lost seller
///      approvals). The checks: chain id (56/97, or EXPECTED_CHAIN_ID),
///      pass/USDT have code, USDT decimals == 18 (read live), treasury
///      non-zero, USDT floors > 0 and strictly ascending (T1 < T2 < T3).
///      After the deploy, the immutable parameters plus all three floors
///      are read back from the deployed contract and compared with the
///      intended values; the read-back also proves a BNB floor read
///      reverts (USDT-only).
contract DeployKongMarketOracle is Script {
    struct DeployParams {
        address pass;
        address usdt;
        address treasury;
        uint256[3] floorUsdt;
        uint256 deployerKey;
    }

    function run() public returns (KongMarketOracle market) {
        DeployParams memory p = DeployParams({
            pass: vm.envAddress("PASS_ADDRESS"),
            usdt: vm.envAddress("USDT_ADDRESS"),
            treasury: vm.envAddress("TREASURY_ADDRESS"),
            floorUsdt: [
                vm.envUint("FLOOR_USDT_T1"),
                vm.envUint("FLOOR_USDT_T2"),
                vm.envUint("FLOOR_USDT_T3")
            ],
            deployerKey: vm.envUint("DEPLOYER_PRIVATE_KEY")
        });

        console.log("Deployer:", vm.addr(p.deployerKey));
        console.log("Pass:", p.pass);
        console.log("USDT:", p.usdt);
        console.log("Treasury (new FeeDistributor):", p.treasury);
        console.log("Floor USDT T1/T2/T3 (wei):", p.floorUsdt[0], p.floorUsdt[1], p.floorUsdt[2]);

        _validate(p);

        vm.startBroadcast(p.deployerKey);
        market = new KongMarketOracle(p.pass, p.usdt, p.treasury, p.floorUsdt);
        vm.stopBroadcast();

        _verifyReadBack(market, p);

        console.log("KongMarketOracle deployed at:", address(market));
        console.log("Fee (bps):", market.FEE_BPS());
    }

    /// @notice All pre-deploy validations (audit L-3).
    function _validate(DeployParams memory p) internal view {
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

        // (d) Non-zero parameters (also checked by the constructor, but
        // fail here with a clear message first).
        require(p.treasury != address(0), "TREASURY_ADDRESS is zero");
        require(p.pass != address(0), "PASS_ADDRESS is zero");
        require(p.usdt != address(0), "USDT_ADDRESS is zero");

        // (a) Pass and USDT must be deployed contracts, not EOAs or typos
        // — an address without code would brick the market.
        require(p.pass.code.length > 0, "PASS_ADDRESS has no code");
        require(p.usdt.code.length > 0, "USDT_ADDRESS has no code");

        // (b) The payment token must be 18-decimal USDT (read live).
        // A 6-decimal token would silently misprice every floor by 1e12
        // (the v2 KONG decimals bug class).
        uint8 usdtDecimals = IERC20Metadata(p.usdt).decimals();
        console.log("USDT decimals (live):", usdtDecimals);
        require(usdtDecimals == 18, "USDT decimals must be 18");

        // (c) Floors must be > 0 and strictly ascending (T1 < T2 < T3).
        // The constructor enforces the same, but failing here names the
        // misconfiguration before any gas is spent.
        require(
            p.floorUsdt[0] > 0 && p.floorUsdt[1] > 0 && p.floorUsdt[2] > 0,
            "USDT floors must be > 0"
        );
        require(
            p.floorUsdt[0] < p.floorUsdt[1] && p.floorUsdt[1] < p.floorUsdt[2],
            "USDT floors must ascend T1 < T2 < T3"
        );
        console.log("All pre-deploy validations passed.");
    }

    /// @notice Post-deploy read-back: verify the immutable parameters
    ///         on-chain match the intended values, and prove the market is
    ///         USDT-only (a BNB floor read reverts). (In a broadcast run
    ///         these reads execute against the simulated state — ALWAYS
    ///         re-verify with cast afterwards against the live chain.)
    function _verifyReadBack(KongMarketOracle market, DeployParams memory p) internal view {
        require(address(market.pass()) == p.pass, "read-back: pass mismatch");
        require(address(market.usdt()) == p.usdt, "read-back: usdt mismatch");
        require(market.treasury() == p.treasury, "read-back: treasury mismatch");
        require(market.floorOf(1, p.usdt) == p.floorUsdt[0], "read-back: USDT T1 floor mismatch");
        require(market.floorOf(2, p.usdt) == p.floorUsdt[1], "read-back: USDT T2 floor mismatch");
        require(market.floorOf(3, p.usdt) == p.floorUsdt[2], "read-back: USDT T3 floor mismatch");
        try market.floorOf(1, address(0)) returns (uint256) {
            revert("read-back: BNB floor did not revert");
        } catch {
            // Expected: USDT-only market.
        }
        console.log("Post-deploy read-back verified.");
    }
}
