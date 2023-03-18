// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "./interfaces/IDepositContract.sol";
import "../feeDistributorFactory/FeeDistributorFactory.sol";
import "./IP2pEth2Depositor.sol";

contract P2pEth2Depositor is ERC165, IP2pEth2Depositor {

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
    * @dev Factory for cloning (EIP-1167) FeeDistributor instances pre client
    */
    FeeDistributorFactory public immutable i_feeDistributorFactory;

    /**
     * @dev Minimal and maximum amount of nodes per transaction.
     */
    uint256 public constant nodesMinAmount = 1;

    /**
    * @dev 314 deposits (10048 ETH) is determined by calldata size limit of 128 kb
    * @dev https://ethereum.stackexchange.com/questions/144120/maximum-calldata-size-per-block
    */
    uint256 public constant nodesMaxAmount = 500;

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

        i_feeDistributorFactory = feeDistributorFactory_;
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
        bytes calldata withdrawal_credentials, // 1, same for all
        bytes[] calldata signatures,
        bytes32[] calldata deposit_data_roots,
        IFeeDistributor.FeeRecipient calldata _clientConfig,
        IFeeDistributor.FeeRecipient calldata _referrerConfig
    ) external payable {

        uint256 validatorCount = pubkeys.length;

        if (validatorCount == 0 || validatorCount > nodesMaxAmount) {
            revert P2pEth2Depositor__NodeCountError();
        }

        if (msg.value != collateral * validatorCount) {
            revert P2pEth2Depositor__EtherValueError();
        }

        if (!(
            signatures.length == validatorCount &&
            deposit_data_roots.length == validatorCount
        )) {
            revert P2pEth2Depositor__AmountOfParametersError();
        }

        uint64 firstValidatorId = toUint64(depositContract.get_deposit_count()) + 1;

        for (uint256 i = 0; i < validatorCount;) {
            // pubkey, withdrawal_credentials, signature lengths are already checked inside ETH DepositContract

            depositContract.deposit{value : collateral}(
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
        i_feeDistributorFactory.createFeeDistributor(
            _clientConfig,
            _referrerConfig,
            IFeeDistributor.ValidatorData({
                clientOnlyClRewards : 0,
                firstValidatorId : firstValidatorId,
                validatorCount : uint16(validatorCount)
            })
        );

        emit P2pEth2DepositEvent(msg.sender, firstValidatorId, validatorCount);
    }

    /**
    * @dev See {IERC165-supportsInterface}.
    */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IP2pEth2Depositor).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
    * @dev Convert deposit_count from ETH2 DepositContract to uint64
    * ETH2 DepositContract returns inverted bytes. Need to invert them back.
    */
    function toUint64(bytes memory b) internal pure returns (uint64) {
        uint64 result;
        assembly {
            let x := mload(add(b, 8))

            result := or(
                or (
                    or(
                        and(0xff, shr(56, x)),
                        and(0xff00, shr(40, x))
                    ),
                    or(
                        and(0xff0000, shr(24, x)),
                        and(0xff000000, shr(8, x))
                    )
                ),

                or (
                    or(
                        and(0xff00000000, shl(8, x)),
                        and(0xff0000000000, shl(24, x))
                    ),
                    or(
                        and(0xff000000000000, shl(40, x)),
                        and(0xff00000000000000, shl(56, x))
                    )
                )
            )
        }
        return result;
    }
}
