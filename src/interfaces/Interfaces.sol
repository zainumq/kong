// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Minimal interface for the SPACE ID Agent ID registry (BSC).
/// @dev Only balanceOf is used. NOTE: Agent ID totalSupply() REVERTS —
///      never call it.
interface IAgentID {
    function balanceOf(address account) external view returns (uint256);
}

/// @notice Minimal interface for the PancakeSwap V2 router (BSC).
/// @dev Only addLiquidity is used by KongSale.graduate().
interface IPancakeRouter02 {
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
}
