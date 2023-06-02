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
import "../p2pEth2Depositor/IP2pOrgUnlimitedEthDepositor.sol";
import "../structs/P2pStructs.sol";

error FeeDistributorFactory__NotFeeDistributor(address _passedAddress);
error FeeDistributorFactory__NotP2pEth2Depositor(address _passedAddress);
error FeeDistributorFactory__ReferenceFeeDistributorNotSet();
error FeeDistributorFactory__CallerNotAuthorized(address _caller);

contract FeeDistributorFactory is OwnableAssetRecoverer, OwnableWithOperator, ERC165, IFeeDistributorFactory {

    uint96 s_defaultClientBasisPoints;
    address private s_p2pEth2Depositor;

    constructor(uint96 _defaultClientBasisPoints) {
        s_defaultClientBasisPoints = _defaultClientBasisPoints;
    }

    function setP2pEth2Depositor(address _p2pEth2Depositor) external onlyOwner {
        if (!ERC165Checker.supportsInterface(_p2pEth2Depositor, type(IP2pOrgUnlimitedEthDepositor).interfaceId)) {
            revert FeeDistributorFactory__NotP2pEth2Depositor(_p2pEth2Depositor);
        }

        s_p2pEth2Depositor = _p2pEth2Depositor;
        emit P2pEth2DepositorSet(_p2pEth2Depositor);
    }

    function setDefaultClientBasisPoints(uint96 _defaultClientBasisPoints) external onlyOwner {
        s_defaultClientBasisPoints = _defaultClientBasisPoints;
    }

    function createFeeDistributor(
        address _referenceFeeDistributor,
        FeeRecipient memory _clientConfig,
        FeeRecipient calldata _referrerConfig,
        bytes calldata _additionalData
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

        if (_referenceFeeDistributor == address(0)) {
            revert FeeDistributorFactory__ReferenceFeeDistributorNotSet();
        }

        if (!ERC165Checker.supportsInterface(_referenceFeeDistributor, type(IFeeDistributor).interfaceId)) {
            revert FeeDistributorFactory__NotFeeDistributor(_referenceFeeDistributor);
        }

        if (_clientConfig.basisPoints == 0) {
            _clientConfig.basisPoints = s_defaultClientBasisPoints;
        }

        // clone the reference implementation of FeeDistributor
        newFeeDistributorAddress = Clones.cloneDeterministic(
            _referenceFeeDistributor,
            _getSalt(_clientConfig, _referrerConfig)
        );

        // cast address to FeeDistributor
        IFeeDistributor newFeeDistributor = IFeeDistributor(newFeeDistributorAddress);

        // set the client address to the cloned FeeDistributor instance
        newFeeDistributor.initialize(_clientConfig, _referrerConfig, _additionalData);

        // emit event with the address of the newly created instance for the external listener
        emit FeeDistributorCreated(
            newFeeDistributorAddress,
            _clientConfig.recipient,
            _referenceFeeDistributor,
            _clientConfig.basisPoints
        );

        return newFeeDistributorAddress;
    }

    function predictFeeDistributorAddress(
        address _referenceFeeDistributor,
        FeeRecipient calldata _clientConfig,
        FeeRecipient calldata _referrerConfig
    ) public view returns (address) {
        return Clones.predictDeterministicAddress(
            _referenceFeeDistributor,
            _getSalt(_clientConfig, _referrerConfig)
        );
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IFeeDistributorFactory).interfaceId || super.supportsInterface(interfaceId);
    }

    function owner() public view override(Ownable, OwnableBase, IOwnable) returns (address) {
        return super.owner();
    }

    function _getSalt(
        FeeRecipient calldata _clientConfig,
        FeeRecipient calldata _referrerConfig
    ) private view returns (bytes32)
    {
        return keccak256(abi.encode(_clientConfig, _referrerConfig));
    }
}
