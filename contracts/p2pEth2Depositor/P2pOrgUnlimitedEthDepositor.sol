// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../@openzeppelin/contracts/proxy/Clones.sol";
import "../@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "./interfaces/IDepositContract.sol";
import "../lib/P2pAddressLib.sol";
import "./P2pOrgUnlimitedEthDepositorErrors.sol";
import "../constants/P2pConstants.sol";
import "./IP2pOrgUnlimitedEthDepositor.sol";
import "../feeDistributorFactory/IFeeDistributorFactory.sol";
import "../structs/P2pStructs.sol";

contract P2pOrgUnlimitedEthDepositor is IP2pOrgUnlimitedEthDepositor {

    IDepositContract public immutable i_depositContract;
    IFeeDistributorFactory public immutable i_feeDistributorFactory;

    mapping(address => ClientDeposit) private s_deposits;

    constructor(bool _mainnet, address _feeDistributorFactory) {
        if (!ERC165Checker.supportsInterface(_feeDistributorFactory, type(IFeeDistributorFactory).interfaceId)) {
            revert P2pOrgUnlimitedEthDepositor__NotFactory(_feeDistributorFactory);
        }

        i_feeDistributorFactory = IFeeDistributorFactory(_feeDistributorFactory);

        i_depositContract = _mainnet
            ? IDepositContract(0x00000000219ab540356cBB839Cbe05303d7705Fa) // real Mainnet DepositContract
            : IDepositContract(0xff50ed3d0ec03aC01D4C79aAd74928BFF48a7b2b); // real Goerli DepositContract
    }

    receive() external payable {
        revert P2pOrgUnlimitedEthDepositor__DoNotSendEthDirectlyHere();
    }

    function addEth(
        address _referenceFeeDistributor,
        FeeRecipient calldata _clientConfig,
        FeeRecipient calldata _referrerConfig,
        bytes calldata _additionalData
    ) external payable {
        if (msg.value == 0) {
            revert P2pOrgUnlimitedEthDepositor__NoZeroDeposits();
        }

        if (!ERC165Checker.supportsInterface(_referenceFeeDistributor, type(IFeeDistributor).interfaceId)) {
            revert P2pOrgUnlimitedEthDepositor__NotFeeDistributor(_referenceFeeDistributor);
        }

        address feeDistributorInstance = i_feeDistributorFactory.predictFeeDistributorAddress(
            _referenceFeeDistributor,
            _clientConfig,
            _referrerConfig
        );

        if (feeDistributorInstance.code.length == 0) {
            // if feeDistributorInstance doesn't exist, deploy it

            i_feeDistributorFactory.createFeeDistributor(
                _referenceFeeDistributor,
                _clientConfig,
                _referrerConfig,
                _additionalData
            );
        }

        // amount = previous amount of feeDistributorInstance + new deposit
        uint112 amount = uint112(s_deposits[feeDistributorInstance].amount + msg.value);

        // reset expiration starting from the current block.timestamp
        uint40 expiration = uint40(block.timestamp + TIMEOUT);

        s_deposits[feeDistributorInstance] = ClientDeposit({
            amount: amount,
            expiration: expiration
        });

        emit P2pOrgUnlimitedEthDepositor__Deposit(
            msg.sender,
            feeDistributorInstance,
            amount,
            expiration
        );
    }

    function refund(address _feeDistributorInstance) public {
        address client = IFeeDistributor(_feeDistributorInstance).client();
        if (msg.sender != client) {
            revert P2pOrgUnlimitedEthDepositor__CallerNotClient(msg.sender, client);
        }

        uint40 expiration = s_deposits[_feeDistributorInstance].expiration;
        if (uint40(block.timestamp) < expiration) {
            revert P2pOrgUnlimitedEthDepositor__WaitForExpiration(expiration, uint40(block.timestamp));
        }

        uint256 amount = s_deposits[_feeDistributorInstance].amount;
        if (amount == 0) {
            revert P2pOrgUnlimitedEthDepositor__InsufficientBalance(_feeDistributorInstance);
        }

        delete s_deposits[_feeDistributorInstance];

        bool success = P2pAddressLib._sendValue(payable(client), amount);
        if (!success) {
            revert P2pOrgUnlimitedEthDepositor__FailedToSendEth(client, amount);
        }

        emit P2pOrgUnlimitedEthDepositor__Refund(client, amount);
    }

    // Can be very gas expensive.
    // Better use refundAll(address[])
    // Only callable by client
    function refundAll() external {
        address[] memory allClientFeeDistributors = i_feeDistributorFactory.allClientFeeDistributors(msg.sender);

        for (uint256 i = 0; i < allClientFeeDistributors.length;) {
            refund(allClientFeeDistributors[i]);

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }
    }

    // Cheaper, requires calling feeDistributorFactory's allClientFeeDistributors externally first
    // Only callable by client
    function refundAll(address[] calldata _allClientFeeDistributors) external {
        for (uint256 i = 0; i < _allClientFeeDistributors.length;) {
            refund(_allClientFeeDistributors[i]);

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }
    }

    function makeBeaconDeposit(
        address _feeDistributorInstance,
        bytes[] calldata _pubkeys,
        bytes[] calldata _signatures,
        bytes32[] calldata _depositDataRoots
    ) external {
        i_feeDistributorFactory.checkOperatorOrOwner(msg.sender);

        uint256 validatorCount = _pubkeys.length;
        uint256 amountToStake = COLLATERAL * validatorCount;

        if (validatorCount == 0 || validatorCount > VALIDATORS_MAX_AMOUNT) {
            revert P2pOrgUnlimitedEthDepositor__ValidatorCountError();
        }

        if (s_deposits[_feeDistributorInstance].amount < amountToStake) {
            revert P2pOrgUnlimitedEthDepositor__EtherValueError();
        }

        if (!(
            _signatures.length == validatorCount &&
            _depositDataRoots.length == validatorCount
        )) {
            revert P2pOrgUnlimitedEthDepositor__AmountOfParametersError();
        }

        s_deposits[_feeDistributorInstance].amount -= amountToStake;

        address eth2WithdrawalCredentialsAddress = IFeeDistributor(_feeDistributorInstance).eth2WithdrawalCredentialsAddress();
        bytes memory withdrawalCredentials = abi.encode(hex'010000000000000000000000', eth2WithdrawalCredentialsAddress);

        for (uint256 i = 0; i < validatorCount;) {
            // pubkey, withdrawal_credentials, signature lengths are already checked inside ETH DepositContract

            i_depositContract.deposit{value : COLLATERAL}(
                _pubkeys[i],
                withdrawalCredentials,
                _signatures[i],
                _depositDataRoots[i]
            );

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        IFeeDistributor(_feeDistributorInstance).increaseDepositedCount(validatorCount);

        emit P2pEth2DepositEvent(_feeDistributorInstance, validatorCount);
    }

    function totalBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function depositAmount(address _feeDistributorInstance) external view returns (uint112) {
        return s_deposits[_feeDistributorInstance].amount;
    }

    function depositExpiration(address _feeDistributorInstance) external view returns (uint40) {
        return s_deposits[_feeDistributorInstance].expiration;
    }
}
