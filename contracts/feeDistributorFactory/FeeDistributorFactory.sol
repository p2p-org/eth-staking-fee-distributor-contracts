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

/// @notice Should be a FeeDistributor contract
/// @param _passedAddress passed address that does not support IFeeDistributor interface
error FeeDistributorFactory__NotFeeDistributor(address _passedAddress);

/// @notice Should be a P2pEth2Depositor contract
/// @param _passedAddress passed address that does not support IP2pEth2Depositor interface
error FeeDistributorFactory__NotP2pEth2Depositor(address _passedAddress);

/// @notice Reference FeeDistributor should be set before calling `createFeeDistributor`
error FeeDistributorFactory__ReferenceFeeDistributorNotSet();

/// @notice caller should be owner, operator, or P2pEth2Depositor contract
/// @param _caller calling address
error FeeDistributorFactory__CallerNotAuthorized(address _caller);

/// @title Factory for cloning (EIP-1167) FeeDistributor instances pre client
contract FeeDistributorFactory is OwnableAssetRecoverer, OwnableWithOperator, ERC165, IFeeDistributorFactory {

    /// @notice Default Client Basis Points
    /// @dev Used when no client config provided.
    /// Default Referrer Basis Points is zero.
    uint96 private s_defaultClientBasisPoints;

    /// @notice The address of P2pEth2Depositor
    address private s_p2pEth2Depositor;

    /// @notice client address -> array of client FeeDistributors mapping
    mapping(address => address[]) private s_allClientFeeDistributors;

    /// @notice array of all FeeDistributors for all clients
    address[] private s_allFeeDistributors;

    /// @dev Set values known at the initial deploy time.
    /// @param _defaultClientBasisPoints Default Client Basis Points
    constructor(uint96 _defaultClientBasisPoints) {
        s_defaultClientBasisPoints = _defaultClientBasisPoints;

        emit FeeDistributorFactory__DefaultClientBasisPointsSet(_defaultClientBasisPoints);
    }

    /// @notice Set a new version of P2pEth2Depositor contract
    /// @param _p2pEth2Depositor the address of the new P2pEth2Depositor contract
    function setP2pEth2Depositor(address _p2pEth2Depositor) external onlyOwner {
        if (!ERC165Checker.supportsInterface(_p2pEth2Depositor, type(IP2pOrgUnlimitedEthDepositor).interfaceId)) {
            revert FeeDistributorFactory__NotP2pEth2Depositor(_p2pEth2Depositor);
        }

        s_p2pEth2Depositor = _p2pEth2Depositor;
        emit FeeDistributorFactory__P2pEth2DepositorSet(_p2pEth2Depositor);
    }

    /// @notice Set a new Default Client Basis Points
    /// @param _defaultClientBasisPoints Default Client Basis Points
    function setDefaultClientBasisPoints(uint96 _defaultClientBasisPoints) external onlyOwner {
        s_defaultClientBasisPoints = _defaultClientBasisPoints;

        emit FeeDistributorFactory__DefaultClientBasisPointsSet(_defaultClientBasisPoints);
    }

    /// @inheritdoc IFeeDistributorFactory
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
        emit FeeDistributorFactory__FeeDistributorCreated(
            newFeeDistributorAddress,
            _clientConfig.recipient,
            _referenceFeeDistributor,
            _clientConfig.basisPoints
        );

        return newFeeDistributorAddress;
    }

    /// @inheritdoc IFeeDistributorFactory
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

    /// @inheritdoc IFeeDistributorFactory
    function allClientFeeDistributors(address _client) external view returns (address[] memory) {
        return s_allClientFeeDistributors[_client];
    }

    /// @inheritdoc IFeeDistributorFactory
    function allFeeDistributors() external view returns (address[] memory) {
        return s_allFeeDistributors;
    }

    /// @inheritdoc IFeeDistributorFactory
    function p2pEth2Depositor() external view returns (address) {
        return s_p2pEth2Depositor;
    }

    /// @inheritdoc IFeeDistributorFactory
    function defaultClientBasisPoints() external view returns (uint96) {
        return s_defaultClientBasisPoints;
    }

    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IFeeDistributorFactory).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IOwnable
    function owner() public view override(Ownable, OwnableBase, IOwnable) returns (address) {
        return super.owner();
    }

    /// @inheritdoc IFeeDistributorFactory
    function operator() public view override(OwnableWithOperator, IFeeDistributorFactory) returns (address) {
        return super.operator();
    }

    /// @inheritdoc IFeeDistributorFactory
    function checkOperatorOrOwner(address _address) public view override(OwnableWithOperator, IFeeDistributorFactory) {
        return super.checkOperatorOrOwner(_address);
    }

    /// @inheritdoc IFeeDistributorFactory
    function checkP2pEth2Depositor(address _address) external view {
        if (s_p2pEth2Depositor != _address) {
            revert FeeDistributorFactory__NotP2pEth2Depositor(_address);
        }
    }

    /// @inheritdoc IFeeDistributorFactory
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

    /// @notice Calculates the salt required for deterministic clone creation
    /// depending on clientConfig and referrerConfig
    /// @param _clientConfig address and basis points (percent * 100) of the client
    /// @param _referrerConfig address and basis points (percent * 100) of the referrer.
    /// @return bytes32 salt
    function _getSalt(
        FeeRecipient memory _clientConfig,
        FeeRecipient calldata _referrerConfig
    ) private pure returns (bytes32)
    {
        return keccak256(abi.encode(_clientConfig, _referrerConfig));
    }
}
