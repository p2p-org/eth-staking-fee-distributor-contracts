// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "./FeeDistributor.sol";
import "./AssetRecoverer.sol";
import "./IFeeDistributorFactory.sol";

/**
* @notice if the only 1 address with DEFAULT_ADMIN_ROLE is left,
* it should not be possible to renounce it
* to prevent losing control over the contract.
*/
error FeeDistributorFactory__CannotRevokeTheOnlyAdmin();

/**
* @notice Reference FeeDistributor should be set before calling `createFeeDistributor`
*/
error FeeDistributorFactory__ReferenceFeeDistributorNotSet();

/**
* @title Factory for cloning (EIP-1167) FeeDistributor instances pre client
*/
contract FeeDistributorFactory is AccessControlEnumerable, AssetRecoverer, IFeeDistributorFactory {
    // Type Declarations

    using Clones for address;

    // Constants

    bytes32 public constant REFERENCE_INSTANCE_SETTER_ROLE = keccak256("REFERENCE_INSTANCE_SETTER_ROLE");
    bytes32 public constant INSTANCE_CREATOR_ROLE = keccak256("INSTANCE_CREATOR_ROLE");
    bytes32 public constant ASSET_RECOVERER_ROLE = keccak256("ASSET_RECOVERER_ROLE");

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
        FeeDistributor newFeeDistributor = FeeDistributor(newFeeDistributorAddrress);

        // set the client address to the cloned FeeDistributor instance
        newFeeDistributor.initialize(_client);

        // emit event with the address of the newly created instance for the external listener
        emit FeeDistributorCreated(newFeeDistributorAddrress, _client);
    }

    // from AssetRecoverer

    /**
     * @notice transfers ether from this contract
     * @dev using `address.call` is safer to transfer to other contracts
     * @param _recipient address to transfer ether to
     * @param _amount amount of ether to transfer
     */
    function transferEther(address _recipient, uint256 _amount) public override onlyRole(ASSET_RECOVERER_ROLE) {
        _transferEther(_recipient, _amount);
    }

    /**
     * @notice transfer an ERC20 token from this contract
     * @dev `SafeERC20.safeTransfer` doesn't always return a bool
     * as it performs an internal `require` check
     * @param _token address of the ERC20 token
     * @param _recipient address to transfer the tokens to
     * @param _amount amount of tokens to transfer
     */
    function transferERC20(
        address _token,
        address _recipient,
        uint256 _amount
    ) public override onlyRole(ASSET_RECOVERER_ROLE) {
        _transferERC20(_token, _recipient, _amount);
    }

    /**
     * @notice transfer an ERC721 token from this contract
     * @dev `IERC721.safeTransferFrom` doesn't always return a bool
     * as it performs an internal `require` check
     * @param _token address of the ERC721 token
     * @param _recipient address to transfer the token to
     * @param _tokenId id of the individual token
     * @param _data data to transfer along
     */
    function transferERC721(
        address _token,
        address _recipient,
        uint256 _tokenId,
        bytes calldata _data
    ) public override onlyRole(ASSET_RECOVERER_ROLE) {
        _transferERC721(_token, _recipient, _tokenId, _data);
    }

    /**
     * @notice transfer an ERC1155 token from this contract
     * @dev see `AssetRecoverer`
     * @param _token address of the ERC1155 token that is being recovered
     * @param _recipient address to transfer the token to
     * @param _tokenId id of the individual token to transfer
     * @param _amount amount of tokens to transfer
     * @param _data data to transfer along
     */
    function transferERC1155(
        address _token,
        address _recipient,
        uint256 _tokenId,
        uint256 _amount,
        bytes calldata _data
    ) public override onlyRole(ASSET_RECOVERER_ROLE) {
        _transferERC1155(_token, _recipient, _tokenId, _amount, _data);
    }

    // from AccessControl

    /**
    * @dev See {IERC165-supportsInterface}.
    */
    function supportsInterface(bytes4 interfaceId) public view virtual override (AccessControlEnumerable, IERC165) returns (bool) {
        return interfaceId == type(IFeeDistributorFactory).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Revokes `role` from `account`.
     * May emit a {RoleRevoked} event.
     * Overrides AccessControl _revokeRole
     * to prevent renouncing the only admin
     * and losing control over the contract.
     */
    function _revokeRole(bytes32 role, address account) internal override {
        if (role == DEFAULT_ADMIN_ROLE && getRoleMemberCount(DEFAULT_ADMIN_ROLE) == 1) {
            revert FeeDistributorFactory__CannotRevokeTheOnlyAdmin();
        }

        super._revokeRole(role, account);
    }
}
