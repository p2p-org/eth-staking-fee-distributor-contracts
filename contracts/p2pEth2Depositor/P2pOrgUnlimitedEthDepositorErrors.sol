// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

error P2pOrgUnlimitedEthDepositor__FailedToSendEth(address _receiver, uint256 _amount);

error P2pOrgUnlimitedEthDepositor__NoZeroDeposits();

error P2pOrgUnlimitedEthDepositor__CallerNotClient(address _caller, address _client);

error P2pOrgUnlimitedEthDepositor__InsufficientBalance(address _feeDistributorInstance);

error P2pOrgUnlimitedEthDepositor__WaitForExpiration(uint40 _expiration, uint40 _now);

error P2pOrgUnlimitedEthDepositor__ValidatorCountError();

error P2pOrgUnlimitedEthDepositor__EtherValueError();

error P2pOrgUnlimitedEthDepositor__AmountOfParametersError();

error P2pOrgUnlimitedEthDepositor__DoNotSendEthDirectlyHere();

error P2pOrgUnlimitedEthDepositor__ClientNotAcceptingEth(address _client);

error P2pOrgUnlimitedEthDepositor__NotFeeDistributor(address _passedAddress);

error P2pOrgUnlimitedEthDepositor__NotFactory(address _passedAddress);
