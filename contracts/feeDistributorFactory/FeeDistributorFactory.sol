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

    mapping(address => address[]) private s_allClientFeeDistributors;

    address[] private s_allFeeDistributors;

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
        FeeRecipient calldata _referrerConfig
    ) external returns (address newFeeDistributorAddress) {
        check_Operator_Owner_P2pEth2Depositor(msg.sender);

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
        newFeeDistributor.initialize(_clientConfig, _referrerConfig);

        // append new FeeDistributor address to all client feeDistributors array
        s_allClientFeeDistributors[_clientConfig.recipient].push(newFeeDistributorAddress);

        // append new FeeDistributor address to all feeDistributors array
        s_allFeeDistributors.push(newFeeDistributorAddress);

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

    function allClientFeeDistributors(address _client) external view returns (address[] memory) {
        return s_allClientFeeDistributors[_client];
    }

    function allFeeDistributors() external view returns (address[] memory) {
        return s_allFeeDistributors;
    }

    function p2pEth2Depositor() external view returns (address) {
        return s_p2pEth2Depositor;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IFeeDistributorFactory).interfaceId || super.supportsInterface(interfaceId);
    }

    function owner() public view override(Ownable, OwnableBase, IOwnable) returns (address) {
        return super.owner();
    }

    function operator() public view override(OwnableWithOperator, IFeeDistributorFactory) returns (address) {
        return super.operator();
    }

    function checkOperatorOrOwner(address _address) public view override(OwnableWithOperator, IFeeDistributorFactory) {
        return super.checkOperatorOrOwner(_address);
    }

    function checkP2pEth2Depositor(address _address) external view {
        if (s_p2pEth2Depositor != _address) {
            revert FeeDistributorFactory__NotP2pEth2Depositor(_address);
        }
    }

    function check_Operator_Owner_P2pEth2Depositor(address _address) public view {
        address currentOwner = owner();
        address currentOperator = operator();

        if (currentOperator != _address
            && currentOwner != _address
            && s_p2pEth2Depositor != _address
        ) {
            revert FeeDistributorFactory__CallerNotAuthorized(_address);
        }
    }

    function _getSalt(
        FeeRecipient memory _clientConfig,
        FeeRecipient calldata _referrerConfig
    ) private pure returns (bytes32)
    {
        return keccak256(abi.encode(_clientConfig, _referrerConfig));
    }
}
