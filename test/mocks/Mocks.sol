// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Mock BSC USDT: ERC-20 with 18 decimals, freely mintable.
///         MUST match mainnet: real BSC USDT (0x55d398326f99059fF775485246999027B3197955)
///         returns decimals() == 18 (verified on-chain 19 Nov 2026). The v2
///         mock used 6 decimals (Ethereum USDT) and hid a critical pricing
///         bug — see KongDecimalsTest.
contract MockUSDT is ERC20 {
    constructor() ERC20("Tether USD", "USDT") {}

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @notice Mock Agent ID registry: only balanceOf, settable per address.
contract MockAgentID {
    mapping(address => uint256) public balanceOf;

    function setBalance(address account, uint256 amount) external {
        balanceOf[account] = amount;
    }
}

/// @notice Mock PancakeSwap V2 router: pulls the tokens via transferFrom and
///         records the call so tests can assert exact graduation amounts.
contract MockRouter {
    uint256 public calls;
    address public lastTokenA;
    address public lastTokenB;
    uint256 public lastAmountA;
    uint256 public lastAmountB;
    uint256 public lastAmountAMin;
    uint256 public lastAmountBMin;
    address public lastTo;
    uint256 public lastDeadline;

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        IERC20(tokenA).transferFrom(msg.sender, address(this), amountADesired);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountBDesired);
        calls += 1;
        lastTokenA = tokenA;
        lastTokenB = tokenB;
        lastAmountA = amountADesired;
        lastAmountB = amountBDesired;
        lastAmountAMin = amountAMin;
        lastAmountBMin = amountBMin;
        lastTo = to;
        lastDeadline = deadline;
        return (amountADesired, amountBDesired, 1 ether);
    }
}

/// @notice Malicious ERC-20 used for reentrancy tests. When armed, its next
///         transfer/transferFrom/mint calls back into an arbitrary target
///         and REVERTS if that callback fails — simulating an attacker
///         token trying to re-enter the sale mid-transfer.
contract MaliciousERC20 is ERC20 {
    address public target;
    bytes public payload;
    bool public armed;

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function arm(address target_, bytes calldata payload_) external {
        target = target_;
        payload = payload_;
        armed = true;
    }

    function _update(address from, address to, uint256 value) internal override {
        super._update(from, to, value);
        if (armed) {
            armed = false;
            (bool ok,) = target.call(payload);
            require(ok, "reenter failed");
        }
    }
}

/// @notice Malicious router used for the graduate() reentrancy test: its
///         addLiquidity tries to re-enter KongSale.graduate().
contract MaliciousRouter {
    address public sale;

    function setSale(address sale_) external {
        sale = sale_;
    }

    function addLiquidity(
        address,
        address,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256,
        uint256,
        address,
        uint256
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        (bool ok,) = sale.call(abi.encodeWithSignature("graduate()"));
        require(ok, "reenter failed");
        return (amountADesired, amountBDesired, 1 ether);
    }
}
