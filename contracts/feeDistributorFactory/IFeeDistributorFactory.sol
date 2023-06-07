// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "../access/IOwnable.sol";
import "../feeDistributor/IFeeDistributor.sol";
import "../structs/P2pStructs.sol";

interface IFeeDistributorFactory is IOwnable, IERC165 {
    event FeeDistributorCreated(
        address indexed _newFeeDistributorAddress,
        address indexed _clientAddress,
        address indexed _referenceFeeDistributor,
        uint96 _clientBasisPoints
    );

    event P2pEth2DepositorSet(address indexed _p2pEth2Depositor);

    function createFeeDistributor(
        address _referenceFeeDistributor,
        FeeRecipient calldata _clientConfig,
        FeeRecipient calldata _referrerConfig,
        bytes calldata _additionalData
    ) external returns (address newFeeDistributorAddress);

    function predictFeeDistributorAddress(
        address _referenceFeeDistributor,
        FeeRecipient calldata _clientConfig,
        FeeRecipient calldata _referrerConfig
    ) external view returns (address);

    function allClientFeeDistributors(
        address _client
    ) external view returns (address[] memory);

    function allFeeDistributors() external view returns (address[] memory);

    function p2pEth2Depositor() external view returns (address);

    function operator() external view returns (address);

    function checkOperatorOrOwner(address _address) external view;

    function checkP2pEth2Depositor(address _address) external view;
}
