// SPDX-FileCopyrightText: 2022 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "../feeDistributorFactory/IFeeDistributorFactory.sol";
import "../assetRecovering/OwnableTokenRecoverer.sol";
import "./IFeeDistributor.sol";
import "../structs/P2pStructs.sol";
import "../constants/P2pConstants.sol";
import "./BaseFeeDistributor.sol";

error ContractWcFeeDistributor__NoPubkeysPassed();
error ContractWcFeeDistributor__TooManyPubkeysPassed();

contract ContractWcFeeDistributor is BaseFeeDistributor {

    ValidatorData private s_validatorData;

    constructor(
        address _factory,
        address payable _service
    ) BaseFeeDistributor(_factory, _service) {
    }

    function initialize(
        FeeRecipient calldata _clientConfig,
        FeeRecipient calldata _referrerConfig,
        uint32 _depositedCount
    ) external { // onlyFactory due to _initialize
        s_validatorData.depositedCount = _depositedCount;

        _initialize(_clientConfig, _referrerConfig);
    }

    function increasedepositedCount(uint256 _validatorCountToAdd) external onlyFactory {
        s_validatorData.depositedCount += _validatorCountToAdd;
    }

    function voluntaryExit(bytes[] calldata _pubkeys) external override { // onlyClient due to BaseFeeDistributor
        if (_pubkeys.length == 0) {
            revert ContractWcFeeDistributor__NoPubkeysPassed();
        }
        if (_pubkeys.length > s_validatorData.depositedCount - s_validatorData.exitedCount) {
            revert ContractWcFeeDistributor__TooManyPubkeysPassed();
        }

        s_validatorData.exitedCount += _pubkeys.length;

        BaseFeeDistributor.voluntaryExit(_pubkeys);
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
            uint256 collateralsCountToReturn = balance / COLLATERAL;

            s_validatorData.collateralReturnedCount += collateralsCountToReturn;

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

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(ContractWcFeeDistributor).interfaceId || super.supportsInterface(interfaceId);
    }
}
