// SPDX-FileCopyrightText: 2024 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "../@openzeppelin/contracts/proxy/Clones.sol";
import "../@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "./interfaces/IDepositContract.sol";
import "../lib/P2pAddressLib.sol";
import "./P2pOrgUnlimitedEthDepositorErrors.sol";
import "../constants/P2pConstants.sol";
import "./IP2pOrgUnlimitedEthDepositor.sol";
import "../feeDistributorFactory/IFeeDistributorFactory.sol";
import "../structs/P2pStructs.sol";

/// @title Single entrypoint contract for P2P Validator ETH staking deposits
/// @dev All client sent ETH is temporarily held in this contract until P2P picks it up
/// to further forward to the Beacon (aka ETH2) DepositContract.
/// There are no other ways for any ETH to go from this contract other than to:
/// 1) Beacon DepositContract with client defined withdrawal credentials
/// 2) Client defined withdrawal credentials address itself
contract P2pOrgUnlimitedEthDepositor is ERC165, IP2pOrgUnlimitedEthDepositor {
    /// @notice Beacon DepositContract address
    IDepositContract public immutable i_depositContract;

    /// @notice FeeDistributorFactory address
    IFeeDistributorFactory public immutable i_feeDistributorFactory;

    /// @notice client deposit ID -> (amount, expiration)
    mapping(bytes32 => ClientDeposit) private s_deposits;

    /// @notice whether EIP-7251 has been enabled
    bool private s_eip7251Enabled;

    /// @dev Set values known at the initial deploy time.
    /// @param _feeDistributorFactory address of FeeDistributorFactory
    constructor(address _feeDistributorFactory) {
        if (
            !ERC165Checker.supportsInterface(
                _feeDistributorFactory,
                type(IFeeDistributorFactory).interfaceId
            )
        ) {
            revert P2pOrgUnlimitedEthDepositor__NotFactory(
                _feeDistributorFactory
            );
        }

        i_feeDistributorFactory = IFeeDistributorFactory(
            _feeDistributorFactory
        );

        i_depositContract = block.chainid == 1
            ? IDepositContract(0x00000000219ab540356cBB839Cbe05303d7705Fa) // real Mainnet DepositContract
            : IDepositContract(0x4242424242424242424242424242424242424242); // real Holesky DepositContract
    }

    /// @notice ETH should only be sent to this contract along with the `addEth` function
    receive() external payable {
        revert P2pOrgUnlimitedEthDepositor__DoNotSendEthDirectlyHere();
    }

    /// @inheritdoc IP2pOrgUnlimitedEthDepositor
    function enableEip7251() external {
        address eip7251Enabler = i_feeDistributorFactory.owner();
        if (msg.sender != eip7251Enabler) {
            revert P2pOrgUnlimitedEthDepositor__CallerNotEip7251Enabler(
                msg.sender,
                eip7251Enabler
            );
        }

        s_eip7251Enabled = true;

        emit P2pOrgUnlimitedEthDepositor__Eip7251Enabled();
    }

    /// @inheritdoc IP2pOrgUnlimitedEthDepositor
    function addEth(
        bytes32 _eth2WithdrawalCredentials,
        uint96 _ethAmountPerValidatorInWei,
        address _referenceFeeDistributor,
        FeeRecipient calldata _clientConfig,
        FeeRecipient calldata _referrerConfig,
        bytes calldata _extraData
    )
        external
        payable
        returns (bytes32 depositId, address feeDistributorInstance)
    {
        if (msg.value < MIN_DEPOSIT) {
            revert P2pOrgUnlimitedEthDepositor__NoSmallDeposits();
        }
        if (
            (_ethAmountPerValidatorInWei != MIN_ACTIVATION_BALANCE ||
                _eth2WithdrawalCredentials[0] != 0x01) && !s_eip7251Enabled
        ) {
            revert P2pOrgUnlimitedEthDepositor__Eip7251NotEnabledYet();
        }
        if (
            _eth2WithdrawalCredentials[0] != 0x01 &&
            _eth2WithdrawalCredentials[0] != 0x02
        ) {
            revert P2pOrgUnlimitedEthDepositor__IncorrectWithdrawalCredentialsPrefix(
                _eth2WithdrawalCredentials[0]
            );
        }
        if ((_eth2WithdrawalCredentials << 16) >> 176 != 0) {
            revert P2pOrgUnlimitedEthDepositor__WithdrawalCredentialsBytesNotZero(
                _eth2WithdrawalCredentials
            );
        }
        if (
            _ethAmountPerValidatorInWei < MIN_ACTIVATION_BALANCE ||
            _ethAmountPerValidatorInWei > MAX_EFFECTIVE_BALANCE
        ) {
            revert P2pOrgUnlimitedEthDepositor__EthAmountPerValidatorInWeiOutOfRange(
                _ethAmountPerValidatorInWei
            );
        }
        if (
            !ERC165Checker.supportsInterface(
                _referenceFeeDistributor,
                type(IFeeDistributor).interfaceId
            )
        ) {
            revert P2pOrgUnlimitedEthDepositor__NotFeeDistributor(
                _referenceFeeDistributor
            );
        }

        feeDistributorInstance = i_feeDistributorFactory
            .predictFeeDistributorAddress(
                _referenceFeeDistributor,
                _clientConfig,
                _referrerConfig
            );

        depositId = getDepositId(
            _eth2WithdrawalCredentials,
            _ethAmountPerValidatorInWei,
            feeDistributorInstance
        );

        if (
            s_deposits[depositId].status == ClientDepositStatus.ServiceRejected
        ) {
            revert P2pOrgUnlimitedEthDepositor__ShouldNotBeRejected(depositId);
        }

        if (feeDistributorInstance.code.length == 0) {
            // if feeDistributorInstance doesn't exist, deploy it

            i_feeDistributorFactory.createFeeDistributor(
                _referenceFeeDistributor,
                _clientConfig,
                _referrerConfig
            );
        }

        // amount = previous amount of feeDistributorInstance + new deposit
        uint112 amount = uint112(s_deposits[depositId].amount + msg.value);

        // reset expiration starting from the current block.timestamp
        uint40 expiration = uint40(block.timestamp + TIMEOUT);

        s_deposits[depositId] = ClientDeposit({
            amount: amount,
            expiration: expiration,
            status: ClientDepositStatus.EthAdded,
            ethAmountPerValidatorInWei: _ethAmountPerValidatorInWei
        });

        emit P2pOrgUnlimitedEthDepositor__ClientEthAdded(
            depositId,
            msg.sender,
            feeDistributorInstance,
            _eth2WithdrawalCredentials,
            amount,
            expiration,
            _ethAmountPerValidatorInWei,
            _extraData
        );
    }

    /// @inheritdoc IP2pOrgUnlimitedEthDepositor
    function rejectService(
        bytes32 _depositId,
        string calldata _reason
    ) external {
        i_feeDistributorFactory.checkOperatorOrOwner(msg.sender);

        if (s_deposits[_depositId].status == ClientDepositStatus.None) {
            revert P2pOrgUnlimitedEthDepositor__NoDepositToReject(_depositId);
        }

        s_deposits[_depositId].status = ClientDepositStatus.ServiceRejected;
        s_deposits[_depositId].expiration = 0; // allow the client to get a refund immediately

        emit P2pOrgUnlimitedEthDepositor__ServiceRejected(_depositId, _reason);
    }

    /// @inheritdoc IP2pOrgUnlimitedEthDepositor
    function refund(
        bytes32 _eth2WithdrawalCredentials,
        uint96 _ethAmountPerValidatorInWei,
        address _feeDistributorInstance
    ) public {
        address client = IFeeDistributor(_feeDistributorInstance).client();
        if (msg.sender != client) {
            revert P2pOrgUnlimitedEthDepositor__CallerNotClient(
                msg.sender,
                client
            );
        }

        bytes32 depositId = getDepositId(
            _eth2WithdrawalCredentials,
            _ethAmountPerValidatorInWei,
            _feeDistributorInstance
        );
        uint40 expiration = s_deposits[depositId].expiration;
        if (uint40(block.timestamp) < expiration) {
            revert P2pOrgUnlimitedEthDepositor__WaitForExpiration(
                expiration,
                uint40(block.timestamp)
            );
        }

        uint256 amount = s_deposits[depositId].amount;
        if (amount == 0) {
            revert P2pOrgUnlimitedEthDepositor__InsufficientBalance(depositId);
        }

        delete s_deposits[depositId];

        bool success = P2pAddressLib._sendValue(payable(client), amount);
        if (!success) {
            revert P2pOrgUnlimitedEthDepositor__FailedToSendEth(client, amount);
        }

        emit P2pOrgUnlimitedEthDepositor__Refund(
            depositId,
            _feeDistributorInstance,
            client,
            amount
        );
    }

    /// @inheritdoc IP2pOrgUnlimitedEthDepositor
    function makeBeaconDeposit(
        bytes32 _eth2WithdrawalCredentials,
        uint96 _ethAmountPerValidatorInWei,
        address _feeDistributorInstance,
        bytes[] calldata _pubkeys,
        bytes[] calldata _signatures,
        bytes32[] calldata _depositDataRoots
    ) external {
        i_feeDistributorFactory.checkOperatorOrOwner(msg.sender);

        bytes32 depositId = getDepositId(
            _eth2WithdrawalCredentials,
            _ethAmountPerValidatorInWei,
            _feeDistributorInstance
        );
        ClientDeposit memory clientDeposit = s_deposits[depositId];

        if (clientDeposit.status == ClientDepositStatus.ServiceRejected) {
            revert P2pOrgUnlimitedEthDepositor__ShouldNotBeRejected(depositId);
        }

        uint256 validatorCount = _pubkeys.length;
        uint112 amountToStake = uint112(
            _ethAmountPerValidatorInWei * validatorCount
        );

        if (validatorCount == 0 || validatorCount > VALIDATORS_MAX_AMOUNT) {
            revert P2pOrgUnlimitedEthDepositor__ValidatorCountError();
        }

        if (clientDeposit.amount < amountToStake) {
            revert P2pOrgUnlimitedEthDepositor__EtherValueError();
        }

        if (
            !(_signatures.length == validatorCount &&
                _depositDataRoots.length == validatorCount)
        ) {
            revert P2pOrgUnlimitedEthDepositor__AmountOfParametersError();
        }

        uint112 newAmount = clientDeposit.amount - amountToStake;
        s_deposits[depositId].amount = newAmount;
        if (newAmount == 0) {
            // all ETH has been deposited to Beacon DepositContract
            delete s_deposits[depositId];
            emit P2pOrgUnlimitedEthDepositor__Eth2DepositCompleted(depositId);
        } else {
            s_deposits[depositId].status = ClientDepositStatus
                .BeaconDepositInProgress;
            emit P2pOrgUnlimitedEthDepositor__Eth2DepositInProgress(depositId);
        }

        bytes memory withdrawalCredentials = new bytes(32);
        assembly ("memory-safe") {
            mstore(add(withdrawalCredentials, 32), _eth2WithdrawalCredentials)
        }

        for (uint256 i = 0; i < validatorCount; ) {
            // pubkey, withdrawal_credentials, signature lengths are already checked inside Beacon DepositContract

            i_depositContract.deposit{value: _ethAmountPerValidatorInWei}(
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

        emit P2pOrgUnlimitedEthDepositor__Eth2Deposit(
            depositId,
            validatorCount
        );
    }

    /// @inheritdoc IP2pOrgUnlimitedEthDepositor
    function totalBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /// @inheritdoc IP2pOrgUnlimitedEthDepositor
    function getDepositId(
        bytes32 _eth2WithdrawalCredentials,
        uint96 _ethAmountPerValidatorInWei,
        address _feeDistributorInstance
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    _eth2WithdrawalCredentials,
                    _ethAmountPerValidatorInWei,
                    _feeDistributorInstance
                )
            );
    }

    /// @inheritdoc IP2pOrgUnlimitedEthDepositor
    function getDepositId(
        bytes32 _eth2WithdrawalCredentials,
        uint96 _ethAmountPerValidatorInWei,
        address _referenceFeeDistributor,
        FeeRecipient calldata _clientConfig,
        FeeRecipient calldata _referrerConfig
    ) public view returns (bytes32) {
        address feeDistributorInstance = i_feeDistributorFactory
            .predictFeeDistributorAddress(
                _referenceFeeDistributor,
                _clientConfig,
                _referrerConfig
            );

        return
            getDepositId(
                _eth2WithdrawalCredentials,
                _ethAmountPerValidatorInWei,
                feeDistributorInstance
            );
    }

    /// @inheritdoc IP2pOrgUnlimitedEthDepositor
    function depositAmount(bytes32 _depositId) external view returns (uint112) {
        return s_deposits[_depositId].amount;
    }

    /// @inheritdoc IP2pOrgUnlimitedEthDepositor
    function depositExpiration(
        bytes32 _depositId
    ) external view returns (uint40) {
        return s_deposits[_depositId].expiration;
    }

    /// @inheritdoc IP2pOrgUnlimitedEthDepositor
    function depositStatus(
        bytes32 _depositId
    ) external view returns (ClientDepositStatus) {
        return s_deposits[_depositId].status;
    }

    /// @notice Returns whether EIP-7251 has been enabled
    function eip7251Enabled() external view returns (bool) {
        return s_eip7251Enabled;
    }

    /// @inheritdoc ERC165
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IP2pOrgUnlimitedEthDepositor).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
