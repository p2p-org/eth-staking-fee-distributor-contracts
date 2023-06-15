// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "../structs/P2pStructs.sol";

interface IFeeDistributor is IERC165 {

    event FeeDistributor__Initialized(
        address indexed _client,
        uint96 _clientBasisPoints,
        address indexed _referrer,
        uint96 _referrerBasisPoints
    );

    event FeeDistributor__Withdrawn(
        uint256 _serviceAmount,
        uint256 _clientAmount,
        uint256 _referrerAmount
    );

    event FeeDistributor__VoluntaryExit(
        bytes[] _pubkeys
    );

    event FeeDistributor__EtherRecovered(
        address indexed _to,
        uint256 _amount
    );

    event FeeDistributor__EtherRecoveryFailed(
        address indexed _to,
        uint256 _amount
    );

    function initialize(
        FeeRecipient calldata _clientConfig,
        FeeRecipient calldata _referrerConfig
    ) external;

    function increaseDepositedCount(uint32 _validatorCountToAdd) external;

    function voluntaryExit(bytes[] calldata _pubkeys) external;

    function factory() external view returns (address);

    function service() external view returns (address);

    function client() external view returns (address);

    function clientBasisPoints() external view returns (uint256);

    function referrer() external view returns (address);

    function referrerBasisPoints() external view returns (uint256);

    function eth2WithdrawalCredentialsAddress() external view returns (address);
}
