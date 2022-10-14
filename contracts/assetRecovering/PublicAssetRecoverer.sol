// SPDX-FileCopyrightText: 2022 Lido <info@lido.fi>
// SPDX-License-Identifier: MIT

// https://github.com/lidofinance/lido-otc-seller/blob/master/contracts/lib/AssetRecoverer.sol
pragma solidity 0.8.17;

import "./PublicTokenRecoverer.sol";
import "./AssetRecoverer.sol";

/// @title Public Asset Recoverer with public functions callable by ASSET_RECOVERER_ROLE
/// @notice Recover ether, ERC20, ERC721 and ERC1155 from a derived contract
abstract contract PublicAssetRecoverer is PublicTokenRecoverer, AssetRecoverer {

    // Functions

    // from AssetRecoverer

    /**
     * @notice transfers ether from this contract
     * @dev using `address.call` is safer to transfer to other contracts
     * @param _recipient address to transfer ether to
     * @param _amount amount of ether to transfer
     */
    function transferEther(address _recipient, uint256 _amount) public onlyRole(ASSET_RECOVERER_ROLE) {
        _transferEther(_recipient, _amount);
    }
}
