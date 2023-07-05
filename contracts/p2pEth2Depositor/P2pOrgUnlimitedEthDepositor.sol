// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

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

    /// @notice client FeeDistributor instance -> (amount, expiration)
    mapping(address => ClientDeposit) private s_deposits;

    /// @dev Set values known at the initial deploy time.
    /// @param _mainnet Mainnet=true Goerli=false
    /// @param _feeDistributorFactory address of FeeDistributorFactory
    constructor(bool _mainnet, address _feeDistributorFactory) {
        if (!ERC165Checker.supportsInterface(_feeDistributorFactory, type(IFeeDistributorFactory).interfaceId)) {
            revert P2pOrgUnlimitedEthDepositor__NotFactory(_feeDistributorFactory);
        }

        i_feeDistributorFactory = IFeeDistributorFactory(_feeDistributorFactory);

        i_depositContract = _mainnet
            ? IDepositContract(0x00000000219ab540356cBB839Cbe05303d7705Fa) // real Mainnet DepositContract
            : IDepositContract(0xff50ed3d0ec03aC01D4C79aAd74928BFF48a7b2b); // real Goerli DepositContract
    }

    /// @notice ETH should only be sent to this contract along with the `addEth` function
    receive() external payable {
        revert P2pOrgUnlimitedEthDepositor__DoNotSendEthDirectlyHere();
    }

    /// @inheritdoc IP2pOrgUnlimitedEthDepositor
    function addEth(
        address _referenceFeeDistributor,
        FeeRecipient calldata _clientConfig,
        FeeRecipient calldata _referrerConfig
    ) external payable returns(address feeDistributorInstance) {
        if (msg.value == 0) {
            revert P2pOrgUnlimitedEthDepositor__NoZeroDeposits();
        }

        if (!ERC165Checker.supportsInterface(_referenceFeeDistributor, type(IFeeDistributor).interfaceId)) {
            revert P2pOrgUnlimitedEthDepositor__NotFeeDistributor(_referenceFeeDistributor);
        }

        feeDistributorInstance = i_feeDistributorFactory.predictFeeDistributorAddress(
            _referenceFeeDistributor,
            _clientConfig,
            _referrerConfig
        );

        if (feeDistributorInstance.code.length == 0) {
            // if feeDistributorInstance doesn't exist, deploy it

            i_feeDistributorFactory.createFeeDistributor(
                _referenceFeeDistributor,
                _clientConfig,
                _referrerConfig
            );
        }

        // amount = previous amount of feeDistributorInstance + new deposit
        uint112 amount = uint112(s_deposits[feeDistributorInstance].amount + msg.value);

        // reset expiration starting from the current block.timestamp
        uint40 expiration = uint40(block.timestamp + TIMEOUT);

        s_deposits[feeDistributorInstance] = ClientDeposit({
            amount: amount,
            expiration: expiration,
            status: ClientDepositStatus.EthAdded,
            reservedForFutureUse: 0
        });

        emit P2pOrgUnlimitedEthDepositor__ClientEthAdded(
            msg.sender,
            feeDistributorInstance,
            amount,
            expiration
        );
    }

    /// @inheritdoc IP2pOrgUnlimitedEthDepositor
    function rejectService(
        address _feeDistributorInstance,
        string calldata _reason
    ) external {
        i_feeDistributorFactory.checkOperatorOrOwner(msg.sender);

        s_deposits[_feeDistributorInstance].status = ClientDepositStatus.ServiceRejected;
        s_deposits[_feeDistributorInstance].expiration = 0; // allow the client to get a refund immediately

        emit P2pOrgUnlimitedEthDepositor__ServiceRejected(_feeDistributorInstance, _reason);
    }

    /// @inheritdoc IP2pOrgUnlimitedEthDepositor
    function refund(
        address _feeDistributorInstance
    ) public {
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

        emit P2pOrgUnlimitedEthDepositor__Refund(_feeDistributorInstance, client, amount);
    }

    /// @notice Can be very gas expensive.
    /// Better use `refundAll(address[])`
    /// Only callable by client
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

    /// @notice Cheaper, requires calling feeDistributorFactory's allClientFeeDistributors externally first
    /// Only callable by client
    /// @param _allClientFeeDistributors array of all client FeeDistributor instances whose associated ETH amounts should be refunded
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

    /// @inheritdoc IP2pOrgUnlimitedEthDepositor
    function makeBeaconDeposit(
        address _feeDistributorInstance,
        bytes[] calldata _pubkeys,
        bytes[] calldata _signatures,
        bytes32[] calldata _depositDataRoots
    ) external {
        i_feeDistributorFactory.checkOperatorOrOwner(msg.sender);

        uint256 validatorCount = _pubkeys.length;
        uint112 amountToStake = uint112(COLLATERAL * validatorCount);

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

        uint112 newAmount = s_deposits[_feeDistributorInstance].amount - amountToStake;
        s_deposits[_feeDistributorInstance].amount = newAmount;
        if (newAmount == 0) { // all ETH has been deposited to Beacon DepositContract
            delete s_deposits[_feeDistributorInstance];
            emit P2pOrgUnlimitedEthDepositor__Eth2DepositCompleted(_feeDistributorInstance);
        } else {
            s_deposits[_feeDistributorInstance].status = ClientDepositStatus.BeaconDepositInProgress;
            emit P2pOrgUnlimitedEthDepositor__Eth2DepositInProgress(_feeDistributorInstance);
        }

        bytes memory withdrawalCredentials = abi.encodePacked(
            hex'010000000000000000000000',
            IFeeDistributor(_feeDistributorInstance).eth2WithdrawalCredentialsAddress()
        );

        for (uint256 i = 0; i < validatorCount;) {
            // pubkey, withdrawal_credentials, signature lengths are already checked inside Beacon DepositContract

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

        IFeeDistributor(_feeDistributorInstance).increaseDepositedCount(uint32(validatorCount));

        emit P2pOrgUnlimitedEthDepositor__Eth2Deposit(_feeDistributorInstance, validatorCount);
    }

    /// @inheritdoc IP2pOrgUnlimitedEthDepositor
    function totalBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /// @inheritdoc IP2pOrgUnlimitedEthDepositor
    function depositAmount(address _feeDistributorInstance) external view returns (uint112) {
        return s_deposits[_feeDistributorInstance].amount;
    }

    /// @inheritdoc IP2pOrgUnlimitedEthDepositor
    function depositExpiration(address _feeDistributorInstance) external view returns (uint40) {
        return s_deposits[_feeDistributorInstance].expiration;
    }

    /// @inheritdoc IP2pOrgUnlimitedEthDepositor
    function depositStatus(address _feeDistributorInstance) external view returns (ClientDepositStatus) {
        return s_deposits[_feeDistributorInstance].status;
    }

    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IP2pOrgUnlimitedEthDepositor).interfaceId || super.supportsInterface(interfaceId);
    }
}
