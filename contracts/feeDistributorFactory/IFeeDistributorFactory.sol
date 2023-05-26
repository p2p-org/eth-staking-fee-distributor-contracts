// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "../access/IOwnable.sol";
import "../feeDistributor/IFeeDistributor.sol";

interface IFeeDistributorFactory is IOwnable, IERC165 {
    event FeeDistributorCreated(address indexed _newFeeDistributorAddress, address indexed _clientAddress);
    event ReferenceInstanceSet(address indexed _referenceFeeDistributor);
    event P2pEth2DepositorSet(address indexed _p2pEth2Depositor);

    function setReferenceInstance(address _referenceFeeDistributor) external;

    function createFeeDistributor(
        IFeeDistributor.FeeRecipient calldata _clientConfig,
        IFeeDistributor.FeeRecipient calldata _referrerConfig,
        IFeeDistributor.ValidatorData calldata _validatorData
    ) external returns (address newFeeDistributorAddress);

    function getReferenceFeeDistributor() external view returns (address);
}
