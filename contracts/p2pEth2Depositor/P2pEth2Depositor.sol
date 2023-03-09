// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "./interfaces/IDepositContract.sol";
import "../feeDistributorFactory/FeeDistributorFactory.sol";

contract P2pEth2Depositor {

    /**
    * @notice do not send ETH directly here
    */
    error P2pEth2Depositor__DoNotSendEthDirectlyHere();

    /**
    * @notice you can deposit only 1 to 1000 nodes per transaction
    */
    error P2pEth2Depositor__NodeCountError();

    /**
    * @notice the amount of ETH does not match the amount of nodes
    */
    error P2pEth2Depositor__EtherValueError();

    /**
    * @notice amount of parameters do no match
    */
    error P2pEth2Depositor__AmountOfParametersError();

    /**
     * @dev Eth2 Deposit Contract address.
     */
    IDepositContract public immutable depositContract;

    /**
    * @title Factory for cloning (EIP-1167) FeeDistributor instances pre client
    */
    FeeDistributorFactory public immutable feeDistributorFactory;

    /**
     * @dev Minimal and maximum amount of nodes per transaction.
     */
    uint256 public constant nodesMinAmount = 1;

    /**
    * @dev 314 deposits (10048 ETH) is determined by calldata size limit of 128 kb
    * @dev https://ethereum.stackexchange.com/questions/144120/maximum-calldata-size-per-block
    */
    uint256 public constant nodesMaxAmount = 314;

    /**
     * @dev Collateral size of one node.
     */
    uint256 public constant collateral = 32 ether;

    /**
     * @dev Setting Eth2 Smart Contract address during construction.
     */
    constructor(bool mainnet, address depositContract_, FeeDistributorFactory feeDistributorFactory_) {
        depositContract = mainnet
        ? IDepositContract(0x00000000219ab540356cBB839Cbe05303d7705Fa)
        : (depositContract_ == 0x0000000000000000000000000000000000000000)
            ? IDepositContract(0x8c5fecdC472E27Bc447696F431E425D02dd46a8c)
            : IDepositContract(depositContract_);

        feeDistributorFactory = feeDistributorFactory_;
    }

    /**
     * @dev This contract will not accept direct ETH transactions.
     */
    receive() external payable {
        revert P2pEth2Depositor__DoNotSendEthDirectlyHere();
    }

    /**
     * @dev Function that allows to deposit up to 1000 nodes at once.
     *
     * - pubkeys                - Array of BLS12-381 public keys.
     * - withdrawal_credentials - Array of commitments to a public keys for withdrawals.
     * - signatures             - Array of BLS12-381 signatures.
     * - deposit_data_roots     - Array of the SHA-256 hashes of the SSZ-encoded DepositData objects.
     */
    function deposit(
        bytes[] calldata pubkeys,
        byte calldata withdrawal_credentials, // 1, same for all
        bytes[] calldata signatures,
        bytes32[] calldata deposit_data_roots,
        IFeeDistributor.FeeRecipient calldata _clientConfig,
        IFeeDistributor.FeeRecipient calldata _referrerConfig
    ) external payable {

        uint256 nodesAmount = pubkeys.length;

        if (nodesAmount == 0 || nodesAmount > nodesMaxAmount) {
            revert P2pEth2Depositor__NodeCountError();
        }

        if (msg.value != collateral * nodesAmount) {
            revert P2pEth2Depositor__EtherValueError();
        }

        if (!(
            signatures.length == nodesAmount &&
            deposit_data_roots.length == nodesAmount
        )) {
            revert P2pEth2Depositor__AmountOfParametersError();
        }

        for (uint256 i = 0; i < nodesAmount;) {
            // pubkey, withdrawal_credentials, signature lengths are already checked inside ETH DepositContract

            depositContract.deposit{value: collateral}(
                pubkeys[i],
                withdrawal_credentials,
                signatures[i],
                deposit_data_roots[i]
            );

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        // First, make sure all the deposits are successful, then deploy FeeDistributor
        feeDistributorFactory.createFeeDistributor(
            _clientConfig,
            _referrerConfig
        );

        emit DepositEvent(msg.sender, nodesAmount);
    }

    event DepositEvent(address indexed from, uint256 nodesAmount);
}
