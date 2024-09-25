// SPDX-FileCopyrightText: 2024 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "../@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "../feeDistributorFactory/IFeeDistributorFactory.sol";
import "../assetRecovering/OwnableTokenRecoverer.sol";
import "./IFeeDistributor.sol";
import "../structs/P2pStructs.sol";
import "./BaseFeeDistributor.sol";

/// @title FeeDistributor
contract DeoracleizedFeeDistributor is BaseFeeDistributor {
    /// @dev Set values that are constant, common for all the clients, known at the initial deploy time.
    /// @param _factory address of FeeDistributorFactory
    /// @param _service address of the service (P2P) fee recipient
    constructor(
        address _factory,
        address payable _service
    ) BaseFeeDistributor(_factory, _service) {}

    /// @notice Withdraw
    function withdraw(
        uint256 _clientAmount,
        uint256 _serviceAmount,
        uint256 _referrerAmount
    ) external nonReentrant {
        i_factory.checkOperatorOrOwner(msg.sender);

        if (s_clientConfig.recipient == address(0)) {
            revert FeeDistributor__ClientNotSet();
        }

        if (address(this).balance == 0) {
            // revert if there is no ether to withdraw
            revert FeeDistributor__NothingToWithdraw();
        }

        if (
            _clientAmount + _serviceAmount + _referrerAmount >
            address(this).balance
        ) {
            revert FeeDistributor__AmountsExceedBalance();
        }

        if (_clientAmount + _serviceAmount + _referrerAmount == 0) {
            revert FeeDistributor__AmountsAreZero();
        }

        if (_referrerAmount > 0) {
            if (s_referrerConfig.recipient != address(0)) {
                // if there is a referrer

                // Send ETH to referrer. Ignore the possible yet unlikely revert in the receive function.
                P2pAddressLib._sendValue(
                    s_referrerConfig.recipient,
                    _referrerAmount
                );
            } else {
                revert FeeDistributor__ReferrerNotSet();
            }
        }

        if (_serviceAmount > 0) {
            // Send ETH to service. Ignore the possible yet unlikely revert in the receive function.
            P2pAddressLib._sendValue(i_service, _serviceAmount);
        }

        if (_clientAmount > 0) {
            // Send ETH to client. Ignore the possible yet unlikely revert in the receive function.
            P2pAddressLib._sendValue(s_clientConfig.recipient, _clientAmount);
        }

        emit FeeDistributor__Withdrawn(
            _serviceAmount,
            _clientAmount,
            _referrerAmount
        );
    }
}
