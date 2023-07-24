// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "../feeDistributorFactory/IFeeDistributorFactory.sol";
import "../assetRecovering/OwnableTokenRecoverer.sol";
import "./IFeeDistributor.sol";
import "../structs/P2pStructs.sol";
import "./BaseFeeDistributor.sol";

/// @title FeeDistributor accepting and splitting EL rewards only.
contract ElOnlyFeeDistributor is BaseFeeDistributor {

    /// @dev Set values that are constant, common for all the clients, known at the initial deploy time.
    /// @param _factory address of FeeDistributorFactory
    /// @param _service address of the service (P2P) fee recipient
    constructor(
        address _factory,
        address payable _service
    ) BaseFeeDistributor(_factory, _service) {
    }

    /// @notice Withdraw the whole balance of the contract according to the pre-defined basis points.
    /// @dev In case someone (either service, or client, or referrer) fails to accept ether,
    /// the owner will be able to recover some of their share.
    /// This scenario is very unlikely. It can only happen if that someone is a contract
    /// whose receive function changed its behavior since FeeDistributor's initialization.
    /// It can never happen unless the receiving party themselves wants it to happen.
    /// We strongly recommend against intentional reverts in the receive function
    /// because the remaining parties might call `withdraw` again multiple times without waiting
    /// for the owner to recover ether for the reverting party.
    /// In fact, as a punishment for the reverting party, before the recovering,
    /// 1 more regular `withdraw` will happen, rewarding the non-reverting parties again.
    /// `recoverEther` function is just an emergency backup plan and does not replace `withdraw`.
    function withdraw() external nonReentrant {
        if (s_clientConfig.recipient == address(0)) {
            revert FeeDistributor__ClientNotSet();
        }

        // get the contract's balance
        uint256 balance = address(this).balance;

        if (balance == 0) {
            // revert if there is no ether to withdraw
            revert FeeDistributor__NothingToWithdraw();
        }

        // how much should client get
        uint256 clientAmount = (balance * s_clientConfig.basisPoints) / 10000;

        // how much should service get
        uint256 serviceAmount = balance - clientAmount;

        // how much should referrer get
        uint256 referrerAmount;

        if (s_referrerConfig.recipient != address(0)) {
            // if there is a referrer

            referrerAmount = (balance * s_referrerConfig.basisPoints) / 10000;
            serviceAmount -= referrerAmount;

            // Send ETH to referrer. Ignore the possible yet unlikely revert in the receive function.
            P2pAddressLib._sendValue(s_referrerConfig.recipient, referrerAmount);
        }

        // Send ETH to service. Ignore the possible yet unlikely revert in the receive function.
        P2pAddressLib._sendValue(i_service, serviceAmount);

        // Send ETH to client. Ignore the possible yet unlikely revert in the receive function.
        P2pAddressLib._sendValue(s_clientConfig.recipient, clientAmount);

        emit FeeDistributor__Withdrawn(serviceAmount, clientAmount, referrerAmount);
    }

    /// @notice Recover ether in a rare case when either service, or client, or referrer
    /// refuse to accept ether.
    /// @param _to receiver address
    function recoverEther(address payable _to) external onlyOwner {
        this.withdraw();

        // get the contract's balance
        uint256 balance = address(this).balance;

        if (balance > 0) { // only happens if at least 1 party reverted in their receive
            bool success = P2pAddressLib._sendValue(_to, balance);

            if (success) {
                emit FeeDistributor__EtherRecovered(_to, balance);
            } else {
                revert FeeDistributor__EtherRecoveryFailed(_to, balance);
            }
        }
    }

    /// @inheritdoc IFeeDistributor
    /// @dev client address
    function eth2WithdrawalCredentialsAddress() external override view returns (address) {
        return s_clientConfig.recipient;
    }
}
