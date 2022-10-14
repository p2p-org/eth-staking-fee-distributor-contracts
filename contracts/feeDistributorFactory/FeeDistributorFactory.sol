// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "../assetRecovering/PublicAssetRecoverer.sol";
import "./IFeeDistributorFactory.sol";
import "../feeDistributor/IFeeDistributor.sol";

/**
* @notice Should be a FeeDistributor contract
* @param _passedAddress passed address that does not support IFeeDistributor interface
*/
error FeeDistributorFactory__NotFeeDistributor(address _passedAddress);

/**
* @notice Reference FeeDistributor should be set before calling `createFeeDistributor`
*/
error FeeDistributorFactory__ReferenceFeeDistributorNotSet();

/**
* @title Factory for cloning (EIP-1167) FeeDistributor instances pre client
*/
contract FeeDistributorFactory is PublicAssetRecoverer, IFeeDistributorFactory {
    // Type Declarations

    using Clones for address;

    // Constants

    bytes32 public constant REFERENCE_INSTANCE_SETTER_ROLE = keccak256("REFERENCE_INSTANCE_SETTER_ROLE");
    bytes32 public constant INSTANCE_CREATOR_ROLE = keccak256("INSTANCE_CREATOR_ROLE");

    // State variables

    /**
    * @notice The address of the reference implementation of FeeDistributor
    * @dev used as the basis for clones
    */
    address private s_referenceFeeDistributor;

    constructor() {
        // Grant the contract deployer the default admin role: it will be able
        // to grant and revoke any roles
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // Functions

    /**
    * @notice Set a new reference implementation of FeeDistributor contract
    * @param _referenceFeeDistributor the address of the new reference implementation contract
    */
    function setReferenceInstance(address _referenceFeeDistributor) external onlyRole(REFERENCE_INSTANCE_SETTER_ROLE) {
        if (!ERC165Checker.supportsInterface(_referenceFeeDistributor, type(IFeeDistributor).interfaceId)) {
            revert FeeDistributorFactory__NotFeeDistributor(_referenceFeeDistributor);
        }

        s_referenceFeeDistributor = _referenceFeeDistributor;
        emit ReferenceInstanceSet(_referenceFeeDistributor);
    }

    /**
    * @notice Creates a FeeDistributor instance for a client
    * @dev Emits `FeeDistributorCreated` event with the address of the newly created instance
    * @param _client the address of the client
    */
    function createFeeDistributor(address _client) external onlyRole(INSTANCE_CREATOR_ROLE) {
        if (s_referenceFeeDistributor == address(0)) {
            revert FeeDistributorFactory__ReferenceFeeDistributorNotSet();
        }

        // clone the reference implementation of FeeDistributor
        address newFeeDistributorAddrress = s_referenceFeeDistributor.clone();

        // cast address to FeeDistributor
        IFeeDistributor newFeeDistributor = IFeeDistributor(newFeeDistributorAddrress);

        // set the client address to the cloned FeeDistributor instance
        newFeeDistributor.initialize(_client);

        // emit event with the address of the newly created instance for the external listener
        emit FeeDistributorCreated(newFeeDistributorAddrress, _client);
    }

    /**
     * @dev Returns the reference FeeDistributor contract address
     */
    function getReferenceFeeDistributor() external view returns (address) {
        return s_referenceFeeDistributor;
    }

    // from AccessControl

    /**
    * @dev See {IERC165-supportsInterface}.
    */
    function supportsInterface(bytes4 interfaceId) public view virtual override (AccessControlEnumerable, IERC165) returns (bool) {
        return interfaceId == type(IFeeDistributorFactory).interfaceId || super.supportsInterface(interfaceId);
    }
}
