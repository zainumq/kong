// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title KongCommunityVesting — linear vesting with a parameterised schedule for the $KONG community reserve
/// @notice Holds the vested portion of the community reserve: 10,000,000
///         KONG (of the 17M that remains after the 33M KongMerkleDistributor
///         funding; the other 7M stays liquid in Account 16). Locking it
///         here means the vested portion cannot be dumped at once — it
///         unlocks linearly over the deploy-time schedule.
///
///         WHY A NEW CONTRACT (do not "reuse" KongVesting): KongVesting
///         starts only when the KongSale calls start(timestamp) at
///         graduation, and KongSale only ever starts its own two
///         vestings. A standalone KongVesting with sale=KongSale would
///         NEVER start (funds locked forever), and with sale=owner the
///         owner could backdate the timestamp and instantly vest
///         everything. This contract fixes the clock at deploy time
///         instead: startTimestamp = block.timestamp in the constructor,
///         no start() function, no sale dependency, no owner/admin.
///
///         WHY A PARAMETERISED SCHEDULE: the user chose a 30-day full
///         release with a 14-day hard lock first (cliff 14 days, linear
///         16 days) instead of the treasury/team 90-day cliff + 365-day
///         schedule. The schedule is an immutable deploy-time parameter
///         so the release speed is a visible, one-time decision — fixed
///         forever once deployed, never changeable afterwards.
///
/// @dev Schedule (planned mainnet values): cliff 14 days (1,209,600
///      seconds), linear duration 16 days (1,382,400 seconds). Nothing
///      is releasable during the first 14 days; then funds release
///      linearly at ~625,000 KONG/day (at a 10,000,000 allocation),
///      fully vested at deploy + 30 days. Anyone may call release();
///      tokens always go to the beneficiary. There is no owner/admin
///      and no other fund-exit path: if the beneficiary key is lost,
///      the funds stay locked — the same trust model as the
///      treasury/team vestings.
///
///      TRUST NOTE: a 30-day full release (14-day lock + 16-day
///      linear) prevents any movement for two weeks and any instant
///      dump thereafter, but is a much shorter lock than the
///      treasury/team 455-day schedule. This is a deliberate user
///      decision (23 Nov 2026): the community reserve exists to fund
///      community programs, and a 15-month lock would leave it
///      unusable when programs need it.
contract KongCommunityVesting is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Cliff after deploy, in seconds (immutable, constructor
    ///         arg). Nothing is releasable before startTimestamp + cliff.
    ///         Planned mainnet value: 14 days (1,209,600 seconds).
    uint256 public immutable cliff;
    /// @notice Linear vesting duration after the cliff, in seconds
    ///         (immutable, constructor arg). Fully vested at
    ///         startTimestamp + cliff + duration. Planned mainnet value:
    ///         16 days (1,382,400 seconds), so full vesting lands at
    ///         deploy + 30 days.
    uint256 public immutable duration;

    IERC20 public immutable token;
    address public immutable beneficiary;
    /// @notice Timestamp the vesting clock started: fixed at deploy.
    uint256 public immutable startTimestamp;

    /// @notice Tokens already released to the beneficiary.
    uint256 public released;

    event Released(uint256 amount);

    error NothingToRelease();

    constructor(address token_, address beneficiary_, uint256 cliff_, uint256 duration_) {
        require(token_ != address(0), "token zero");
        require(beneficiary_ != address(0), "beneficiary zero");
        require(duration_ > 0, "duration zero");
        token = IERC20(token_);
        beneficiary = beneficiary_;
        cliff = cliff_;
        duration = duration_;
        startTimestamp = block.timestamp;
    }

    /// @notice Total tokens ever allocated to this contract (balance +
    ///         already released).
    function totalAllocated() public view returns (uint256) {
        return token.balanceOf(address(this)) + released;
    }

    /// @notice Tokens vested (unlocked) so far, including already released.
    function vested() public view returns (uint256) {
        uint256 total = totalAllocated();
        if (block.timestamp < startTimestamp + cliff) return 0;
        if (block.timestamp >= startTimestamp + cliff + duration) return total;
        uint256 elapsed = block.timestamp - (startTimestamp + cliff);
        return (total * elapsed) / duration;
    }

    /// @notice Tokens releasable right now (vested minus released).
    function releasable() public view returns (uint256) {
        uint256 v = vested();
        return v > released ? v - released : 0;
    }

    /// @notice Release all currently releasable tokens to the beneficiary.
    ///         Callable by anyone.
    function release() external nonReentrant {
        uint256 amount = releasable();
        if (amount == 0) revert NothingToRelease();
        released += amount;
        emit Released(amount);
        token.safeTransfer(beneficiary, amount);
    }
}
