// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

/// @notice Could not send ETH. Most likely, the receiver is a contract rejecting ETH.
/// @param _receiver receiver address
/// @param _amount amount of ETH is wei
error P2pOrgUnlimitedEthDepositor__FailedToSendEth(address _receiver, uint256 _amount);

/// @notice Deposits must be at least 1 ETH.
error P2pOrgUnlimitedEthDepositor__NoSmallDeposits();

/// @notice Only client can call refund
/// @param _caller address calling refund
/// @param _client actual client address who should be calling
error P2pOrgUnlimitedEthDepositor__CallerNotClient(address _caller, address _client);

/// @notice There is no ETH associated with the provided FeeDistributor instance address
/// @param _depositId ID of client deposit (derived from ETH2 WithdrawalCredentials, ETH amount per validator in wei, fee distributor instance address)
error P2pOrgUnlimitedEthDepositor__InsufficientBalance(bytes32 _depositId);

/// @notice Should wait for block timestamp to become greater than expiration to ask for a refund
/// @param _expiration block timestamp after which the client will be able to get a refund
/// @param _now block timestamp at the time of the actual call
error P2pOrgUnlimitedEthDepositor__WaitForExpiration(uint40 _expiration, uint40 _now);

/// @notice you can deposit only 1 to 400 validators per transaction
error P2pOrgUnlimitedEthDepositor__ValidatorCountError();

/// @notice the amount of ETH does not match the amount of validators
error P2pOrgUnlimitedEthDepositor__EtherValueError();

/// @notice amount of parameters do no match
error P2pOrgUnlimitedEthDepositor__AmountOfParametersError();

/// @notice do not send ETH directly here
error P2pOrgUnlimitedEthDepositor__DoNotSendEthDirectlyHere();

/// @notice Most likely, the client is a contract rejecting ETH.
/// @param _client client address
error P2pOrgUnlimitedEthDepositor__ClientNotAcceptingEth(address _client);

/// @notice _referenceFeeDistributor should implement IFeeDistributor interface
/// @param _passedAddress passed address for _referenceFeeDistributor
error P2pOrgUnlimitedEthDepositor__NotFeeDistributor(address _passedAddress);

/// @notice Should be a FeeDistributorFactory contract
/// @param _passedAddress passed address that does not support IFeeDistributorFactory interface
error P2pOrgUnlimitedEthDepositor__NotFactory(address _passedAddress);

/// @notice There is no active deposit for the given FeeDistributor instance
/// @param _depositId ID of client deposit (derived from ETH2 WithdrawalCredentials, ETH amount per validator in wei, fee distributor instance address)
error P2pOrgUnlimitedEthDepositor__NoDepositToReject(bytes32 _depositId);

/// @notice Cannot proceed because a deposit for this FeeDistributor instance has already been rejected
/// @param _depositId ID of client deposit (derived from ETH2 WithdrawalCredentials, ETH amount per validator in wei, fee distributor instance address)
error P2pOrgUnlimitedEthDepositor__ShouldNotBeRejected(bytes32 _depositId);

/// @notice Caller should be EIP-7251 enabler (contract deployer)
/// @param _caller caller address
/// @param _eip7251Enabler EIP-7251 enabler address
error P2pOrgUnlimitedEthDepositor__CallerNotEip7251Enabler(address _caller, address _eip7251Enabler);

/// @notice EIP-7251 has not been enabled yet.
error P2pOrgUnlimitedEthDepositor__Eip7251NotEnabledYet();

/// @notice ETH amount per validator must be >= 32 ETH and <= 2048 ETH
/// @param _ethAmountPerValidatorInWei passed ETH amount per validator in wei
error P2pOrgUnlimitedEthDepositor__EthAmountPerValidatorInWeiOutOfRange(uint256 _ethAmountPerValidatorInWei);

/// @notice Withdrawal credentials prefix must be either 0x01 or 0x02
error P2pOrgUnlimitedEthDepositor__IncorrectWithdrawalCredentialsPrefix(bytes1 _passedPrefix);

/// @notice Withdrawal credentials bytes 2 - 12 must be zero
error P2pOrgUnlimitedEthDepositor__WithdrawalCredentialsBytesNotZero(bytes32 _eth2WithdrawalCredentials);
