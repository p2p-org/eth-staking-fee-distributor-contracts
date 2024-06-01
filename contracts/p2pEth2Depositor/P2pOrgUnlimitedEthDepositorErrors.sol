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
/// @param _feeDistributorInstance FeeDistributor instance address
error P2pOrgUnlimitedEthDepositor__InsufficientBalance(address _feeDistributorInstance);

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
/// @param _feeDistributorInstance FeeDistributor instance address
error P2pOrgUnlimitedEthDepositor__NoDepositToReject(address _feeDistributorInstance);

/// @notice Cannot proceed because a deposit for this FeeDistributor instance has already been rejected
/// @param _feeDistributorInstance FeeDistributor instance address
error P2pOrgUnlimitedEthDepositor__ShouldNotBeRejected(address _feeDistributorInstance);

/// @notice Caller should be EIP-7251 enabler (contract deployer)
/// @param _caller caller address
/// @param _eip7251Enabler EIP-7251 enabler address
error P2pOrgUnlimitedEthDepositor__CallerNotEip7251Enabler(address _caller, address _eip7251Enabler);

/// @notice EIP-7251 has not been enabled yet.
error P2pOrgUnlimitedEthDepositor__Eip7251NotEnabledYet();

/// @notice ETH amount per validator must be >= 32 ETH and <= 2048 ETH
/// @param _ethAmountPerValidatorInWei passed ETH amount per validator in wei
error P2pOrgUnlimitedEthDepositor__EthAmountPerValidatorInWeiOutOfRange(uint256 _ethAmountPerValidatorInWei);
