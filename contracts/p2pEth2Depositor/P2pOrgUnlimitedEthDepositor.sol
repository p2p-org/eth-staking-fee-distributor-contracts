// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "./interfaces/IDepositContract.sol";
import "../lib/P2pAddressLib.sol";
import "./P2pOrgUnlimitedEthDepositorErrors.sol";
import "./P2pOrgUnlimitedEthDepositorConstants.sol";
import "./IP2pOrgUnlimitedEthDepositor.sol";

contract P2pOrgUnlimitedEthDepositor is IP2pOrgUnlimitedEthDepositor {

    IDepositContract public immutable i_depositContract;

    mapping(address => ClientDeposit) public s_clientDeposits;

    constructor(bool _mainnet) {
        i_depositContract = _mainnet
            ? IDepositContract(0x00000000219ab540356cBB839Cbe05303d7705Fa) // real Mainnet DepositContract
            : IDepositContract(0xff50ed3d0ec03aC01D4C79aAd74928BFF48a7b2b); // real Goerli DepositContract
    }

    receive() external payable {
        revert P2pOrgUnlimitedEthDepositor__DoNotSendEthDirectlyHere();
    }

    function deposit(
        address _referenceFeeDistributor,
        IFeeDistributor.FeeRecipient calldata _clientConfig,
        IFeeDistributor.FeeRecipient calldata _referrerConfig
    ) public payable {
        if (msg.value == 0) {
            revert P2pOrgUnlimitedEthDepositor__NoZeroDeposits(msg.sender, _client);
        }

        if (!ERC165Checker.supportsInterface(_referenceFeeDistributor, type(IFeeDistributor).interfaceId)) {
            revert P2pOrgUnlimitedEthDepositor__NotFeeDistributor(_referenceFeeDistributor);
        }

        s_balanceOf[_client] = msg.value;

        // check if _client accepts ETH
        bool success = P2pAddressLib._sendValue(payable(_client), 0);
        if (!success) {
            revert P2pOrgUnlimitedEthDepositor__ClientNotAcceptingEth(_client);
        }

        emit P2pOrgUnlimitedEthDepositor__Deposit(msg.sender, _client, msg.value);
    }

    function refund() external {
        uint256 clientBalance = s_balanceOf[msg.sender];

        if (clientBalance == 0) {
            revert P2pOrgUnlimitedEthDepositor__InsufficientBalance();
        }

        s_balanceOf[msg.sender] = 0;

        bool success = P2pAddressLib._sendValue(payable(msg.sender), clientBalance);
        if (!success) {
            revert P2pOrgUnlimitedEthDepositor__FailedToSendEth(msg.sender, clientBalance);
        }

        emit P2pOrgUnlimitedEthDepositor__Refund(msg.sender, clientBalance);
    }

    function makeBeaconDeposit(
        bytes[] calldata _pubkeys,
        bytes[] calldata _signatures,
        bytes32[] calldata _deposit_data_roots
    ) external {

        uint256 validatorCount = _pubkeys.length;

        if (validatorCount == 0 || validatorCount > VALIDATORS_MAX_AMOUNT) {
            revert P2pOrgUnlimitedEthDepositor__ValidatorCountError();
        }

        if (msg.value != COLLATERAL * validatorCount) {
            revert P2pOrgUnlimitedEthDepositor__EtherValueError();
        }

        if (!(
            _signatures.length == validatorCount &&
            _deposit_data_roots.length == validatorCount
        )) {
            revert P2pOrgUnlimitedEthDepositor__AmountOfParametersError();
        }

        uint64 firstValidatorId = toUint64(i_depositContract.get_deposit_count()) + 1;

        for (uint256 i = 0; i < validatorCount;) {
            // pubkey, withdrawal_credentials, signature lengths are already checked inside ETH DepositContract

            i_depositContract.deposit{value : collateral}(
                _pubkeys[i],
                _withdrawal_credentials,
                _signatures[i],
                _deposit_data_roots[i]
            );

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        // First, make sure all the deposits are successful, then deploy FeeDistributor
        address newFeeDistributorAddress = i_feeDistributorFactory.createFeeDistributor(
            _clientConfig,
            _referrerConfig,
            IFeeDistributor.ValidatorData({
                clientOnlyClRewards : 0,
                firstValidatorId : firstValidatorId,
                validatorCount : uint32(validatorCount)
            })
        );

        emit P2pEth2DepositEvent(msg.sender, newFeeDistributorAddress, firstValidatorId, validatorCount);
    }

    function totalSupply() public view returns (uint256) {
        return address(this).balance;
    }

    function balanceOf(address _owner) external view returns (uint256) {
        return s_balanceOf[_owner];
    }
}
