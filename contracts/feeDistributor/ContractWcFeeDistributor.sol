// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../structs/P2pStructs.sol";
import "../constants/P2pConstants.sol";
import "./BaseFeeDistributor.sol";

/// @notice Need to pass at least 1 pubkey that needs to be exited
error ContractWcFeeDistributor__NoPubkeysPassed();

/// @notice The number of pubkeys exceeds the number of non-exited validators
error ContractWcFeeDistributor__TooManyPubkeysPassed();

/// @title FeeDistributor accepting and splitting both CL and EL rewards.
/// @dev Its address must be used as 0x01 withdrawal credentials when making ETH2 deposit
contract ContractWcFeeDistributor is BaseFeeDistributor {

    /// @notice Emits when new ETH2 deposits have been reported
    /// @param _added number of newly added validators
    /// @param _newDepositedCount total number of all client deposited validators after the add
    event ContractWcFeeDistributor__DepositedCountIncreased(
        uint32 _added,
        uint32 _newDepositedCount
    );

    /// @notice Emits when new validators have been requested to exit
    /// @param _added number of newly requested to exit validators
    /// @param _newExitedCount total number of all client validators ever requested to exit
    event ContractWcFeeDistributor__ExitedCountIncreased(
        uint32 _added,
        uint32 _newExitedCount
    );

    /// @notice Emits when some portion of ETH has been returned to the client as a collateral return
    /// @param _added amount of newly returned ETH
    /// @param _newCollateralReturnedValue total collateral value returned to the client
    event ContractWcFeeDistributor__CollateralReturnedValueIncreased(
        uint112 _added,
        uint112 _newCollateralReturnedValue
    );

    /// @dev depositedCount, exitedCount, collateralReturnedValue stored in 1 storage slot
    ValidatorData private s_validatorData;

    /// @dev Set values that are constant, common for all the clients, known at the initial deploy time.
    /// @param _factory address of FeeDistributorFactory
    /// @param _service address of the service (P2P) fee recipient
    constructor(
        address _factory,
        address payable _service
    ) BaseFeeDistributor(_factory, _service) {
    }

    /// @notice Report that new ETH2 deposits have been made
    /// @param _validatorCountToAdd number of newly deposited validators
    function increaseDepositedCount(uint32 _validatorCountToAdd) external override {
        i_factory.check_Operator_Owner_P2pEth2Depositor(msg.sender);

        s_validatorData.depositedCount += _validatorCountToAdd;

        emit ContractWcFeeDistributor__DepositedCountIncreased(
            _validatorCountToAdd,
            s_validatorData.depositedCount
        );
    }

    /// @inheritdoc IFeeDistributor
    function voluntaryExit(bytes[] calldata _pubkeys) public override { // onlyClient due to BaseFeeDistributor
        if (_pubkeys.length == 0) {
            revert ContractWcFeeDistributor__NoPubkeysPassed();
        }
        if (_pubkeys.length > s_validatorData.depositedCount - s_validatorData.exitedCount) {
            revert ContractWcFeeDistributor__TooManyPubkeysPassed();
        }

        s_validatorData.exitedCount += uint32(_pubkeys.length);

        emit ContractWcFeeDistributor__ExitedCountIncreased(
            uint32(_pubkeys.length),
            s_validatorData.exitedCount
        );

        super.voluntaryExit(_pubkeys);
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

        if (s_validatorData.collateralReturnedValue / COLLATERAL < s_validatorData.exitedCount) {
            // If exited some of the validators voluntarily.
            // In case of slashing, the client can still call the voluntaryExit function to claim
            // non-splittable balance up to 32 ETH per validator,
            // thus getting some slashing protection covered from EL rewards.

            uint112 collateralValueToReturn = uint112(
                s_validatorData.exitedCount * COLLATERAL - s_validatorData.collateralReturnedValue
            );

            if (collateralValueToReturn > balance) {
                collateralValueToReturn = uint112(balance);
            }

            s_validatorData.collateralReturnedValue += collateralValueToReturn;

            emit ContractWcFeeDistributor__CollateralReturnedValueIncreased(
                collateralValueToReturn,
                s_validatorData.collateralReturnedValue
            );

            // Send collaterals to client
            P2pAddressLib._sendValue(
                s_clientConfig.recipient,
                collateralValueToReturn
            );

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
            P2pAddressLib._sendValue(
                s_referrerConfig.recipient,
                referrerAmount
            );
        }

        // Send ETH to service. Ignore the possible yet unlikely revert in the receive function.
        P2pAddressLib._sendValue(
            i_service,
            serviceAmount
        );

        // Send ETH to client. Ignore the possible yet unlikely revert in the receive function.
        P2pAddressLib._sendValue(
            s_clientConfig.recipient,
            clientAmount
        );

        emit FeeDistributor__Withdrawn(
            serviceAmount,
            clientAmount,
            referrerAmount
        );
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
                emit FeeDistributor__EtherRecoveryFailed(_to, balance);
            }
        }
    }

    /// @notice Returns the number of validators reported as deposited
    /// @return uint32 number of validators
    function depositedCount() external view returns (uint32) {
        return s_validatorData.depositedCount;
    }

    /// @notice Returns the number of validators requested to exit
    /// @return uint32 number of validators
    function exitedCount() external view returns (uint32) {
        return s_validatorData.exitedCount;
    }

    /// @notice Returns the amount of ETH returned to the client to cover the collaterals
    /// @return uint112 ETH value returned
    function collateralReturnedValue() external view returns (uint112) {
        return s_validatorData.collateralReturnedValue;
    }

    /// @inheritdoc IFeeDistributor
    /// @dev FeeDistributor's own address
    function eth2WithdrawalCredentialsAddress() external override view returns (address) {
        return address(this);
    }
}
