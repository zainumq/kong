// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title KongToken — $KONG
/// @notice ERC-20 utility token for the Kong Alpha project.
/// @dev Total supply is fixed at 1,000,000,000 KONG (18 decimals), minted
///      once to the deployer in the constructor. There is no mint, burn, or
///      owner function after deployment. The deployer distributes the fixed
///      allocation (see README deploy steps):
///        - 485,000,000 (48.5%)  -> KongSale (claims for pass holders)
///        - 250,000,000 (25%)    -> KongSale (liquidity, paired at graduation)
///        -  15,000,000 (1.5%)   -> KongSale (referral reward pool)
///        - 100,000,000 (10%)    -> treasury KongVesting
///        - 100,000,000 (10%)    -> team KongVesting
///        -  50,000,000 (5%)     -> community address
contract KongToken is ERC20 {
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 ether; // 1 billion, 18 decimals

    constructor() ERC20("Kong", "KONG") {
        _mint(msg.sender, TOTAL_SUPPLY);
    }
}
