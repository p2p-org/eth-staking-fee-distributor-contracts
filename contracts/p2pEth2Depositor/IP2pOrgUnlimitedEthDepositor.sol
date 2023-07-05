// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "../feeDistributor/IFeeDistributor.sol";
import "../structs/P2pStructs.sol";

/// @dev External interface of P2pOrgUnlimitedEthDepositor declared to support ERC165 detection.
interface IP2pOrgUnlimitedEthDepositor is IERC165 {

    /// @notice Emits when a client adds ETH for staking
    /// @param _sender address who sent ETH
    /// @param _feeDistributorInstance address of FeeDistributor instance that determines the terms of staking service
    /// @param _amount sent amount of ETH in wei
    /// @param _expiration block timestamp after which the client will be able to get a refund
    event P2pOrgUnlimitedEthDepositor__ClientEthAdded(
        address indexed _sender,
        address indexed _feeDistributorInstance,
        uint256 _amount,
        uint40 _expiration
    );

    /// @notice Emits when a refund has been sent to the client
    /// @param _feeDistributorInstance address of FeeDistributor instance that was associated with the client deposit
    /// @param _client address who received the refunded ETH
    /// @param _amount refunded amount of ETH in wei
    event P2pOrgUnlimitedEthDepositor__Refund(
        address indexed _feeDistributorInstance,
        address indexed _client,
        uint256 _amount
    );

    /// @notice Emits when P2P has made ETH2 deposits with client funds and withdrawal credentials
    /// @param _feeDistributorAddress address of FeeDistributor instance that was associated with the client deposit
    /// @param _validatorCount number of validators that has been created
    event P2pOrgUnlimitedEthDepositor__Eth2Deposit(
        address indexed _feeDistributorAddress,
        uint256 _validatorCount
    );

    /// @notice Emits when all the available ETH has been forwarded to Beacon DepositContract
    /// @param _feeDistributorAddress address of FeeDistributor instance that was associated with the client deposit
    event P2pOrgUnlimitedEthDepositor__Eth2DepositCompleted(
        address indexed _feeDistributorAddress
    );

    /// @notice Emits when some (but not all) of the available ETH has been forwarded to Beacon DepositContract
    /// @param _feeDistributorAddress address of FeeDistributor instance that was associated with the client deposit
    event P2pOrgUnlimitedEthDepositor__Eth2DepositInProgress(
        address indexed _feeDistributorAddress
    );

    /// @notice Emits when P2P rejects the service for a given FeeDistributor client instance.
    /// The client can get a full refund immediately in this case.
    /// @param _feeDistributorAddress address of FeeDistributor instance that was associated with the client deposit
    /// @param _reason optional reason why P2P decided not to provide service
    event P2pOrgUnlimitedEthDepositor__ServiceRejected(
        address indexed _feeDistributorAddress,
        string _reason
    );

    /// @notice Send unlimited amount of ETH along with the fixed terms of staking service
    /// Callable by clients
    /// @param _referenceFeeDistributor address of FeeDistributor template that determines the terms of staking service
    /// @param _clientConfig address and basis points (percent * 100) of the client
    /// @param _referrerConfig address and basis points (percent * 100) of the referrer.
    /// @return feeDistributorInstance client FeeDistributor instance corresponding to the passed template
    function addEth(
        address _referenceFeeDistributor,
        FeeRecipient calldata _clientConfig,
        FeeRecipient calldata _referrerConfig
    ) external payable returns(address feeDistributorInstance);

    /// @notice Reject the service for a given FeeDistributor client instance.
    /// @dev Allows the client to avoid waiting for expiration to get a refund.
    /// @dev Can be helpful if the client made a mistake while adding ETH.
    /// @dev Callable by P2P
    /// @param _feeDistributorInstance client FeeDistributor instance corresponding to the passed template
    /// @param _reason optional reason why P2P decided not to provide service
    function rejectService(
        address _feeDistributorInstance,
        string calldata _reason
    ) external;

    /// @notice refund the unused for staking ETH after the expiration timestamp.
    /// If not called, all multiples of 32 ETH will be used for staking eventually.
    /// @param _feeDistributorInstance client FeeDistributor instance that has non-zero ETH amount (can be checked by `depositAmount`)
    function refund(address _feeDistributorInstance) external;

    /// @notice Send ETH to ETH2 DepositContract on behalf of the client. Callable by P2P
    /// @param _feeDistributorInstance user FeeDistributor instance that determines the terms of staking service
    /// @param _pubkeys BLS12-381 public keys
    /// @param _signatures BLS12-381 signatures
    /// @param _depositDataRoots SHA-256 hashes of the SSZ-encoded DepositData objects
    function makeBeaconDeposit(
        address _feeDistributorInstance,
        bytes[] calldata _pubkeys,
        bytes[] calldata _signatures,
        bytes32[] calldata _depositDataRoots
    ) external;

    /// @notice Returns the total contract ETH balance in wei
    /// @return uint256 total contract ETH balance in wei
    function totalBalance() external view returns (uint256);

    /// @notice Returns the amount of ETH in wei that is associated with a client FeeDistributor instance
    /// @param _feeDistributorInstance address of client FeeDistributor instance
    /// @return uint112 amount of ETH in wei
    function depositAmount(address _feeDistributorInstance) external view returns (uint112);

    /// @notice Returns the block timestamp after which the client will be able to get a refund
    /// @param _feeDistributorInstance address of client FeeDistributor instance
    /// @return uint40 block timestamp
    function depositExpiration(address _feeDistributorInstance) external view returns (uint40);

    /// @notice Returns the status of the deposit
    /// @param _feeDistributorInstance address of client FeeDistributor instance
    /// @return ClientDepositStatus status
    function depositStatus(address _feeDistributorInstance) external view returns (ClientDepositStatus);
}
