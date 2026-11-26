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

// src/FeeDistributor.sol

/// @notice Minimal KongMarket interface: only the fee sweep is needed.
interface IKongMarketSweep {
    function sweepFees(address token) external;
}

/// @title FeeDistributor — fee treasury for KongMarket
/// @notice This contract is the `treasury` of the KongMarket mainnet
///         deployment. It receives swept market fees (1% of sales) plus
///         KongMintPass secondary-sale royalties (5%, receiver = treasury),
///         and splits every new USDT 50% holder pool / 30% builder /
///         20% rebate pool. The rebate pool funds the 50% trading-fee
///         rebate for pass holders ("Balik Modal dari Aktivitas Sendiri",
///         25 Nov 2026): rebates first, referral rewards from the
///         remainder, both paid out monthly via Merkle (v1.1 wiring).
///
///         HISTORICAL NOTE (closed 26 Nov 2026): the market used to
///         accept BNB-denominated sales, and a BNB sale's 1% fee was
///         stranded in the market — `sweep()` only ever called
///         `market.sweepFees(address(usdt))` and `split()` accounts USDT
///         only, while `sweepFees(address(0))` could only be called by
///         this contract as treasury and no function here ever called it
///         (proven on testnet 26 Nov 2026: one BNB sale left exactly
///         0.0000269851 tBNB, 1% of the price, unsweepable). The market
///         contract was rewritten USDT-only (KongMarketOracle, testnet
///         26 Nov 2026): `list()`/`floorOf()` revert `InvalidPaymentToken()`
///         for anything but USDT, `buy()` is non-payable, and the oracle
///         price feed was removed — so there is no BNB fee path left to
///         strand, and this contract sweeps USDT by construction.
///         Re-verified 26 Nov 2026: a 2 USDT sale's 0.02 USDT fee split
///         exactly 50/30/20, and list/floor/buy/sweepFees with BNB all
///         revert. (NatSpec-only change: no bytecode change; the deployed
///         testnet contract keeps its earlier verification.)
///
///         TESTNET BUILD (25 Nov 2026, user order: "build testnet aja dulu").
///         Mainnet deploy is NOT part of this build.
///
/// @dev No owner/admin/pause/upgrade — same house style as KongSale.
///      The market address is a ONE-TIME setter (not immutable) only
///      because the market's own constructor needs this contract as its
///      treasury while this contract needs the market's address to sweep:
///      a circular dependency. Deploy order: (1) deploy this contract,
///      (2) deploy KongMarket with treasury = this contract, (3) call
///      setMarket() in the SAME deploy script, immediately. For mainnet,
///      the deploy script must do all three steps back-to-back; a factory
///      that deploys both atomically is the v1.1 hardening.
///      Splits are computed on the BALANCE DELTA (balance - accounted),
///      so no accounting can drift from actual holdings.
///      Holder-pool distribution (monthly Merkle claims) is v1.1 wiring:
///      the pool is accounted here as `holderPool` and funded into the
///      existing audited KongMerkleDistributor from there. Nothing in this
///      contract lets anyone withdraw holder funds.
///      Mint-proceeds seed is split 50/50 between `holderPool` and
///      `rebatePool`, so rebates run from month one, before fee income
///      is meaningful.
contract FeeDistributor is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Fee split (basis points, must sum to 10_000).
    uint256 public constant HOLDER_BPS = 5_000;
    uint256 public constant BUILDER_BPS = 3_000;
    uint256 public constant GROWTH_BPS = 2_000;

    /// @notice USDT (18 decimals on BSC).
    IERC20 public immutable usdt;

    /// @notice Receives the 30% builder share (user's wallet).
    address public immutable builder;

    /// @notice Receives the 20% rebate-pool share (rebates/referrals).
    ///         Withdraws it to fund the monthly Merkle distributions.
    address public immutable growthPool;

    /// @notice The KongMarketPass contract: the ONLY caller of seed().
    ///         Set once via setMarketPass() (same one-time pattern as
    ///         setMarket — the pass constructor needs this contract's
    ///         address while this contract needs the pass's address).
    address public marketPass;

    /// @notice KongMarket contract. Set once via setMarket().
    address public market;

    /// @notice Total USDT already allocated into buckets.
    uint256 public accounted;

    /// @notice USDT owed to pass holders (monthly Merkle distribution, v1.1).
    uint256 public holderPool;

    /// @notice USDT owed to the builder.
    uint256 public builderShare;

    /// @notice USDT funding pass-holder fee rebates (50% of fee paid,
    ///         max 2 USDT/pass/month, pro-rata if short) and, from the
    ///         remainder, referral rewards. Funded by 20% of swept fees
    ///         plus half of every mint-proceeds seed.
    uint256 public rebatePool;

    /// @notice Referral scheme (recorded here; paid monthly via Merkle
    ///         v1.1 from the rebate pool — see contract header). A
    ///         referee's trading fees earn their referrer 10% for 90
    ///         days from the day the referrer was set, capped at 20 USDT
    ///         per referrer per calendar month. Fees are swept in
    ///         aggregate, so this contract has no per-trade accrual:
    ///         the cap and the 90-day window are enforced by the Merkle
    ///         builder at payout time, and the constants below are the
    ///         on-chain source of truth for those parameters.
    uint256 public constant REFERRAL_BPS = 1_000; // 10% of the referee's fee
    uint256 public constant REFERRAL_WINDOW = 90 days;
    uint256 public constant REFERRAL_MONTHLY_CAP = 20 ether; // 20 USDT (18 decimals)

    /// @notice Referrer recorded for each referee (trader).
    ///         address(0) = no referrer recorded.
    mapping(address => address) public referrerOf;

    /// @notice Timestamp when the referee's referrer was set. Start of
    ///         the 90-day referral window.
    mapping(address => uint256) public referrerSetAt;

    /// @notice Timestamp of the first fee income (first sweep/split that
    ///         brought market fees in). 0 = the market has never earned
    ///         fees yet. Read by KongMarketPass for the "launch guarantee":
    ///         a pass refund window extends to 7 days after this moment.
    uint256 public firstSweepAt;

    error MarketAlreadySet();
    error MarketPassAlreadySet();
    error MarketNotSet();
    error NotMarketPass();
    error NotBuilder();
    error NotGrowthPool();
    error NothingNew();
    error InsufficientShare();
    error InvalidReferrer();
    error SelfReferral();
    error ReferrerAlreadySet();

    event MarketSet(address indexed market);
    event MarketPassSet(address indexed marketPass);
    event ReferrerSet(address indexed referee, address indexed referrer, uint256 timestamp);
    event Swept(uint256 amount);
    event Split(uint256 holderAmount, uint256 builderAmount, uint256 rebateAmount);
    event Seeded(uint256 holderAmount, uint256 rebateAmount);
    event FirstSweep(uint256 timestamp);
    event Withdrawn(address indexed to, uint256 amount, uint8 indexed bucket);

    constructor(address usdt_, address builder_, address growthPool_) {
        require(usdt_ != address(0), "usdt zero");
        require(builder_ != address(0), "builder zero");
        require(growthPool_ != address(0), "growth zero");
        usdt = IERC20(usdt_);
        builder = builder_;
        growthPool = growthPool_;
    }

    /// @notice Point this distributor at the KongMarketPass contract.
    ///         One-time; only the pass may call seed(). Call in the deploy
    ///         script right after deploying the pass.
    function setMarketPass(address marketPass_) external {
        if (marketPass != address(0)) revert MarketPassAlreadySet();
        require(marketPass_ != address(0), "marketPass zero");
        marketPass = marketPass_;
        emit MarketPassSet(marketPass_);
    }

    /// @notice Point this distributor at the KongMarket contract. One-time:
    ///         once set it can never change (treasury is immutable on the
    ///         market side too). Call in the deploy script, immediately
    ///         after deploying the market with treasury = this contract.
    function setMarket(address market_) external {
        if (market != address(0)) revert MarketAlreadySet();
        require(market_ != address(0), "market zero");
        market = market_;
        emit MarketSet(market_);
    }

    /// @notice Record the caller's referrer. One-time and self-service
    ///         only: only the trader themselves may set their own
    ///         referrer, the referrer must be a different non-zero
    ///         address, and once set it can never be changed (same
    ///         one-time style as setMarket / setMarketPass). Pure
    ///         recording — it moves no funds and does not touch escrow,
    ///         splits, or withdrawals. The 90-day window starts at the
    ///         recorded timestamp; referral rewards are paid monthly via
    ///         Merkle v1.1 from the rebate pool.
    function setReferrer(address referrer) external {
        if (referrer == address(0)) revert InvalidReferrer();
        if (referrer == msg.sender) revert SelfReferral();
        if (referrerOf[msg.sender] != address(0)) revert ReferrerAlreadySet();
        referrerOf[msg.sender] = referrer;
        referrerSetAt[msg.sender] = block.timestamp;
        emit ReferrerSet(msg.sender, referrer, block.timestamp);
    }

    /// @notice True while a referee's referral window covers `timestamp`:
    ///         a referrer was recorded and the timestamp falls within 90
    ///         days of when it was set. Read by the Merkle builder (and
    ///         anyone verifying a payout) — no funds move here.
    function isReferralActive(address referee, uint256 timestamp) external view returns (bool) {
        address referrer = referrerOf[referee];
        if (referrer == address(0)) return false;
        uint256 start = referrerSetAt[referee];
        return timestamp >= start && timestamp <= start + REFERRAL_WINDOW;
    }

    /// @notice Pull swept fees from the market, then split them 50/30/20.
    ///         Callable by anyone (keeper/cron) — the split is fixed, so
    ///         there is nothing for the caller to gain or manipulate.
    function sweep() external nonReentrant {
        if (market == address(0)) revert MarketNotSet();
        uint256 before = usdt.balanceOf(address(this));
        IKongMarketSweep(market).sweepFees(address(usdt));
        uint256 swept = usdt.balanceOf(address(this)) - before;
        _splitNew(0);
        emit Swept(swept);
    }

    /// @notice Split any unaccounted USDT sitting in this contract (e.g.
    ///         direct royalty transfers) 50/30/20. Callable by anyone.
    function split() external nonReentrant {
        _splitNew(0);
    }

    /// @notice Credit a mint-proceeds seed from the KongMarketPass.
    ///         ONLY the pass contract may call this, and the pass contract
    ///         transfers the USDT + calls seed() atomically in the same tx
    ///         (see KongMarketPass.distributeProceeds), so the seed can
    ///         never be re-split as fee income. The seed is split 50/50
    ///         between the holder pool and the rebate pool.
    function seed() external nonReentrant {
        if (msg.sender != marketPass) revert NotMarketPass();
        _splitNew(1);
    }

    /// @notice Builder withdraws their accumulated 30% share.
    function withdrawBuilder() external nonReentrant {
        if (msg.sender != builder) revert NotBuilder();
        uint256 amount = builderShare;
        if (amount == 0) revert InsufficientShare();
        builderShare = 0;
        usdt.safeTransfer(builder, amount);
        emit Withdrawn(builder, amount, 1);
    }

    /// @notice Growth-pool operator withdraws the accumulated rebate pool
    ///         (20% fee share + half of every seed) to fund the monthly
    ///         Merkle rebate/referral distributions (v1.1 wiring).
    function withdrawGrowth() external nonReentrant {
        if (msg.sender != growthPool) revert NotGrowthPool();
        uint256 amount = rebatePool;
        if (amount == 0) revert InsufficientShare();
        rebatePool = 0;
        usdt.safeTransfer(growthPool, amount);
        emit Withdrawn(growthPool, amount, 2);
    }

    /// @notice Allocate all unaccounted USDT. kind 0 = fee split
    ///         50/30/20 (holder/builder/rebate), kind 1 = mint-proceeds
    ///         seed split 50/50 between holder pool and rebate pool.
    function _splitNew(uint8 kind) internal {
        uint256 balance = usdt.balanceOf(address(this));
        if (balance <= accounted) revert NothingNew();
        uint256 fresh = balance - accounted;
        accounted = balance;
        if (kind == 1) {
            uint256 holderAmount = fresh / 2;
            uint256 rebateAmount = fresh - holderAmount;
            holderPool += holderAmount;
            rebatePool += rebateAmount;
            emit Seeded(holderAmount, rebateAmount);
            emit Split(holderAmount, 0, rebateAmount);
        } else {
            if (firstSweepAt == 0) {
                firstSweepAt = block.timestamp;
                emit FirstSweep(block.timestamp);
            }
            uint256 holderAmount = (fresh * HOLDER_BPS) / 10_000;
            uint256 builderAmount = (fresh * BUILDER_BPS) / 10_000;
            uint256 rebateAmount = fresh - holderAmount - builderAmount;
            holderPool += holderAmount;
            builderShare += builderAmount;
            rebatePool += rebateAmount;
            emit Split(holderAmount, builderAmount, rebateAmount);
        }
    }
}
