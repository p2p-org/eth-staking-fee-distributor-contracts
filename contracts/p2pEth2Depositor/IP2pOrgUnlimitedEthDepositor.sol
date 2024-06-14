// SPDX-FileCopyrightText: 2024 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "../@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "../feeDistributor/IFeeDistributor.sol";
import "../structs/P2pStructs.sol";

/// @dev External interface of P2pOrgUnlimitedEthDepositor declared to support ERC165 detection.
interface IP2pOrgUnlimitedEthDepositor is IERC165 {
    /// @notice Emits when a client adds ETH for staking
    /// @param _depositId ID of client deposit (derived from ETH2 WithdrawalCredentials, ETH amount per validator in wei, fee distributor instance address)
    /// @param _sender address who sent ETH
    /// @param _feeDistributorInstance address of FeeDistributor instance that determines the terms of staking service
    /// @param _eth2WithdrawalCredentials ETH2 withdrawal credentials
    /// @param _amount sent amount of ETH in wei
    /// @param _expiration block timestamp after which the client will be able to get a refund
    /// @param _ethAmountPerValidatorInWei amount of ETH to deposit per 1 validator (should be >= 32 and <= 2048)
    /// @param _extraData any other data to pass to the event listener
    event P2pOrgUnlimitedEthDepositor__ClientEthAdded(
        bytes32 indexed _depositId,
        address indexed _sender,
        address indexed _feeDistributorInstance,
        bytes32 _eth2WithdrawalCredentials,
        uint256 _amount,
        uint40 _expiration,
        uint96 _ethAmountPerValidatorInWei,
        bytes _extraData
    );

    /// @notice Emits when a refund has been sent to the client
    /// @param _depositId ID of client deposit (derived from ETH2 WithdrawalCredentials, ETH amount per validator in wei, fee distributor instance address)
    /// @param _feeDistributorInstance address of FeeDistributor instance that was associated with the client deposit
    /// @param _client address who received the refunded ETH
    /// @param _amount refunded amount of ETH in wei
    event P2pOrgUnlimitedEthDepositor__Refund(
        bytes32 indexed _depositId,
        address indexed _feeDistributorInstance,
        address indexed _client,
        uint256 _amount
    );

    /// @notice Emits when P2P has made ETH2 deposits with client funds and withdrawal credentials
    /// @param _depositId ID of client deposit (derived from ETH2 WithdrawalCredentials, ETH amount per validator in wei, fee distributor instance address)
    /// @param _validatorCount number of validators that has been created
    event P2pOrgUnlimitedEthDepositor__Eth2Deposit(
        bytes32 indexed _depositId,
        uint256 _validatorCount
    );

    /// @notice Emits when all the available ETH has been forwarded to Beacon DepositContract
    /// @param _depositId ID of client deposit (derived from ETH2 WithdrawalCredentials, ETH amount per validator in wei, fee distributor instance address)
    event P2pOrgUnlimitedEthDepositor__Eth2DepositCompleted(
        bytes32 indexed _depositId
    );

    /// @notice Emits when some (but not all) of the available ETH has been forwarded to Beacon DepositContract
    /// @param _depositId ID of client deposit (derived from ETH2 WithdrawalCredentials, ETH amount per validator in wei, fee distributor instance address)
    event P2pOrgUnlimitedEthDepositor__Eth2DepositInProgress(
        bytes32 indexed _depositId
    );

    /// @notice Emits when P2P rejects the service for a given FeeDistributor client instance.
    /// The client can get a full refund immediately in this case.
    /// @param _depositId ID of client deposit (derived from ETH2 WithdrawalCredentials, ETH amount per validator in wei, fee distributor instance address)
    /// @param _reason optional reason why P2P decided not to provide service
    event P2pOrgUnlimitedEthDepositor__ServiceRejected(
        bytes32 indexed _depositId,
        string _reason
    );

    /// @notice Emits when EIP-7251 has been enabled
    event P2pOrgUnlimitedEthDepositor__Eip7251Enabled();

    /// @notice make makeBeaconDeposit work with custom deposit amount
    /// @dev Callable by deployer
    /// @dev Should be called after Pectra hardfork
    function enableEip7251() external;

    /// @notice Send unlimited amount of ETH along with the fixed terms of staking service
    /// Callable by clients
    /// @param _eth2WithdrawalCredentials ETH2 withdrawal credentials
    /// @param _ethAmountPerValidatorInWei amount of ETH to deposit per 1 validator (should be >= 32 and <= 2048)
    /// @param _referenceFeeDistributor address of FeeDistributor template that determines the terms of staking service
    /// @param _clientConfig address and basis points (percent * 100) of the client
    /// @param _referrerConfig address and basis points (percent * 100) of the referrer.
    /// @param _extraData any other data to pass to the event listener
    /// @return depositId ID of client deposit (derived from ETH2 WithdrawalCredentials, ETH amount per validator in wei, fee distributor instance address)
    /// @return feeDistributorInstance client FeeDistributor instance
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
        returns (bytes32 depositId, address feeDistributorInstance);

    /// @notice Reject the service for a given ID of client deposit.
    /// @dev Allows the client to avoid waiting for expiration to get a refund.
    /// @dev Can be helpful if the client made a mistake while adding ETH.
    /// @dev Callable by P2P
    /// @param _depositId ID of client deposit (derived from ETH2 WithdrawalCredentials, ETH amount per validator in wei, fee distributor instance address)
    /// @param _reason optional reason why P2P decided not to provide service
    function rejectService(
        bytes32 _depositId,
        string calldata _reason
    ) external;

    /// @notice refund the unused for staking ETH after the expiration timestamp.
    /// If not called, all multiples of 32 ETH will be used for staking eventually.
    /// @param _eth2WithdrawalCredentials ETH2 withdrawal credentials
    /// @param _ethAmountPerValidatorInWei amount of ETH to deposit per 1 validator (should be >= 32 and <= 2048)
    /// @param _feeDistributorInstance client FeeDistributor instance that has non-zero ETH amount (can be checked by `depositAmount`)
    function refund(
        bytes32 _eth2WithdrawalCredentials,
        uint96 _ethAmountPerValidatorInWei,
        address _feeDistributorInstance
    ) external;

    /// @notice Send ETH to ETH2 DepositContract on behalf of the client. Callable by P2P
    /// @param _eth2WithdrawalCredentials ETH2 withdrawal credentials
    /// @param _ethAmountPerValidatorInWei amount of ETH to deposit per 1 validator (should be >= 32 and <= 2048)
    /// @param _feeDistributorInstance user FeeDistributor instance that determines the terms of staking service
    /// @param _pubkeys BLS12-381 public keys
    /// @param _signatures BLS12-381 signatures
    /// @param _depositDataRoots SHA-256 hashes of the SSZ-encoded DepositData objects
    function makeBeaconDeposit(
        bytes32 _eth2WithdrawalCredentials,
        uint96 _ethAmountPerValidatorInWei,
        address _feeDistributorInstance,
        bytes[] calldata _pubkeys,
        bytes[] calldata _signatures,
        bytes32[] calldata _depositDataRoots
    ) external;

    /// @notice Returns the total contract ETH balance in wei
    /// @return uint256 total contract ETH balance in wei
    function totalBalance() external view returns (uint256);

    /// @notice Returns the ID of client deposit
    /// @param _eth2WithdrawalCredentials ETH2 withdrawal credentials
    /// @param _ethAmountPerValidatorInWei amount of ETH to deposit per 1 validator (should be >= 32 and <= 2048)
    /// @param _feeDistributorInstance user FeeDistributor instance that determines the terms of staking service
    /// @return bytes32 deposit ID
    function getDepositId(
        bytes32 _eth2WithdrawalCredentials,
        uint96 _ethAmountPerValidatorInWei,
        address _feeDistributorInstance
    ) external pure returns (bytes32);

    /// @notice Returns the ID of client deposit
    /// @param _eth2WithdrawalCredentials ETH2 withdrawal credentials
    /// @param _ethAmountPerValidatorInWei amount of ETH to deposit per 1 validator (should be >= 32 and <= 2048)
    /// @param _referenceFeeDistributor address of FeeDistributor template that determines the terms of staking service
    /// @param _clientConfig address and basis points (percent * 100) of the client
    /// @param _referrerConfig address and basis points (percent * 100) of the referrer.
    /// @return bytes32 deposit ID
    function getDepositId(
        bytes32 _eth2WithdrawalCredentials,
        uint96 _ethAmountPerValidatorInWei,
        address _referenceFeeDistributor,
        FeeRecipient calldata _clientConfig,
        FeeRecipient calldata _referrerConfig
    ) external view returns (bytes32);

    /// @notice Returns the amount of ETH in wei that is associated with a client FeeDistributor instance
    /// @param _depositId ID of client deposit (derived from ETH2 WithdrawalCredentials, ETH amount per validator in wei, fee distributor instance address)
    /// @return uint112 amount of ETH in wei
    function depositAmount(bytes32 _depositId) external view returns (uint112);

    /// @notice Returns the block timestamp after which the client will be able to get a refund
    /// @param _depositId ID of client deposit (derived from ETH2 WithdrawalCredentials, ETH amount per validator in wei, fee distributor instance address)
    /// @return uint40 block timestamp
    function depositExpiration(
        bytes32 _depositId
    ) external view returns (uint40);

    /// @notice Returns the status of the deposit
    /// @param _depositId ID of client deposit (derived from ETH2 WithdrawalCredentials, ETH amount per validator in wei, fee distributor instance address)
    /// @return ClientDepositStatus status
    function depositStatus(
        bytes32 _depositId
    ) external view returns (ClientDepositStatus);
}
