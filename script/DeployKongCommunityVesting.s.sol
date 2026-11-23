// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {KongCommunityVesting} from "../src/KongCommunityVesting.sol";

/// @title DeployKongCommunityVesting — MAINNET (chain 56) deploy script
/// @notice Deploys KongCommunityVesting for the VESTED portion of the
///         community reserve: 10,000,000 KONG (of the 17M that remains
///         after the 33M KongMerkleDistributor funding; the other 7M
///         stays liquid in Account 16 for community programs).
///
///         CONSTRUCTOR ARGS (fixed):
///           token       = 0x410eAA536d701c5096619be8cBB6D46643796ee4 (KongToken)
///           beneficiary = 0xed1A29F81a61029089Ad8D641670baD47bDced3A (Account 16)
///           cliff       = 1,209,600 seconds (14 days — nothing releasable)
///           duration    = 1,382,400 seconds (16 days of linear release)
///
///         THE CLOCK STARTS AT DEPLOY: startTimestamp = block.timestamp in
///         the constructor. 14-day cliff, then linear release over 16 days
///         at ~625,000 KONG/day — fully vested at deploy + 30 days.
///         Deploy late Nov 2026 -> cliff ends ~mid-Dec 2026, fully vested
///         ~late Dec 2026 (see kong-community-vesting-20261123.md).
///
///         DEPLOY METHOD: this script is provided for reference and for
///         reproducible verification. The actual mainnet deploy is done
///         by the user in REMIX via MetaMask (Account 16) in the device
///         browser — see kong-community-vesting-20261123.md § "Mainnet
///         deploy" for the exact steps. DO NOT broadcast this script to
///         mainnet from this VM: the deployer key is not available here.
///
///         POST-DEPLOY (same session, MetaMask):
///           1. Verify on BscScan + Sourcify (flattened source, solc
///              0.8.24, optimizer 200 runs, EVM Cancun).
///           2. FIRST confirm the distributor has already taken its
///              33,000,000 KONG — Account 16 holds exactly 50,000,000.
///              THEN transfer exactly 10,000,000 KONG from Account 16
///              to the vesting contract. Verify
///              balanceOf(vesting) == 10,000,000 and
///              totalAllocated() == 10,000,000. The remaining 7,000,000
///              KONG stays liquid in Account 16.
///           3. Confirm startTimestamp() == deploy block timestamp,
///              beneficiary() == Account 16, releasable() == 0.
///
///         forge script script/DeployKongCommunityVesting.s.sol \
///           --rpc-url $BSC_MAINNET_RPC
contract DeployKongCommunityVesting is Script {
    address internal constant KONG_TOKEN = 0x410eAA536d701c5096619be8cBB6D46643796ee4;
    address internal constant BENEFICIARY = 0xed1A29F81a61029089Ad8D641670baD47bDced3A;
    uint256 internal constant CLIFF = 14 days; // 1,209,600 seconds
    uint256 internal constant DURATION = 16 days; // 1,382,400 seconds

    function run() public returns (KongCommunityVesting vesting) {
        // Mainnet only: this script must never deploy to testnet, where
        // the token address does not exist.
        require(block.chainid == 56, "DeployKongCommunityVesting: mainnet (56) only");
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        console.log("Deployer:", deployer);
        console.log("KONG token:", KONG_TOKEN);
        console.log("Beneficiary:", BENEFICIARY);
        console.log("Cliff (seconds):", CLIFF);
        console.log("Duration (seconds):", DURATION);

        vm.startBroadcast(deployerKey);
        vesting = new KongCommunityVesting(KONG_TOKEN, BENEFICIARY, CLIFF, DURATION);
        vm.stopBroadcast();

        console.log("KongCommunityVesting deployed at:", address(vesting));
        console.log("startTimestamp == deploy block timestamp (clock starts NOW).");
        console.log("14-day cliff, then ~625,000 KONG/day; fully vested at deploy + 30 days.");
        console.log("NEXT: verify source on BscScan + Sourcify.");
        console.log("NEXT: AFTER distributor took its 33M, transfer 10,000,000 KONG here (7M stays liquid).");
    }
}
