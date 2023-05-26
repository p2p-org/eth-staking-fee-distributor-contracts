// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

error P2pOrgUnlimitedEthDepositor__FailedToSendEth(address indexed _receiver, uint256 _wad);

error P2pOrgUnlimitedEthDepositor__InsufficientBalance(address indexed _account);

error P2pOrgUnlimitedEthDepositor__ValidatorCountError();

error P2pOrgUnlimitedEthDepositor__EtherValueError();

error P2pOrgUnlimitedEthDepositor__AmountOfParametersError();
