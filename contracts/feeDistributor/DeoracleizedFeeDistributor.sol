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
    function withdraw(Withdrawal calldata _withdrawal) external nonReentrant {
        i_factory.checkOperatorOrOwner(msg.sender);

        if (s_clientConfig.recipient == address(0)) {
            revert FeeDistributor__ClientNotSet();
        }

        uint256 clientAmount = uint256(_withdrawal.clientAmount);
        uint256 serviceAmount = uint256(_withdrawal.serviceAmount);
        uint256 referrerAmount = uint256(_withdrawal.referrerAmount);

        if (
            clientAmount + serviceAmount + referrerAmount >
            address(this).balance
        ) {
            revert FeeDistributor__AmountsExceedBalance();
        }

        if (clientAmount + serviceAmount + referrerAmount == 0) {
            revert FeeDistributor__AmountsAreZero();
        }

        if (referrerAmount > 0) {
            if (s_referrerConfig.recipient != address(0)) {
                // if there is a referrer

                // Send ETH to referrer. Ignore the possible yet unlikely revert in the receive function.
                P2pAddressLib._sendValue(
                    s_referrerConfig.recipient,
                    referrerAmount
                );
            } else {
                revert FeeDistributor__ReferrerNotSet();
            }
        }

        if (serviceAmount > 0) {
            // Send ETH to service. Ignore the possible yet unlikely revert in the receive function.
            P2pAddressLib._sendValue(i_service, serviceAmount);
        }

        if (clientAmount > 0) {
            // Send ETH to client. Ignore the possible yet unlikely revert in the receive function.
            P2pAddressLib._sendValue(s_clientConfig.recipient, clientAmount);
        }

        emit FeeDistributor__Withdrawn(
            serviceAmount,
            clientAmount,
            referrerAmount
        );
    }

    /// @inheritdoc Erc4337Account
    function withdrawSelector() public pure override returns (bytes4) {
        return DeoracleizedFeeDistributor.withdraw.selector;
    }
}
