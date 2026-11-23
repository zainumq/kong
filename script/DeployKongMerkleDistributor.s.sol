// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {KongMerkleDistributor} from "../src/KongMerkleDistributor.sol";

/// @title DeployKongMerkleDistributor — MAINNET (chain 56) deploy script
/// @notice Deploys the KongMerkleDistributor for the $KONG community
///         benefit pools (10M airdrop + 20M buyer bonus + 3M streak).
///
///         CONSTRUCTOR ARGS (fixed):
///           token = 0x410eAA536d701c5096619be8cBB6D46643796ee4 (KongToken)
///           owner = msg.sender (the deployer, Account 16)
///
///         DEPLOY METHOD: this script is provided for reference and for
///         reproducible verification. The actual mainnet deploy is done
///         by the user in REMIX via MetaMask (Account 16) in the device
///         browser — see kong-distributor-design.md § "Mainnet deploy"
///         for the exact steps. DO NOT broadcast this script to mainnet
///         from this VM: the deployer key is not available here.
///
///         POST-DEPLOY (same session, MetaMask):
///           1. Verify on BscScan + Sourcify (flattened source, solc
///              0.8.24, optimizer 200 runs, EVM Cancun).
///           2. Transfer exactly 33,000,000 KONG from Account 16 to the
///              distributor. Verify balanceOf(distributor) == 33M.
///           3. Do NOT call setRoot() — the root is set at graduation
///              only, after the snapshot + off-chain tree verification.
///
///         forge script script/DeployKongMerkleDistributor.s.sol \
///           --rpc-url $BSC_MAINNET_RPC
contract DeployKongMerkleDistributor is Script {
    address internal constant KONG_TOKEN = 0x410eAA536d701c5096619be8cBB6D46643796ee4;

    function run() public returns (KongMerkleDistributor distributor) {
        // Mainnet only: this script must never deploy to testnet, where
        // the token address does not exist.
        require(block.chainid == 56, "DeployKongMerkleDistributor: mainnet (56) only");
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        console.log("Deployer / owner:", deployer);
        console.log("KONG token:", KONG_TOKEN);

        vm.startBroadcast(deployerKey);
        distributor = new KongMerkleDistributor(KONG_TOKEN);
        vm.stopBroadcast();

        console.log("KongMerkleDistributor deployed at:", address(distributor));
        console.log("NEXT: transfer 33,000,000 KONG to the distributor.");
        console.log("NEXT: verify source on BscScan + Sourcify.");
        console.log("DO NOT setRoot() until graduation (see design doc).");
    }
}
