// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../@openzeppelin/contracts/proxy/Clones.sol";
import "../@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "../assetRecovering/OwnableAssetRecoverer.sol";
import "./IFeeDistributorFactory.sol";
import "../feeDistributor/IFeeDistributor.sol";
import "../access/Ownable.sol";
import "../access/OwnableWithOperator.sol";
import "../p2pEth2Depositor/IP2pEth2Depositor.sol";

error FeeDistributorFactory__NotFeeDistributor(address _passedAddress);
error FeeDistributorFactory__NotP2pEth2Depositor(address _passedAddress);
error FeeDistributorFactory__ReferenceFeeDistributorNotSet();
error FeeDistributorFactory__CallerNotAuthorized(address _caller);

contract FeeDistributorFactory is OwnableAssetRecoverer, OwnableWithOperator, ERC165, IFeeDistributorFactory {
    using Clones for address;

    address private s_referenceFeeDistributor;
    uint96 s_defaultClientBasisPoints;
    address private s_p2pEth2Depositor;

    constructor(uint96 _defaultClientBasisPoints) {
        s_defaultClientBasisPoints = _defaultClientBasisPoints;
    }

    function setReferenceInstance(address _referenceFeeDistributor) external onlyOwner {
        if (!ERC165Checker.supportsInterface(_referenceFeeDistributor, type(IFeeDistributor).interfaceId)) {
            revert FeeDistributorFactory__NotFeeDistributor(_referenceFeeDistributor);
        }

        s_referenceFeeDistributor = _referenceFeeDistributor;
        emit ReferenceInstanceSet(_referenceFeeDistributor);
    }

    function setP2pEth2Depositor(address _p2pEth2Depositor) external onlyOwner {
        if (!ERC165Checker.supportsInterface(_p2pEth2Depositor, type(IP2pEth2Depositor).interfaceId)) {
            revert FeeDistributorFactory__NotP2pEth2Depositor(_p2pEth2Depositor);
        }

        s_p2pEth2Depositor = _p2pEth2Depositor;
        emit P2pEth2DepositorSet(_p2pEth2Depositor);
    }

    function setDefaultClientBasisPoints(uint96 _defaultClientBasisPoints) external onlyOwner {
        s_defaultClientBasisPoints = _defaultClientBasisPoints;
    }

    function createFeeDistributor(
        IFeeDistributor.FeeRecipient memory _clientConfig,
        IFeeDistributor.FeeRecipient calldata _referrerConfig,
        IFeeDistributor.ValidatorData calldata _validatorData
    ) external returns (address newFeeDistributorAddress) {
        address currentOwner = owner();
        address currentOperator = operator();
        address p2pEth2Depositor = s_p2pEth2Depositor;

        if (currentOperator != _msgSender()
            && currentOwner != _msgSender()
            && p2pEth2Depositor != _msgSender()
        ) {
            revert FeeDistributorFactory__CallerNotAuthorized(_msgSender());
        }

        if (s_referenceFeeDistributor == address(0)) {
            revert FeeDistributorFactory__ReferenceFeeDistributorNotSet();
        }

        if (_clientConfig.basisPoints == 0) {
            _clientConfig.basisPoints = s_defaultClientBasisPoints;
        }

        // clone the reference implementation of FeeDistributor
        newFeeDistributorAddress = s_referenceFeeDistributor.clone();

        // cast address to FeeDistributor
        IFeeDistributor newFeeDistributor = IFeeDistributor(newFeeDistributorAddress);

        // set the client address to the cloned FeeDistributor instance
        newFeeDistributor.initialize(_clientConfig, _referrerConfig, _validatorData);

        // emit event with the address of the newly created instance for the external listener
        emit FeeDistributorCreated(newFeeDistributorAddress, _clientConfig.recipient);

        return newFeeDistributorAddress;
    }

    function getReferenceFeeDistributor() external view returns (address) {
        return s_referenceFeeDistributor;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IFeeDistributorFactory).interfaceId || super.supportsInterface(interfaceId);
    }

    function owner() public view override(Ownable, OwnableBase, IOwnable) returns (address) {
        return super.owner();
    }
}
