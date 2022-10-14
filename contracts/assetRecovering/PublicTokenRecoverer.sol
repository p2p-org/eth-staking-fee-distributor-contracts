// SPDX-FileCopyrightText: 2022 Lido <info@lido.fi>
// SPDX-License-Identifier: MIT

// https://github.com/lidofinance/lido-otc-seller/blob/master/contracts/lib/AssetRecoverer.sol
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "./TokenRecoverer.sol";

/**
* @notice if the only 1 address with DEFAULT_ADMIN_ROLE is left,
* it should not be possible to renounce it
* to prevent losing control over the contract.
*/
error PublicTokenRecoverer__CannotRevokeTheOnlyAdmin();

/// @title Token Recoverer with public functions callable by ASSET_RECOVERER_ROLE
/// @notice Recover ERC20, ERC721 and ERC1155 from a derived contract
abstract contract PublicTokenRecoverer is TokenRecoverer, AccessControlEnumerable {
    // Constants

    bytes32 public constant ASSET_RECOVERER_ROLE = keccak256("ASSET_RECOVERER_ROLE");

    // Functions

    // from AssetRecoverer

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
    ) public onlyRole(ASSET_RECOVERER_ROLE) {
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
    ) public onlyRole(ASSET_RECOVERER_ROLE) {
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
    ) public onlyRole(ASSET_RECOVERER_ROLE) {
        _transferERC1155(_token, _recipient, _tokenId, _amount, _data);
    }

    // from AccessControl

    /**
     * @dev Revokes `role` from `account`.
     * May emit a {RoleRevoked} event.
     * Overrides AccessControl _revokeRole
     * to prevent renouncing the only admin
     * and losing control over the contract.
     */
    function _revokeRole(bytes32 role, address account) internal override {
        if (role == DEFAULT_ADMIN_ROLE && getRoleMemberCount(DEFAULT_ADMIN_ROLE) == 1) {
            revert PublicTokenRecoverer__CannotRevokeTheOnlyAdmin();
        }

        super._revokeRole(role, account);
    }
}
