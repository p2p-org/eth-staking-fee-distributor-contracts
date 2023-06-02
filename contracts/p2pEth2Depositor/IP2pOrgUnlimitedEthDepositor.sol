// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "../feeDistributor/IFeeDistributor.sol";

interface IP2pOrgUnlimitedEthDepositor is IERC165 {
    event P2pOrgUnlimitedEthDepositor__Deposit(
        address indexed _sender,
        address indexed _feeDistributorInstance,
        uint256 _amount,
        uint40 _expiration
    );

    event P2pOrgUnlimitedEthDepositor__Refund(
        address indexed _client,
        uint256 _amount
    );

    event P2pEth2DepositEvent(
        address indexed _from,
        address indexed _feeDistributorAddress,
        uint256 _validatorCount
    );

    function deposit(
        bytes[] calldata _pubkeys,
        bytes[] calldata _signatures,
        bytes32[] calldata _deposit_data_roots
    ) external;
}
