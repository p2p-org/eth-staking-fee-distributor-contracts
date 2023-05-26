// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

/**
* @notice Failed to send ETH
* @dev Most likely, the receipient is a contract refusing to accept ETH
*/
error P2pOrgUnlimitedEthDepositor__FailedToSendEth(address indexed _receiver, uint256 _wad);

/**
* @notice Insufficient Balance
* @dev
*/
error P2pOrgUnlimitedEthDepositor__InsufficientBalance(address indexed _account);

/**
* @notice you can deposit only 1 to 400 validators per transaction
*/
error P2pOrgUnlimitedEthDepositor__ValidatorCountError();

/**
* @notice the amount of ETH does not match the amount of validators
*/
error P2pOrgUnlimitedEthDepositor__EtherValueError();

/**
* @notice amount of parameters do no match
*/
error P2pOrgUnlimitedEthDepositor__AmountOfParametersError();
