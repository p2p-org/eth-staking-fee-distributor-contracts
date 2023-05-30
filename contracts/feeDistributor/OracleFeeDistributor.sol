// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "../feeDistributorFactory/IFeeDistributorFactory.sol";
import "../assetRecovering/OwnableTokenRecoverer.sol";
import "./IFeeDistributor.sol";
import "../oracle/IOracle.sol";
import "../structs/P2pStructs.sol";
import "./BaseFeeDistributor.sol";

error OracleFeeDistributor__NotOracle(address _passedAddress);
error OracleFeeDistributor__NonZeroInitialClientOnlyClRewards(uint112 _passedValue);
error OracleFeeDistributor__InvalidFirstValidatorId(uint64 _firstValidatorId);
error OracleFeeDistributor__InvalidValidatorCount(uint32 _validatorCount);
error OracleFeeDistributor__WaitForEnoughRewardsToWithdraw();

contract OracleFeeDistributor is BaseFeeDistributor {

    IOracle private immutable i_oracle;

    ValidatorData private s_validatorData;

    constructor(
        address _oracle,
        address _factory,
        address payable _service
    ) BaseFeeDistributor(_factory, _service) {
        if (!ERC165Checker.supportsInterface(_oracle, type(IOracle).interfaceId)) {
            revert OracleFeeDistributor__NotOracle(_oracle);
        }

        i_oracle = IOracle(_oracle);
    }

    function initialize(
        FeeRecipient calldata _clientConfig,
        FeeRecipient calldata _referrerConfig,
        ValidatorData calldata _validatorData
    ) external {
        if (_validatorData.clientOnlyClRewards != 0) {
            revert OracleFeeDistributor__NonZeroInitialClientOnlyClRewards(_validatorData.clientOnlyClRewards);
        }
        if (_validatorData.firstValidatorId == 0) {
            revert OracleFeeDistributor__InvalidFirstValidatorId(_validatorData.firstValidatorId);
        }
        if (_validatorData.validatorCount == 0) {
            revert OracleFeeDistributor__InvalidValidatorCount(_validatorData.validatorCount);
        }

        // set validator data
        s_validatorData = _validatorData;

        _initialize(_clientConfig, _referrerConfig);
    }

    function withdraw(
        bytes32[] calldata _proof,
        uint256 _amountInGwei
    ) external nonReentrant {
        if (s_clientConfig.recipient == address(0)) {
            revert FeeDistributor__ClientNotSet();
        }

        // get the contract's balance
        uint256 balance = address(this).balance;

        if (balance == 0) {
            // revert if there is no ether to withdraw
            revert FeeDistributor__NothingToWithdraw();
        }

        // read from storage once
        ValidatorData memory vd = s_validatorData;

        // verify the data from the caller against the oracle
        i_oracle.verify(_proof, vd.firstValidatorId, vd.validatorCount, _amountInGwei);

        // Gwei to Wei
        uint256 amount = _amountInGwei * (10 ** 9);

        if (balance + amount < vd.clientOnlyClRewards) {
            // Can happen if the client has called emergencyEtherRecoveryWithoutOracleData before
            // but the actual rewards amount now appeared to be lower than the already split.
            // Should happen rarely.

            revert OracleFeeDistributor__WaitForEnoughRewardsToWithdraw();
        }

        // total to split = EL + CL - already split part of CL (should be OK unless halfBalance < serviceAmount)
        uint256 totalAmountToSplit = balance + amount - vd.clientOnlyClRewards;

        // set client basis points to value from storage config
        uint256 clientBp = s_clientConfig.basisPoints;

        // how much should service get
        uint256 serviceAmount = totalAmountToSplit - ((totalAmountToSplit * clientBp) / 10000);

        uint256 halfBalance = balance / 2;

        // how much should client get
        uint256 clientAmount;

        // if a half of the available balance is not enough to cover service (and referrer) shares
        // can happen when CL rewards (only accessible by client) are way much than EL rewards
        if (serviceAmount > halfBalance) {
            // client gets 50% of EL rewards
            clientAmount = halfBalance;

            // service (and referrer) get 50% of EL rewards combined (+1 wei in case balance is odd)
            serviceAmount = balance - halfBalance;

            // update the total amount being split to a smaller value to fit the actual balance of this contract
            totalAmountToSplit = (halfBalance * 10000) / (10000 - clientBp);
        } else {
            // send the remaining balance to client
            clientAmount = balance - serviceAmount;
        }

        // client gets the rest from CL as not split anymore amount
        s_validatorData.clientOnlyClRewards = uint112(vd.clientOnlyClRewards + (totalAmountToSplit - balance));

        // how much should referrer get
        uint256 referrerAmount;

        if (s_referrerConfig.recipient != address(0)) {
            // if there is a referrer

            referrerAmount = (totalAmountToSplit * s_referrerConfig.basisPoints) / 10000;

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

    function recoverEther(
        address payable _to,
        bytes32[] calldata _proof,
        uint256 _amountInGwei
    ) external onlyOwner {
        this.withdraw(_proof, _amountInGwei);

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

    function emergencyEtherRecoveryWithoutOracleData() external onlyClient nonReentrant {
        // get the contract's balance
        uint256 balance = address(this).balance;

        if (balance == 0) {
            // revert if there is no ether to withdraw
            revert FeeDistributor__NothingToWithdraw();
        }

        uint256 halfBalance = balance / 2;

        // client gets 50% of EL rewards
        uint256 clientAmount = halfBalance;

        // service (and referrer) get 50% of EL rewards combined (+1 wei in case balance is odd)
        uint256 serviceAmount = balance - halfBalance;

        // the total amount being split fits the actual balance of this contract
        uint256 totalAmountToSplit = (halfBalance * 10000) / (10000 - s_clientConfig.basisPoints);

        // client gets the rest from CL as not split anymore amount
        s_validatorData.clientOnlyClRewards = uint112(s_validatorData.clientOnlyClRewards + (totalAmountToSplit - balance));

        // how much should referrer get
        uint256 referrerAmount;

        if (s_referrerConfig.recipient != address(0)) {
            // if there is a referrer

            referrerAmount = (totalAmountToSplit * s_referrerConfig.basisPoints) / 10000;

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

    function firstValidatorId() external view returns (uint256) {
        return s_validatorData.firstValidatorId;
    }

    function clientOnlyClRewards() external view returns (uint256) {
        return s_validatorData.clientOnlyClRewards;
    }

    function validatorCount() external view returns (uint256) {
        return s_validatorData.validatorCount;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(OracleFeeDistributor).interfaceId || super.supportsInterface(interfaceId);
    }
}
