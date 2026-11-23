// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title KongMerkleDistributor — $KONG community benefit distributor
/// @notice Holds the 33,000,000 KONG community benefit allocation and pays
///         it out to AgentQuest badge holders after the $KONG sale
///         graduates, against ONE combined Merkle root. The three pools
///         (see agentquest-kong-benefit-plan.md + the streak pool):
///           - 10,000,000 KONG holder airdrop (pro-rata by badges held)
///           - 20,000,000 KONG buyer bonus (+20% of claimable, capped,
///             pro-rata scaled off-chain if oversubscribed)
///           -  3,000,000 KONG streak pool (pro-rata by check-in days)
///         Each claimant receives airdrop + bonus + streak in ONE transfer.
///
///         LEAF FORMAT (the off-chain tree builder MUST match this
///         byte-for-byte):
///           leaf = keccak256(abi.encodePacked(index, account,
///                                             airdropAmount, bonusAmount,
///                                             streakAmount))
///         where index is uint256, account is address, and the three
///         amounts are uint256. Parent nodes use OpenZeppelin's
///         MerkleProof (commutative / sorted-pair hashing): each pair is
///         sorted before hashing, i.e. parent = keccak256(min(a,b) ++
///         max(a,b)). The tree builder must use the same sorted-pair
///         rule (e.g. OpenZeppelin StandardMerkleTree, or merkletreejs
///         with sortPairs: true).
///
/// @dev FUNDING MODEL — READ BEFORE DEPLOYING. This contract is funded
///      with the full 33,000,000 KONG BEFORE the $KONG sale opens
///      (1 Dec 2026), so the promised benefits are a verifiable on-chain
///      commitment rather than a promise in a document. That makes the
///      no-leak rule critical (see M-1 in the audit notes):
///
///        * There is NO fund-exit path before the root is set, except
///          the no-root owner reclaim after 2027-03-01 (the sale-failed
///          case). In particular there is no generic withdraw, no
///          emergency rescue, and no way to move KONG before graduation.
///        * claim() is only possible after setRoot(), and setRoot() is
///          only called at graduation (after the snapshot block).
///        * sweepUnclaimed() is time-gated: 180 days after the root is
///          set, or 2027-03-01 if the root was never set.
///
///      GAS-ONLY (user decision 23 Nov 2026): claim() is NONPAYABLE and
///      charges NO fee of any kind. The publicly announced benefit is
///      gas-only; a claim fee would break that promise.
///
///      CLAIM WINDOW: the 180-day window gates the owner's sweep, NOT
///      claims. Claims stay possible after the window until the owner
///      actually sweeps — a claimant who is late but beats the sweep
///      still gets paid. This is deliberate: the sweep is a cleanup
///      mechanism, not a second deadline for holders.
contract KongMerkleDistributor is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice The $KONG token being distributed (mainnet 0x410eAA53...).
    IERC20 public immutable token;

    /// @notice Combined Merkle root for all three pools. Zero until set.
    bytes32 public merkleRoot;

    /// @notice Timestamp when setRoot() was called. Zero until set.
    uint256 public rootSetTime;

    /// @notice Claim window after the root is set; the owner may sweep
    ///         unclaimed funds only after this window closes.
    uint256 public constant CLAIM_WINDOW = 180 days;

    /// @notice Earliest time the owner may reclaim the funds if the root
    ///         was NEVER set (sale-failed case). 2027-03-01 00:00 UTC:
    ///         sale deadline 31 Dec 2026 + 14-day refund window + buffer.
    uint256 public constant NO_ROOT_RECLAIM_TIME = 1803859200;

    /// @dev Uniswap-style claimed bitmap: bit `index % 256` of word
    ///      `index / 256` is 1 once that index has claimed.
    mapping(uint256 => uint256) private claimedBitMap;

    event RootSet(bytes32 indexed root, uint256 timestamp);
    event Claimed(uint256 indexed index, address indexed account, uint256 total);
    event Swept(uint256 amount, address indexed recipient);

    error RootNotSet();
    error RootAlreadySet();
    error AlreadyClaimed();
    error InvalidProof();
    error SweepNotAvailable();

    /// @param token_ The $KONG token address (immutable).
    /// @dev The deployer (Account 16) becomes the owner. The deployer
    ///      MUST fund this contract with 33,000,000 KONG after deploy.
    constructor(address token_) Ownable(msg.sender) {
        require(token_ != address(0), "KongMerkleDistributor: zero token");
        token = IERC20(token_);
    }

    /// @notice Returns true if `index` has already claimed.
    function isClaimed(uint256 index) public view returns (bool) {
        uint256 claimedWord = claimedBitMap[index / 256];
        uint256 claimedBit = (uint256(1) << (index % 256));
        return claimedWord & claimedBit == claimedBit;
    }

    /// @notice Sets the combined Merkle root. Owner only, exactly once.
    /// @dev Called at graduation, after the snapshot block is final and
    ///      the tree has been built + verified off-chain (see the
    ///      pre-root checklist in kong-distributor-design.md). There is
    ///      no way to change the root afterwards — a wrong root can only
    ///      be fixed by deploying a new distributor, so the off-chain
    ///      verification step is load-bearing.
    function setRoot(bytes32 root_) external onlyOwner {
        if (merkleRoot != bytes32(0)) revert RootAlreadySet();
        require(root_ != bytes32(0), "KongMerkleDistributor: zero root");
        merkleRoot = root_;
        rootSetTime = block.timestamp;
        emit RootSet(root_, block.timestamp);
    }

    /// @notice Claims airdrop + bonus + streak for one leaf, in one
    ///         transfer. GAS-ONLY: nonpayable, no fee.
    /// @param index The leaf index in the Merkle tree.
    /// @param account The claimant address (must match the leaf).
    /// @param airdropAmount Airdrop pool amount for this leaf.
    /// @param bonusAmount Buyer-bonus pool amount for this leaf.
    /// @param streakAmount Streak pool amount for this leaf.
    /// @param merkleProof Merkle proof for the leaf.
    /// @dev Anyone may call on behalf of any account (gas payer !=
    ///      claimant is allowed, as in Uniswap's distributor); the
    ///      tokens always go to `account`, never to msg.sender. The
    ///      claimed bit is set BEFORE the transfer (checks-effects-
    ///      interactions) and the function is nonReentrant.
    function claim(
        uint256 index,
        address account,
        uint256 airdropAmount,
        uint256 bonusAmount,
        uint256 streakAmount,
        bytes32[] calldata merkleProof
    ) external nonReentrant {
        if (merkleRoot == bytes32(0)) revert RootNotSet();
        if (isClaimed(index)) revert AlreadyClaimed();

        bytes32 leaf = keccak256(
            abi.encodePacked(index, account, airdropAmount, bonusAmount, streakAmount)
        );
        if (!MerkleProof.verify(merkleProof, merkleRoot, leaf)) revert InvalidProof();

        // Effects before interactions: mark claimed, then pay.
        claimedBitMap[index / 256] |= (uint256(1) << (index % 256));

        uint256 total = airdropAmount + bonusAmount + streakAmount;
        token.safeTransfer(account, total);
        emit Claimed(index, account, total);
    }

    /// @notice Sweeps the ENTIRE remaining KONG balance to the owner.
    /// @dev Allowed only when (a) the root is set AND the 180-day claim
    ///      window has closed, OR (b) the root was never set AND the
    ///      no-root reclaim time (2027-03-01) has passed. Case (b)
    ///      covers a failed sale: no graduation, no root, funds return
    ///      to the community reserve. There is no other fund-exit path.
    function sweepUnclaimed() external onlyOwner nonReentrant {
        bool rootSet = merkleRoot != bytes32(0);
        bool windowClosed = rootSet && block.timestamp > rootSetTime + CLAIM_WINDOW;
        bool noRootReclaim = !rootSet && block.timestamp > NO_ROOT_RECLAIM_TIME;
        if (!windowClosed && !noRootReclaim) revert SweepNotAvailable();

        uint256 balance = token.balanceOf(address(this));
        token.safeTransfer(owner(), balance);
        emit Swept(balance, owner());
    }
}
