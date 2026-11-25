// SPDX-License-Identifier: MIT
pragma solidity =0.8.24 >=0.4.16 >=0.6.2 ^0.8.20;

// lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol

// OpenZeppelin Contracts (last updated v5.4.0) (utils/introspection/IERC165.sol)

/**
 * @dev Interface of the ERC-165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[ERC].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[ERC section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol

// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/StorageSlot.sol)
// This file was procedurally generated from scripts/generate/templates/StorageSlot.js.

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC-1967 implementation slot:
 * ```solidity
 * contract ERC1967 {
 *     // Define the slot. Alternatively, use the SlotDerivation library to derive the slot.
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(newImplementation.code.length > 0);
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * TIP: Consider using this library along with {SlotDerivation}.
 */
library StorageSlot {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    struct Int256Slot {
        int256 value;
    }

    struct StringSlot {
        string value;
    }

    struct BytesSlot {
        bytes value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Int256Slot` with member `value` located at `slot`.
     */
    function getInt256Slot(bytes32 slot) internal pure returns (Int256Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `StringSlot` with member `value` located at `slot`.
     */
    function getStringSlot(bytes32 slot) internal pure returns (StringSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `StringSlot` representation of the string storage pointer `store`.
     */
    function getStringSlot(string storage store) internal pure returns (StringSlot storage r) {
        assembly ("memory-safe") {
            r.slot := store.slot
        }
    }

    /**
     * @dev Returns a `BytesSlot` with member `value` located at `slot`.
     */
    function getBytesSlot(bytes32 slot) internal pure returns (BytesSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BytesSlot` representation of the bytes storage pointer `store`.
     */
    function getBytesSlot(bytes storage store) internal pure returns (BytesSlot storage r) {
        assembly ("memory-safe") {
            r.slot := store.slot
        }
    }
}

// lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol

// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/extensions/IERC20Metadata.sol)

/**
 * @dev Interface for the optional metadata functions from the ERC-20 standard.
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// lib/openzeppelin-contracts/contracts/interfaces/IERC2981.sol

// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC2981.sol)

/**
 * @dev Interface for the NFT Royalty Standard.
 *
 * A standardized way to retrieve royalty payment information for non-fungible tokens (NFTs) to enable universal
 * support for royalty payments across all NFT marketplaces and ecosystem participants.
 */
interface IERC2981 is IERC165 {
    /**
     * @dev Returns how much royalty is owed and to whom, based on a sale price that may be denominated in any unit of
     * exchange. The royalty amount is denominated and should be paid in that same unit of exchange.
     *
     * NOTE: ERC-2981 allows setting the royalty to 100% of the price. In that case all the price would be sent to the
     * royalty receiver and 0 tokens to the seller. Contracts dealing with royalty should consider empty transfers.
     */
    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    ) external view returns (address receiver, uint256 royaltyAmount);
}

// lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol

// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC721/IERC721.sol)

/**
 * @dev Required interface of an ERC-721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon
     *   a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC-721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or
     *   {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon
     *   a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Note that the caller is responsible to confirm that the recipient is capable of receiving ERC-721
     * or else they may be permanently lost. Usage of {safeTransferFrom} prevents loss, though the caller must
     * understand this adds an external call which potentially creates a reentrancy vulnerability.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the address zero.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

// lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol

// OpenZeppelin Contracts (last updated v5.5.0) (utils/ReentrancyGuard.sol)

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If EIP-1153 (transient storage) is available on the chain you're deploying at,
 * consider using {ReentrancyGuardTransient} instead.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 *
 * IMPORTANT: Deprecated. This storage-based reentrancy guard will be removed and replaced
 * by the {ReentrancyGuardTransient} variant in v6.0.
 *
 * @custom:stateless
 */
abstract contract ReentrancyGuard {
    using StorageSlot for bytes32;

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ReentrancyGuard")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant REENTRANCY_GUARD_STORAGE =
        0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00;

    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _reentrancyGuardStorageSlot().getUint256Slot().value = NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    /**
     * @dev A `view` only version of {nonReentrant}. Use to block view functions
     * from being called, preventing reading from inconsistent contract state.
     *
     * CAUTION: This is a "view" modifier and does not change the reentrancy
     * status. Use it only on view functions. For payable or non-payable functions,
     * use the standard {nonReentrant} modifier instead.
     */
    modifier nonReentrantView() {
        _nonReentrantBeforeView();
        _;
    }

    function _nonReentrantBeforeView() private view {
        if (_reentrancyGuardEntered()) {
            revert ReentrancyGuardReentrantCall();
        }
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        _nonReentrantBeforeView();

        // Any calls to nonReentrant after this point will fail
        _reentrancyGuardStorageSlot().getUint256Slot().value = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _reentrancyGuardStorageSlot().getUint256Slot().value = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _reentrancyGuardStorageSlot().getUint256Slot().value == ENTERED;
    }

    function _reentrancyGuardStorageSlot() internal pure virtual returns (bytes32) {
        return REENTRANCY_GUARD_STORAGE;
    }
}

// lib/openzeppelin-contracts/contracts/interfaces/IERC1363.sol

// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC1363.sol)

/**
 * @title IERC1363
 * @dev Interface of the ERC-1363 standard as defined in the https://eips.ethereum.org/EIPS/eip-1363[ERC-1363].
 *
 * Defines an extension interface for ERC-20 tokens that supports executing code on a recipient contract
 * after `transfer` or `transferFrom`, or code on a spender contract after `approve`, in a single transaction.
 */
interface IERC1363 is IERC20, IERC165 {
    /*
     * Note: the ERC-165 identifier for this interface is 0xb0202a11.
     * 0xb0202a11 ===
     *   bytes4(keccak256('transferAndCall(address,uint256)')) ^
     *   bytes4(keccak256('transferAndCall(address,uint256,bytes)')) ^
     *   bytes4(keccak256('transferFromAndCall(address,address,uint256)')) ^
     *   bytes4(keccak256('transferFromAndCall(address,address,uint256,bytes)')) ^
     *   bytes4(keccak256('approveAndCall(address,uint256)')) ^
     *   bytes4(keccak256('approveAndCall(address,uint256,bytes)'))
     */

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferAndCall(address to, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `to`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the allowance mechanism
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferFromAndCall(address from, address to, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the allowance mechanism
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `to`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferFromAndCall(address from, address to, uint256 value, bytes calldata data) external returns (bool);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens and then calls {IERC1363Spender-onApprovalReceived} on `spender`.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function approveAndCall(address spender, uint256 value) external returns (bool);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens and then calls {IERC1363Spender-onApprovalReceived} on `spender`.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @param data Additional data with no specified format, sent in call to `spender`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function approveAndCall(address spender, uint256 value, bytes calldata data) external returns (bool);
}

// lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol

// OpenZeppelin Contracts (last updated v5.7.0) (token/ERC20/utils/SafeERC20.sol)

/**
 * @title SafeERC20
 * @dev Wrappers around ERC-20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    /**
     * @dev An operation with an ERC-20 token failed.
     */
    error SafeERC20FailedOperation(address token);

    /**
     * @dev Indicates a failed `decreaseAllowance` request.
     */
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        if (!_safeTransfer(token, to, value, true)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        if (!_safeTransferFrom(token, from, to, value, true)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Variant of {safeTransfer} that returns a bool instead of reverting if the operation is not successful.
     */
    function trySafeTransfer(IERC20 token, address to, uint256 value) internal returns (bool) {
        return _safeTransfer(token, to, value, false);
    }

    /**
     * @dev Variant of {safeTransferFrom} that returns a bool instead of reverting if the operation is not successful.
     */
    function trySafeTransferFrom(IERC20 token, address from, address to, uint256 value) internal returns (bool) {
        return _safeTransferFrom(token, from, to, value, false);
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     *
     * IMPORTANT: If the token implements ERC-7674 (ERC-20 with temporary allowance), and if the "client"
     * smart contract uses ERC-7674 to set temporary allowances, then the "client" smart contract should avoid using
     * this function. Performing a {safeIncreaseAllowance} or {safeDecreaseAllowance} operation on a token contract
     * that has a non-zero temporary allowance (for that particular owner-spender) will result in unexpected behavior.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `requestedDecrease`. If `token` returns no
     * value, non-reverting calls are assumed to be successful.
     *
     * IMPORTANT: If the token implements ERC-7674 (ERC-20 with temporary allowance), and if the "client"
     * smart contract uses ERC-7674 to set temporary allowances, then the "client" smart contract should avoid using
     * this function. Performing a {safeIncreaseAllowance} or {safeDecreaseAllowance} operation on a token contract
     * that has a non-zero temporary allowance (for that particular owner-spender) will result in unexpected behavior.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 requestedDecrease) internal {
        unchecked {
            uint256 currentAllowance = token.allowance(address(this), spender);
            if (currentAllowance < requestedDecrease) {
                revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
            }
            forceApprove(token, spender, currentAllowance - requestedDecrease);
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     *
     * NOTE: If the token implements ERC-7674, this function will not modify any temporary allowance. This function
     * only sets the "standard" allowance. Any temporary allowance will remain active, in addition to the value being
     * set here.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        if (!_safeApprove(token, spender, value, false)) {
            if (!_safeApprove(token, spender, 0, true)) revert SafeERC20FailedOperation(address(token));
            if (!_safeApprove(token, spender, value, true)) revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Performs an {ERC1363} transferAndCall, with a fallback to the simple {ERC20} transfer if the target has no
     * code. This can be used to implement an {ERC721}-like safe transfer that relies on {ERC1363} checks when
     * targeting contracts.
     *
     * Reverts if the returned value is other than `true`.
     */
    function transferAndCallRelaxed(IERC1363 token, address to, uint256 value, bytes memory data) internal {
        if (to.code.length == 0) {
            safeTransfer(token, to, value);
        } else if (!token.transferAndCall(to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Performs an {ERC1363} transferFromAndCall, with a fallback to the simple {ERC20} transferFrom if the target
     * has no code. This can be used to implement an {ERC721}-like safe transfer that relies on {ERC1363} checks when
     * targeting contracts.
     *
     * Reverts if the returned value is other than `true`.
     */
    function transferFromAndCallRelaxed(
        IERC1363 token,
        address from,
        address to,
        uint256 value,
        bytes memory data
    ) internal {
        if (to.code.length == 0) {
            safeTransferFrom(token, from, to, value);
        } else if (!token.transferFromAndCall(from, to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Performs an {ERC1363} approveAndCall, with a fallback to the simple {ERC20} approve if the target has no
     * code. This can be used to implement an {ERC721}-like safe transfer that rely on {ERC1363} checks when
     * targeting contracts.
     *
     * NOTE: When the recipient address (`to`) has no code (i.e. is an EOA), this function behaves as {forceApprove}.
     * Oppositely, when the recipient address (`to`) has code, this function only attempts to call {ERC1363-approveAndCall}
     * once without retrying, and relies on the returned value to be true.
     *
     * Reverts if the returned value is other than `true`.
     */
    function approveAndCallRelaxed(IERC1363 token, address to, uint256 value, bytes memory data) internal {
        if (to.code.length == 0) {
            forceApprove(token, to, value);
        } else if (!token.approveAndCall(to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /// @dev Attempts to fetch the token decimals. A return value of false indicates that the attempt failed in some way.
    function tryGetDecimals(IERC20 token) internal view returns (bool success, uint8 decimals) {
        bytes4 selector = IERC20Metadata.decimals.selector;
        assembly ("memory-safe") {
            mstore(0x00, selector)
            success := staticcall(gas(), token, 0x00, 4, 0x00, 0x20)
            success := and(and(success, gt(returndatasize(), 0x1f)), lt(mload(0x00), 0x100))
            decimals := mul(success, mload(0x00))
        }
    }

    /**
     * @dev Imitates a Solidity `token.transfer(to, value)` call, relaxing the requirement on the return value: the
     * return value is optional (but if data is returned, it must not be false).
     *
     * @param token The token targeted by the call.
     * @param to The recipient of the tokens
     * @param value The amount of token to transfer
     * @param bubble Behavior switch if the transfer call reverts: bubble the revert reason or return a false boolean.
     */
    function _safeTransfer(IERC20 token, address to, uint256 value, bool bubble) private returns (bool success) {
        bytes4 selector = IERC20.transfer.selector;

        assembly ("memory-safe") {
            let fmp := mload(0x40)
            mstore(0x00, selector)
            mstore(0x04, and(to, shr(96, not(0))))
            mstore(0x24, value)
            success := call(gas(), token, 0, 0x00, 0x44, 0x00, 0x20)
            // if call success and return is true, all is good.
            // otherwise (not success or return is not true), we need to perform further checks
            if iszero(and(success, eq(mload(0x00), 1))) {
                // if the call was a failure and bubble is enabled, bubble the error
                if and(iszero(success), bubble) {
                    returndatacopy(fmp, 0x00, returndatasize())
                    revert(fmp, returndatasize())
                }
                // if the return value is not true, then the call is only successful if:
                // - the token address has code
                // - the returndata is empty
                success := and(success, and(iszero(returndatasize()), gt(extcodesize(token), 0)))
            }
            mstore(0x40, fmp)
        }
    }

    /**
     * @dev Imitates a Solidity `token.transferFrom(from, to, value)` call, relaxing the requirement on the return
     * value: the return value is optional (but if data is returned, it must not be false).
     *
     * @param token The token targeted by the call.
     * @param from The sender of the tokens
     * @param to The recipient of the tokens
     * @param value The amount of token to transfer
     * @param bubble Behavior switch if the transfer call reverts: bubble the revert reason or return a false boolean.
     */
    function _safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value,
        bool bubble
    ) private returns (bool success) {
        bytes4 selector = IERC20.transferFrom.selector;

        assembly ("memory-safe") {
            let fmp := mload(0x40)
            mstore(0x00, selector)
            mstore(0x04, and(from, shr(96, not(0))))
            mstore(0x24, and(to, shr(96, not(0))))
            mstore(0x44, value)
            success := call(gas(), token, 0, 0x00, 0x64, 0x00, 0x20)
            // if call success and return is true, all is good.
            // otherwise (not success or return is not true), we need to perform further checks
            if iszero(and(success, eq(mload(0x00), 1))) {
                // if the call was a failure and bubble is enabled, bubble the error
                if and(iszero(success), bubble) {
                    returndatacopy(fmp, 0x00, returndatasize())
                    revert(fmp, returndatasize())
                }
                // if the return value is not true, then the call is only successful if:
                // - the token address has code
                // - the returndata is empty
                success := and(success, and(iszero(returndatasize()), gt(extcodesize(token), 0)))
            }
            mstore(0x40, fmp)
            mstore(0x60, 0)
        }
    }

    /**
     * @dev Imitates a Solidity `token.approve(spender, value)` call, relaxing the requirement on the return value:
     * the return value is optional (but if data is returned, it must not be false).
     *
     * @param token The token targeted by the call.
     * @param spender The spender of the tokens
     * @param value The amount of token to approve
     * @param bubble Behavior switch if the approve call reverts: bubble the revert reason or return a false boolean.
     */
    function _safeApprove(IERC20 token, address spender, uint256 value, bool bubble) private returns (bool success) {
        bytes4 selector = IERC20.approve.selector;

        assembly ("memory-safe") {
            let fmp := mload(0x40)
            mstore(0x00, selector)
            mstore(0x04, and(spender, shr(96, not(0))))
            mstore(0x24, value)
            success := call(gas(), token, 0, 0x00, 0x44, 0x00, 0x20)
            // if call success and return is true, all is good.
            // otherwise (not success or return is not true), we need to perform further checks
            if iszero(and(success, eq(mload(0x00), 1))) {
                // if the call was a failure and bubble is enabled, bubble the error
                if and(iszero(success), bubble) {
                    returndatacopy(fmp, 0x00, returndatasize())
                    revert(fmp, returndatasize())
                }
                // if the return value is not true, then the call is only successful if:
                // - the token address has code
                // - the returndata is empty
                success := and(success, and(iszero(returndatasize()), gt(extcodesize(token), 0)))
            }
            mstore(0x40, fmp)
        }
    }
}

// src/KongMarketOracle.sol

/// @title IKongMintPass — minimal interface KongMarketOracle needs from the pass
/// @notice Only the ERC-721 transfer/approval reads, the ERC-2981 royalty
///         read, and the per-token tier. The market never mints or burns.
interface IKongMintPass is IERC721, IERC2981 {
    function tierOf(uint256 tokenId) external view returns (uint8);
}

/// @title IAggregatorV3 — minimal Chainlink price-feed interface
/// @notice Only the two reads this contract uses. The full
///         AggregatorV3Interface also has description(), version() and
///         getRoundData(), which are not needed here, so no Chainlink
///         package dependency is pulled in.
interface IAggregatorV3 {
    function decimals() external view returns (uint8);
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

/// @title KongMarketOracle — fixed-price marketplace for KongMintPass with a Chainlink-driven BNB floor (BSC)
/// @notice Same marketplace as KongMarket (v1), except the BNB price floor
///         is DYNAMIC: it tracks the Chainlink BNB/USD feed instead of
///         being frozen at deploy time.
///
///         Non-custodial: the seller keeps the pass and only approves this
///         contract (`approve` per token or `setApprovalForAll`). The pass
///         and the payment move in a single `buy` transaction.
///
///         Payment is USDT (18 decimals on BSC) or native BNB, chosen per
///         listing (`paymentToken` = USDT address or `address(0)`).
///
///         Every sale splits the price three ways, enforced on-chain:
///         - royalty, read LIVE from `pass.royaltyInfo(tokenId, price)`
///           and paid to the receiver it returns (5% to treasury on the
///           real KongMintPass — never hardcoded here);
///         - fee, 1% (100 bps), kept in this contract and withdrawable
///           only by treasury via `sweepFees()`;
///         - the remainder (price - royalty - fee) to the seller, so no
///           rounding dust is ever lost.
///
///         Price floors (per tier, read live from `pass.tierOf(tokenId)`):
///         - USDT floor: FIXED, immutable per tier (1 / 1.5 / 2 USDT).
///           It never touches the oracle, so USDT listings work even
///           while the feed is down.
///         - BNB floor: DYNAMIC, `floorUsdt(tier) * 1e8 / bnbUsdPrice`,
///           where `bnbUsdPrice` is the Chainlink BNB/USD answer
///           (8 decimals). Integer division rounds DOWN, so the BNB floor
///           is at most 1 wei below the exact USDT value.
///
///         Fail-closed oracle design: a BNB floor read — and therefore a
///         BNB listing or BNB price update — REVERTS with `StalePrice()`
///         when the feed is stale (older than `maxStaleness`), the answer
///         is <= 0, the round is incomplete (`answeredInRound < roundId`),
///         or the timestamp is in the future. USDT listings, USDT price
///         updates and `cancel` (any currency) are unaffected by a feed
///         outage, so a seller can always exit a listing.
///
/// @dev ORACLE ASSUMPTIONS (read before deploying):
///      - USDT ≈ USD. The BNB floor converts the USDT floor through the
///        BNB/USD price, i.e. it assumes 1 USDT = $1. A USDT depeg
///        misprices the BNB floor by the same percentage (a depegged
///        USDT makes the BNB floor too HIGH in real terms).
///      - The feed is the Chainlink BNB/USD proxy for the deployment
///        chain (8 decimals — enforced in the constructor). The proxy
///        address is immutable here, but Chainlink can upgrade the
///        aggregator behind the proxy; that is a trust assumption on
///        Chainlink's feed operations, shared by all consumers.
///      - `maxStaleness` is a DEPLOYMENT parameter, not a constant,
///        because the same feed has different heartbeats per chain:
///        BNB/USD updates ~every 30s on BSC mainnet (60s heartbeat) but
///        only ~hourly on BSC testnet (3600s heartbeat) — measured live
///        22 Nov 2026. Deploy with 2x the target chain's heartbeat:
///        120s on mainnet (56), 7200s on testnet (97). A mainnet-tight
///        threshold on testnet would brick BNB listings permanently;
///        a testnet-loose threshold on mainnet would accept hour-old
///        prices.
///      - The floor is enforced at LIST / UPDATE-PRICE time, not at BUY
///        time (same as v1). If BNB falls after a listing is created,
///        the listed BNB price can drift below the live floor; the
///        listing stays buyable at the agreed price. The seller can
///        always `cancel` or `updatePrice` (the latter re-checks the
///        live floor).
///
///      NO owner/admin/pause/upgrade. Pass, USDT, treasury, fee, USDT
///      floors, price feed and maxStaleness are immutable
///      (constructor-set). The only special role is treasury calling
///      `sweepFees()` — it cannot change the fee, the royalty, the feed,
///      or any other parameter.
///
///      The only funds ever held by this contract are the accumulated 1%
///      fees (USDT and BNB). It never holds NFTs.
contract KongMarketOracle is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Marketplace fee in basis points: 100 = 1%.
    uint256 public constant FEE_BPS = 100;
    /// @notice Basis-points denominator.
    uint256 public constant BPS_DENOMINATOR = 10_000;
    /// @notice Chainlink BNB/USD feed decimals (10^8 scaling).
    uint256 private constant FEED_DECIMALS_SCALING = 1e8;

    /// @notice The pass collection traded here.
    IKongMintPass public immutable pass;
    /// @notice BSC USDT (18 decimals).
    IERC20 public immutable usdt;
    /// @notice Only this address may call `sweepFees()`.
    address public immutable treasury;
    /// @notice Chainlink BNB/USD price feed (proxy, 8 decimals).
    IAggregatorV3 public immutable priceFeed;
    /// @notice Max age (seconds) of a feed answer before BNB floor reads
    ///         revert. Set at deploy to 2x the target chain's feed
    ///         heartbeat (120s mainnet / 7200s testnet).
    uint256 public immutable maxStaleness;

    // USDT price floors per tier (1/2/3). Immutable: Solidity does not
    // allow `immutable` arrays, so the three values are stored as
    // individual immutables (same pattern as KongMarket's floors).
    // BNB floors are DERIVED from these via the feed — see floorOf().
    uint256 private immutable _floorUsdtTier1;
    uint256 private immutable _floorUsdtTier2;
    uint256 private immutable _floorUsdtTier3;

    /// @notice One active listing. Inactive when `seller == address(0)`.
    struct Listing {
        address seller;
        uint256 price;
        address paymentToken; // USDT address, or address(0) for BNB
    }

    mapping(uint256 tokenId => Listing listing) private _listings;

    event Listed(
        address indexed seller, uint256 indexed tokenId, uint256 price, address paymentToken
    );
    event PriceUpdated(uint256 indexed tokenId, uint256 newPrice);
    event Cancelled(uint256 indexed tokenId);
    event Sold(
        address indexed seller,
        address indexed buyer,
        uint256 indexed tokenId,
        uint256 price,
        address paymentToken
    );
    event FeesSwept(address indexed token, uint256 amount);

    error InvalidTier();
    error InvalidPaymentToken();
    error InvalidPrice();
    error InvalidFloor();
    error BelowFloor();
    error NotPassOwner();
    error NotSeller();
    error NoListing();
    error SelfPurchase();
    error OwnershipChanged();
    error NotApproved();
    error IncorrectValue();
    error ValueNotAllowed();
    error PriceAboveMax();
    error InvalidRoyalty();
    error NotTreasury();
    error NothingToSweep();
    error TransferFailed();
    /// @notice The Chainlink feed answer is stale, non-positive, from an
    ///         incomplete round, or timestamped in the future. BNB floor
    ///         reads (and therefore BNB listings / BNB price updates)
    ///         revert with this; USDT flows are unaffected.
    error StalePrice();

    constructor(
        address pass_,
        address usdt_,
        address treasury_,
        uint256[3] memory floorUsdt_,
        address priceFeed_,
        uint256 maxStaleness_
    ) {
        require(pass_ != address(0), "pass zero");
        require(usdt_ != address(0), "usdt zero");
        require(treasury_ != address(0), "treasury zero");
        require(priceFeed_ != address(0), "feed zero");
        require(maxStaleness_ > 0, "maxStaleness zero");
        // A zero floor would let a pass be listed for dust (1 wei),
        // defeating the floor's purpose (protect sellers from panic
        // selling below their mint cost). Floors are the mint prices,
        // always > 0.
        require(floorUsdt_[0] > 0 && floorUsdt_[1] > 0 && floorUsdt_[2] > 0, "usdt floor zero");
        // Floors must rise with the tier (T1 < T2 < T3): a transposed
        // pair at deploy time is permanent (all parameters are
        // immutable) and would silently weaken the floor protection
        // for one tier. Audit L-3 (carried over from v1).
        if (!(floorUsdt_[0] < floorUsdt_[1] && floorUsdt_[1] < floorUsdt_[2])) {
            revert InvalidFloor();
        }
        // The feed must be a deployed contract returning 8 decimals —
        // pointing at the wrong feed (or an EOA) would silently
        // misprice every BNB floor by orders of magnitude. decimals()
        // is a view call on an already-deployed contract, so it is
        // safe to read in the constructor.
        require(priceFeed_.code.length > 0, "feed has no code");
        require(IAggregatorV3(priceFeed_).decimals() == 8, "feed decimals != 8");

        pass = IKongMintPass(pass_);
        usdt = IERC20(usdt_);
        treasury = treasury_;
        priceFeed = IAggregatorV3(priceFeed_);
        maxStaleness = maxStaleness_;
        _floorUsdtTier1 = floorUsdt_[0];
        _floorUsdtTier2 = floorUsdt_[1];
        _floorUsdtTier3 = floorUsdt_[2];
    }

    // ---- Views ----

    /// @notice Price floor for a tier (1/2/3) in a currency (USDT address
    ///         or `address(0)` for BNB).
    /// @dev USDT: fixed immutable value, no oracle read. BNB: derived
    ///      live from the Chainlink feed — reverts with `StalePrice()`
    ///      when the feed answer fails validation (see `_latestPrice`).
    function floorOf(uint8 tier, address paymentToken) public view returns (uint256) {
        if (tier < 1 || tier > 3) revert InvalidTier();
        uint256 floorUsdt;
        if (tier == 1) floorUsdt = _floorUsdtTier1;
        else if (tier == 2) floorUsdt = _floorUsdtTier2;
        else floorUsdt = _floorUsdtTier3;
        if (paymentToken == address(usdt)) {
            return floorUsdt;
        }
        if (paymentToken == address(0)) {
            // floorBnb = floorUsdt * 1e8 / bnbUsdPrice. Overflow-safe:
            // floorUsdt <= 2e18, so the intermediate is <= 2e26, far
            // below 2^256. Rounds DOWN (at most 1 wei below exact).
            (uint256 price,) = _latestPrice();
            return (floorUsdt * FEED_DECIMALS_SCALING) / price;
        }
        revert InvalidPaymentToken();
    }

    /// @notice The active listing for a tokenId, or an empty listing
    ///         (`seller == address(0)`) when nothing is listed.
    function listingOf(uint256 tokenId) public view returns (Listing memory) {
        return _listings[tokenId];
    }

    /// @notice The validated Chainlink BNB/USD answer (8 decimals) and
    ///         its update timestamp. Reverts with `StalePrice()` on any
    ///         validation failure. Frontend helper: the market page can
    ///         show the live BNB price without calling the feed itself.
    function latestBnbPrice() external view returns (uint256 price, uint256 updatedAt) {
        return _latestPrice();
    }

    // ---- Listing ----

    /// @notice List a pass for sale at `price` in `paymentToken` (USDT
    ///         address or `address(0)` for BNB). Caller must own the pass;
    ///         `price` must be > 0 and >= the floor of the pass's tier
    ///         (tier read live from the pass contract; BNB floor read
    ///         live from the Chainlink feed).
    /// @dev No approval is required to list — approval is checked at buy
    ///      time. Re-listing an already-listed token overwrites the old
    ///      listing (same effect as `updatePrice` plus a currency change);
    ///      only the current owner can do so, which also lets a new owner
    ///      replace a stale listing left behind by a previous owner.
    ///      A BNB listing reverts with `StalePrice()` while the feed is
    ///      down; a USDT listing is unaffected.
    function list(uint256 tokenId, uint256 price, address paymentToken) external {
        if (paymentToken != address(usdt) && paymentToken != address(0)) {
            revert InvalidPaymentToken();
        }
        if (price == 0) revert InvalidPrice();
        // ownerOf reverts for a nonexistent (never minted / burned) token.
        if (pass.ownerOf(tokenId) != msg.sender) revert NotPassOwner();
        uint8 tier = pass.tierOf(tokenId);
        if (price < floorOf(tier, paymentToken)) revert BelowFloor();

        _listings[tokenId] = Listing({seller: msg.sender, price: price, paymentToken: paymentToken});
        emit Listed(msg.sender, tokenId, price, paymentToken);
    }

    /// @notice Change the price of your own active listing. The new price
    ///         must be > 0 and >= the floor of the pass's tier, in the
    ///         listing's own currency (the currency cannot be changed —
    ///         cancel and re-list to switch currency). The BNB floor is
    ///         re-read live, so a repricing can fail with `StalePrice()`
    ///         during a feed outage — cancel still works then.
    /// @dev Reads the tier live, so this reverts on a listing whose pass
    ///      was burned after listing (its tier reads 0). Cancel such a
    ///      listing instead — `cancel` does not read the tier.
    function updatePrice(uint256 tokenId, uint256 newPrice) external {
        Listing storage listing = _listings[tokenId];
        if (listing.seller == address(0)) revert NoListing();
        if (listing.seller != msg.sender) revert NotSeller();
        if (newPrice == 0) revert InvalidPrice();
        uint8 tier = pass.tierOf(tokenId);
        if (newPrice < floorOf(tier, listing.paymentToken)) revert BelowFloor();

        listing.price = newPrice;
        emit PriceUpdated(tokenId, newPrice);
    }

    /// @notice Cancel your own active listing. Works even if the listing
    ///         went stale (pass transferred or burned after listing) and
    ///         even during a Chainlink feed outage — it never reads the
    ///         tier or the price.
    function cancel(uint256 tokenId) external {
        Listing storage listing = _listings[tokenId];
        if (listing.seller == address(0)) revert NoListing();
        if (listing.seller != msg.sender) revert NotSeller();

        delete _listings[tokenId];
        emit Cancelled(tokenId);
    }

    // ---- Buying ----

    /// @notice Buy a listed pass. For a BNB listing, send exactly `price`
    ///         as `msg.value`; for a USDT listing, send no BNB and approve
    ///         this contract for `price` USDT first.
    /// @param tokenId The listed pass to buy.
    /// @param maxPrice The highest price the buyer is willing to pay, in
    ///        the listing's currency. The buy reverts with `PriceAboveMax`
    ///        if the listing's current price exceeds it — this protects
    ///        the buyer from a seller front-running `updatePrice` between
    ///        the moment the buyer reads the price and the buy executes
    ///        (audit M-1, carried over from v1). Pass the price shown in
    ///        the UI; if the seller LOWERED the price since, the buyer pays
    ///        the new (lower) price, not `maxPrice`. For a BNB listing,
    ///        `msg.value` must still equal the (current) price exactly,
    ///        AND the price must be <= `maxPrice`.
    /// @dev The floor is NOT re-checked at buy time (same as v1): a
    ///      listing is a firm offer at the price the seller set. If BNB
    ///      fell after listing, the price may sit below the live floor —
    ///      the buy still executes at the agreed price.
    ///
    ///      Checks-effects-interactions: the listing is deleted BEFORE any
    ///      transfer, and the function is nonReentrant, so a malicious
    ///      buyer/seller/royalty-receiver contract cannot re-enter `buy`
    ///      (or any other guarded function) mid-sale.
    ///
    ///      Split (all in the listing's currency):
    ///      - royalty = `pass.royaltyInfo(tokenId, price)` (live), paid to
    ///        the returned receiver;
    ///      - fee = price * 100 / 10_000 (rounds down), stays in this
    ///        contract until treasury sweeps it;
    ///      - seller = price - royalty - fee (the remainder, so no dust
    ///        is lost to rounding).
    function buy(uint256 tokenId, uint256 maxPrice) external payable nonReentrant {
        Listing memory listing = _listings[tokenId];
        if (listing.seller == address(0)) revert NoListing();
        if (listing.price == 0) revert InvalidPrice();
        // Price protection (audit M-1): the seller may have raised the
        // price after the buyer read it — never charge more than the
        // buyer agreed to. Checked before the value checks so a
        // front-run price hike fails here with a clear error instead of
        // a misleading IncorrectValue.
        if (listing.price > maxPrice) revert PriceAboveMax();
        if (msg.sender == listing.seller) revert SelfPurchase();
        // Stale-listing guards: the seller must still own the pass
        // (ownerOf reverts if the pass was burned, e.g. claimed) and the
        // market must still be approved to move it.
        if (pass.ownerOf(tokenId) != listing.seller) revert OwnershipChanged();
        if (
            pass.getApproved(tokenId) != address(this)
                && !pass.isApprovedForAll(listing.seller, address(this))
        ) revert NotApproved();

        uint256 price = listing.price;
        // Value checks up front (before any effects): a BNB listing must
        // be paid with exactly `price` as msg.value (no over/under-payment,
        // so no refund logic and no stuck dust); a USDT listing must carry
        // no BNB at all (it would otherwise be stuck in the contract —
        // nothing here could return it).
        if (listing.paymentToken == address(0)) {
            if (msg.value != price) revert IncorrectValue();
        } else {
            if (msg.value != 0) revert ValueNotAllowed();
        }

        (address royaltyReceiver, uint256 royaltyAmount) = pass.royaltyInfo(tokenId, price);
        uint256 feeAmount = (price * FEE_BPS) / BPS_DENOMINATOR;
        // The real pass charges 5%, so this can only trigger on a pass
        // contract whose royalty was (mis)configured above 99% — but a
        // checked-math underflow would revert with a bare panic, so fail
        // with a named error instead.
        if (royaltyAmount + feeAmount > price) revert InvalidRoyalty();
        uint256 sellerAmount = price - royaltyAmount - feeAmount;

        // Effects first: delete the listing before any external call.
        delete _listings[tokenId];
        emit Sold(listing.seller, msg.sender, tokenId, price, listing.paymentToken);

        if (listing.paymentToken == address(0)) {
            if (royaltyAmount > 0) {
                _sendBnb(royaltyReceiver, royaltyAmount);
            }
            if (sellerAmount > 0) {
                _sendBnb(listing.seller, sellerAmount);
            }
            // feeAmount stays in this contract.
        } else {
            // Pull the full price, then pay out royalty + seller; the fee
            // stays in this contract.
            usdt.safeTransferFrom(msg.sender, address(this), price);
            if (royaltyAmount > 0) {
                usdt.safeTransfer(royaltyReceiver, royaltyAmount);
            }
            if (sellerAmount > 0) {
                usdt.safeTransfer(listing.seller, sellerAmount);
            }
        }

        // NFT last: a malicious buyer contract's onERC721Received hook
        // runs after all funds have moved and the listing is gone, and
        // re-entry is blocked by the guard.
        pass.safeTransferFrom(listing.seller, msg.sender, tokenId);
    }

    // ---- Fee sweep ----

    /// @notice Send ALL accumulated fees in `token` (USDT address or
    ///         `address(0)` for BNB) to treasury. Treasury only.
    /// @dev Sweeps the whole balance rather than a tracked fee total: the
    ///      contract never receives these tokens any other way in normal
    ///      operation (USDT only enters via `buy`, BNB only as exact
    ///      `msg.value` in `buy`, and plain BNB transfers revert — see
    ///      `receive()`), so the whole balance IS the accumulated fee.
    ///      USDT sent here directly by mistake is swept to treasury as
    ///      well — that is the intended recovery, not a bug. (BNB can
    ///      still be force-sent via `selfdestruct`; sweeping recovers it
    ///      the same way.)
    function sweepFees(address token) external nonReentrant {
        if (msg.sender != treasury) revert NotTreasury();
        if (token == address(0)) {
            uint256 amount = address(this).balance;
            if (amount == 0) revert NothingToSweep();
            emit FeesSwept(token, amount);
            _sendBnb(treasury, amount);
        } else if (token == address(usdt)) {
            uint256 amount = usdt.balanceOf(address(this));
            if (amount == 0) revert NothingToSweep();
            emit FeesSwept(token, amount);
            usdt.safeTransfer(treasury, amount);
        } else {
            revert InvalidPaymentToken();
        }
    }

    // ---- Internal ----

    /// @notice Read the Chainlink BNB/USD answer with full fail-closed
    ///         validation. Reverts with `StalePrice()` when:
    ///         - the answer is <= 0 (feed error / uninitialized),
    ///         - `updatedAt` is 0 (no round ever answered),
    ///         - `updatedAt` is in the future (clock skew — the
    ///           subtraction below would otherwise underflow),
    ///         - the answer is older than `maxStaleness`,
    ///         - the round is incomplete (`answeredInRound < roundId`,
    ///           i.e. the reported answer belongs to an older round).
    /// @return price The BNB/USD price, 8 decimals, as a uint256.
    /// @return updatedAt The timestamp of the validated answer.
    function _latestPrice() internal view returns (uint256 price, uint256 updatedAt) {
        (uint80 roundId, int256 answer, , uint256 updatedAt_, uint80 answeredInRound) =
            priceFeed.latestRoundData();
        if (answer <= 0) revert StalePrice();
        if (updatedAt_ == 0 || updatedAt_ > block.timestamp) revert StalePrice();
        if (block.timestamp - updatedAt_ > maxStaleness) revert StalePrice();
        if (answeredInRound < roundId) revert StalePrice();
        return (uint256(answer), updatedAt_);
    }

    /// @notice Send BNB with a plain call (no gas stipend — the receiver
    ///         may be a contract) and revert if it fails.
    function _sendBnb(address to, uint256 amount) internal {
        (bool ok,) = to.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    /// @notice Reject plain BNB transfers: BNB may only enter via `buy`
    ///         (exact `msg.value`). Without this, a mistaken direct
    ///         transfer would be swept to treasury as if it were a fee
    ///         instead of reverting at the sender.
    receive() external payable {
        revert TransferFailed();
    }
}

