// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title KongVesting — linear vesting with a cliff for $KONG allocations
/// @notice Holds one allocation (treasury 100M or team 100M). The vesting
///         clock starts ONLY when the KongSale calls start() at graduation,
///         so the clock never runs during the sale itself.
/// @dev Schedule: 3-month cliff (90 days) with ZERO release, then linear
///      release over 12 months (365 days). Fully vested at start + 455 days.
///      Anyone may call release(); tokens always go to the beneficiary.
///      There is no owner/admin. If the sale never graduates (refund
///      scenario), start() is never called and the tokens stay locked in
///      this contract forever — by design: without graduation there is no
///      pool and the tokens have no market, and no admin key exists that
///      could move them.
contract KongVesting is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Cliff after vesting start: 90 days, nothing releasable.
    uint256 public constant CLIFF = 90 days;
    /// @notice Linear vesting duration after the cliff: 365 days.
    uint256 public constant DURATION = 365 days;

    IERC20 public immutable token;
    address public immutable beneficiary;
    address public immutable sale;

    /// @notice Timestamp the vesting clock started (set once by the sale
    ///         at graduation). 0 = not started.
    uint256 public startTimestamp;
    /// @notice Tokens already released to the beneficiary.
    uint256 public released;

    event VestingStarted(uint256 indexed startTimestamp);
    event Released(uint256 amount);

    error OnlySale();
    error AlreadyStarted();
    error NotStarted();
    error NothingToRelease();

    modifier onlySale() {
        if (msg.sender != sale) revert OnlySale();
        _;
    }

    constructor(address token_, address beneficiary_, address sale_) {
        require(token_ != address(0), "token zero");
        require(beneficiary_ != address(0), "beneficiary zero");
        require(sale_ != address(0), "sale zero");
        token = IERC20(token_);
        beneficiary = beneficiary_;
        sale = sale_;
    }

    /// @notice Start the vesting clock. Sale only, exactly once, called by
    ///         KongSale.graduate().
    function start(uint256 startTimestamp_) external onlySale {
        if (startTimestamp != 0) revert AlreadyStarted();
        startTimestamp = startTimestamp_;
        emit VestingStarted(startTimestamp_);
    }

    /// @notice Total tokens ever allocated to this contract (balance +
    ///         already released).
    function totalAllocated() public view returns (uint256) {
        return token.balanceOf(address(this)) + released;
    }

    /// @notice Tokens vested (unlocked) so far, including already released.
    function vested() public view returns (uint256) {
        if (startTimestamp == 0) return 0;
        uint256 total = totalAllocated();
        if (block.timestamp < startTimestamp + CLIFF) return 0;
        if (block.timestamp >= startTimestamp + CLIFF + DURATION) return total;
        uint256 elapsed = block.timestamp - (startTimestamp + CLIFF);
        return (total * elapsed) / DURATION;
    }

    /// @notice Tokens releasable right now (vested minus released).
    function releasable() public view returns (uint256) {
        uint256 v = vested();
        return v > released ? v - released : 0;
    }

    /// @notice Release all currently releasable tokens to the beneficiary.
    ///         Callable by anyone.
    function release() external nonReentrant {
        if (startTimestamp == 0) revert NotStarted();
        uint256 amount = releasable();
        if (amount == 0) revert NothingToRelease();
        released += amount;
        emit Released(amount);
        token.safeTransfer(beneficiary, amount);
    }
}
