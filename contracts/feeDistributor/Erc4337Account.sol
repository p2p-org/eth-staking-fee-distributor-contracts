// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../erc4337/interfaces/IAccount.sol";
import "../erc4337/interfaces/UserOperation.sol";
import "../access/IOwnableWithOperator.sol";

/// @notice signer should be either of: 1) owner 2) operator 3) client
/// @param _signer address of the signer.
error Erc4337Account__InvalidSigner(address _signer);

/// @notice passed address should be a valid ERC-4337 entryPoint
/// @param _passedAddress passed address
error Erc4337Account__NotEntryPoint(address _passedAddress);

/// @notice data length should be at least 4 byte to be a function signature
error Erc4337Account__DataTooShort();

/// @notice only withdraw function is allowed to be called via ERC-4337 UserOperation
error Erc4337Account__OnlyWithdrawIsAllowed();

/// @title gasless withdraw for FeeDistributors via ERC-4337
abstract contract Erc4337Account is IAccount, IOwnableWithOperator {
    using ECDSA for bytes32;

    /// @notice return value in case of signature failure, with no time-range.
    /// @dev equivalent to _packValidationData(true,0,0);
    uint256 private constant SIG_VALIDATION_FAILED = 1;

    /// @notice withdraw without agruments
    bytes4 private constant defaultWithdrawSelector = bytes4(keccak256("withdraw()"));

    /// @notice Singleton ERC-4337 entryPoint 0.6.0 used by this account
    address payable constant entryPoint = payable(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);

    /// @notice Validate user's signature and nonce.
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external virtual override returns (uint256 validationData) {
        if (msg.sender != entryPoint) {
            revert Erc4337Account__NotEntryPoint(msg.sender);
        }

        validationData = _validateSignature(userOp, userOpHash);
        _payPrefund(missingAccountFunds);
    }

    /// @notice Validates the signature of a user operation.
    function _validateSignature(
        UserOperation calldata userOp,
        bytes32 userOpHash
    ) private view returns (uint256)
    {
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        address signer = hash.recover(userOp.signature);

        if (!isValidSigner(signer, userOp)) return SIG_VALIDATION_FAILED;
        return 0;
    }

    /// @notice Returns whether a signer is authorized to perform transactions using the wallet.
    function isValidSigner(address _signer, UserOperation calldata _userOp) public view virtual returns (bool) {
        if (!(
            _signer == owner() || _signer == operator() || _signer == client()
        )) {
            revert Erc4337Account__InvalidSigner(_signer);
        }

        bytes4 sig = getFunctionSignature(_userOp.callData);

        if (sig != withdrawSig()) {
            revert Erc4337Account__OnlyWithdrawIsAllowed();
        }

        return true;
    }

    function getFunctionSignature(bytes calldata data) internal pure returns (bytes4 functionSelector) {
        if (data.length < 4) {
            revert Erc4337Account__DataTooShort();
        }
        return bytes4(data[:4]);
    }

    /// @notice sends to the entrypoint (msg.sender) the missing funds for this transaction.
    /// @param missingAccountFunds the minimum value this method should send the entrypoint.
    /// this value MAY be zero, in case there is enough deposit, or the userOp has a paymaster.
    function _payPrefund(uint256 missingAccountFunds) private {
        if (missingAccountFunds != 0) {
            (bool success, ) = payable(msg.sender).call{ value: missingAccountFunds, gas: type(uint256).max }("");
            (success);
            //ignore failure (its EntryPoint's job to verify, not account.)
        }
    }

    /// @notice Returns the client address
    /// @return address client address
    function client() public view virtual returns (address);

    /// @inheritdoc IOwnable
    function owner() public view virtual returns (address);

    /// @inheritdoc IOwnableWithOperator
    function operator() public view virtual returns (address);

    /// @notice withdraw function signature
    /// @dev since withdraw function in derived contracts can have arguments, its
    /// signature can vary and can be overridden in derived contracts
    function withdrawSig() public pure virtual returns (bytes4) {
        return defaultWithdrawSelector;
    }
}
