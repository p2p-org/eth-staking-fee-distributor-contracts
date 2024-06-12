// SPDX-FileCopyrightText: 2024 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "../@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "../feeDistributor/IFeeDistributor.sol";
import "../structs/P2pStructs.sol";

/**
* @title This is a mock for testing only.
* @dev DO NOT deploy in production!
*/
contract MockClientFeeDistributor is ERC165, IFeeDistributor {

    function initialize(
        FeeRecipient calldata _clientConfig,
        FeeRecipient calldata _referrerConfig
    ) external {

    }

    function increaseDepositedCount(uint32 _validatorCountToAdd) external {

    }

    function voluntaryExit(bytes[] calldata _pubkeys) external {

    }

    function factory() external pure returns (address) {
        return address(0);
    }

    function service() external pure returns (address) {
        return address(0);
    }

    function client() external pure returns (address) {
        return address(0);
    }

    function clientBasisPoints() external pure returns (uint256) {
        return 0;
    }

    function referrer() external pure returns (address) {
        return address(0);
    }

    function referrerBasisPoints() external pure returns (uint256) {
        return 0;
    }

    function eth2WithdrawalCredentialsAddress() external pure returns (address) {
        return address(0);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IFeeDistributor).interfaceId || super.supportsInterface(interfaceId);
    }
}
