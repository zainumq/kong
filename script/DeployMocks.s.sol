// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {KongMintPass} from "../src/KongMintPass.sol";
import {MockUSDT} from "../test/mocks/Mocks.sol";

/// @title DeployMocks — deploy testnet stand-ins for the market's inputs
/// @notice Deploys MockUSDT (18 decimals, like real BSC USDT) and a REAL
///         KongMintPass whose `sale` role is the deployer, so the deployer
///         can mint/burn test passes directly (simulating sale mints and
///         claim/refund burns). Testnet only — never on mainnet.
///
///         Environment variables:
///         TREASURY_ADDRESS        royalty receiver for the mock pass
///                                 (defaults to the deployer if unset)
///         TIER1/2/3_IMAGE_URI     tier artwork URIs (placeholder defaults)
///         DEPLOYER_PRIVATE_KEY    deployer key (never commit it)
///
///         After running, feed the logged addresses to
///         DeployKongMarket.s.sol as PASS_ADDRESS / USDT_ADDRESS.
///
///         forge script script/DeployMocks.s.sol:DeployMocks \
///           --rpc-url $BSC_TESTNET_RPC --broadcast
contract DeployMocks is Script {
    function run() public returns (MockUSDT usdt, KongMintPass pass) {
        // Testnet only: mocks must never be deployed to mainnet (chain 56).
        require(block.chainid == 97, "DeployMocks: BSC testnet (97) only");
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        address treasury = vm.envOr("TREASURY_ADDRESS", deployer);
        string memory img1 =
            vm.envOr("TIER1_IMAGE_URI", string("https://kong.example/art/tier1.png"));
        string memory img2 =
            vm.envOr("TIER2_IMAGE_URI", string("https://kong.example/art/tier2.png"));
        string memory img3 =
            vm.envOr("TIER3_IMAGE_URI", string("https://kong.example/art/tier3.png"));

        console.log("Deployer (also the mock sale):", deployer);
        console.log("Treasury (royalty receiver):", treasury);

        vm.startBroadcast(deployerKey);
        usdt = new MockUSDT();
        // The deployer plays the sale role: it can mint/burn test passes.
        pass = new KongMintPass(deployer, treasury, img1, img2, img3);
        vm.stopBroadcast();

        console.log("MockUSDT deployed at:", address(usdt));
        console.log("Mock KongMintPass deployed at:", address(pass));
        console.log("NOTE: pass sale == deployer; mint test passes with pass.mint(to, tier).");
    }
}
