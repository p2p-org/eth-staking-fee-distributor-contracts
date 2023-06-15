// SPDX-FileCopyrightText: 2022 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../structs/P2pStructs.sol";
import "../constants/P2pConstants.sol";
import "./BaseFeeDistributor.sol";

error ContractWcFeeDistributor__NoPubkeysPassed();
error ContractWcFeeDistributor__TooManyPubkeysPassed();

contract ContractWcFeeDistributor is BaseFeeDistributor {

    event DepositedCountIncreased(
        uint32 added,
        uint32 newDepositedCount
    );

    event ExitedCountIncreased(
        uint32 added,
        uint32 newExitedCount
    );

    event CollateralReturnedCountIncreased(
        uint32 added,
        uint32 newCollateralReturnedCount
    );

    ValidatorData private s_validatorData;

    constructor(
        address _factory,
        address payable _service
    ) BaseFeeDistributor(_factory, _service) {
    }

    function increaseDepositedCount(uint32 _validatorCountToAdd) external override {
        i_factory.check_Operator_Owner_P2pEth2Depositor(msg.sender);

        s_validatorData.depositedCount += _validatorCountToAdd;

        emit DepositedCountIncreased(_validatorCountToAdd, s_validatorData.depositedCount);
    }

    function voluntaryExit(bytes[] calldata _pubkeys) public override { // onlyClient due to BaseFeeDistributor
        if (_pubkeys.length == 0) {
            revert ContractWcFeeDistributor__NoPubkeysPassed();
        }
        if (_pubkeys.length > s_validatorData.depositedCount - s_validatorData.exitedCount) {
            revert ContractWcFeeDistributor__TooManyPubkeysPassed();
        }

        s_validatorData.exitedCount += uint32(_pubkeys.length);

        emit ExitedCountIncreased(uint32(_pubkeys.length), s_validatorData.exitedCount);

        super.voluntaryExit(_pubkeys);
    }

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

        if (balance >= COLLATERAL && s_validatorData.collateralReturnedCount < s_validatorData.exitedCount) {
            // if exited and some validators withdrawn

            // integer division
            uint32 collateralsCountToReturn = uint32(balance / COLLATERAL);

            s_validatorData.collateralReturnedCount += collateralsCountToReturn;

            emit CollateralReturnedCountIncreased(collateralsCountToReturn, s_validatorData.collateralReturnedCount);

            // Send collaterals to client
            P2pAddressLib._sendValue(s_clientConfig.recipient, collateralsCountToReturn * COLLATERAL);

            // Balance remainder to split
            balance = address(this).balance;
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

        emit Withdrawn(serviceAmount, clientAmount, referrerAmount);
    }

    function recoverEther(address payable _to) external onlyOwner {
        this.withdraw();

        // get the contract's balance
        uint256 balance = address(this).balance;

        if (balance > 0) { // only happens if at least 1 party reverted in their receive
            bool success = P2pAddressLib._sendValue(_to, balance);

            if (success) {
                emit EtherRecovered(_to, balance);
            } else {
                emit EtherRecoveryFailed(_to, balance);
            }
        }
    }

    function depositedCount() external view returns (uint32) {
        return s_validatorData.depositedCount;
    }

    function exitedCount() external view returns (uint32) {
        return s_validatorData.exitedCount;
    }

    function collateralReturnedCount() external view returns (uint32) {
        return s_validatorData.collateralReturnedCount;
    }

    function eth2WithdrawalCredentialsAddress() external override view returns (address) {
        return address(this);
    }
}
