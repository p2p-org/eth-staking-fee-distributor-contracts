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

error FeeDistributor__NotOracle(address _passedAddress);

error FeeDistributor__NonZeroInitialClientOnlyClRewards(uint176 _passedValue);

error FeeDistributor__InvalidFirstValidatorId(uint64 _firstValidatorId);

error FeeDistributor__InvalidValidatorCount(uint16 _validatorCount);

error FeeDistributor__NotFactory(address _passedAddress);

error FeeDistributor__ZeroAddressService();

error FeeDistributor__ClientAddressEqualsService(address _passedAddress);

error FeeDistributor__ZeroAddressClient();

error FeeDistributor__InvalidClientBasisPoints(uint96 _clientBasisPoints);

error FeeDistributor__ClientPlusReferralBasisPointsExceed10000(uint96 _clientBasisPoints, uint96 _referralBasisPoints);

error FeeDistributor__ReferrerAddressEqualsService(address _passedAddress);

error FeeDistributor__ReferrerAddressEqualsClient(address _passedAddress);

error FeeDistributor__NotFactoryCalled(address _msgSender, IFeeDistributorFactory _actualFactory);

error FeeDistributor__ClientAlreadySet(address _existingClient);

error FeeDistributor__ClientNotSet();

error FeeDistributor__ReferrerBasisPointsMustBeZeroIfAddressIsZero(uint96 _referrerBasisPoints);

error FeeDistributor__ServiceCannotReceiveEther(address _service);

error FeeDistributor__ClientCannotReceiveEther(address _client);

error FeeDistributor__ReferrerCannotReceiveEther(address _referrer);

error FeeDistributor__NothingToWithdraw();

error FeeDistributor__WaitForEnoughRewardsToWithdraw();

error FeeDistributor__CallerNotClient(address _caller, address _client);

contract ClElClientWcFeeDistributor is OwnableTokenRecoverer, ReentrancyGuard, ERC165, IFeeDistributor {

    IFeeDistributorFactory private immutable i_factory;
    IOracle private immutable i_oracle;
    address payable private immutable i_service;

    FeeRecipient private s_clientConfig;
    FeeRecipient private s_referrerConfig;
    ValidatorData private s_validatorData;

    constructor(
        address _oracle,
        address _factory,
        address payable _service
    ) {
        if (!ERC165Checker.supportsInterface(_oracle, type(IOracle).interfaceId)) {
            revert ClElClientWcFeeDistributor__NotOracle(_factory);
        }
        if (!ERC165Checker.supportsInterface(_factory, type(IFeeDistributorFactory).interfaceId)) {
            revert FeeDistributor__NotFactory(_factory);
        }
        if (_service == address(0)) {
            revert FeeDistributor__ZeroAddressService();
        }

        i_oracle = IOracle(_oracle);
        i_factory = IFeeDistributorFactory(_factory);
        i_service = _service;

        bool serviceCanReceiveEther = _sendValue(_service, 0);
        if (!serviceCanReceiveEther) {
            revert FeeDistributor__ServiceCannotReceiveEther(_service);
        }
    }

    modifier onlyClient() {
        address caller = _msgSender();
        address clientAddress = s_clientConfig.recipient;

        if (clientAddress != caller) {
            revert FeeDistributor__CallerNotClient(caller, clientAddress);
        }
        _;
    }

    receive() external payable {
        // only accept ether in an instance, not in a template
        if (s_clientConfig.recipient == address(0)) {
            revert FeeDistributor__ClientNotSet();
        }
    }

    function initialize(
        FeeRecipient calldata _clientConfig,
        FeeRecipient calldata _referrerConfig,
        ValidatorData calldata _validatorData
    ) external {
        if (msg.sender != address(i_factory)) {
            revert FeeDistributor__NotFactoryCalled(msg.sender, i_factory);
        }
        if (_clientConfig.recipient == address(0)) {
            revert FeeDistributor__ZeroAddressClient();
        }
        if (_clientConfig.recipient == i_service) {
            revert FeeDistributor__ClientAddressEqualsService(_clientConfig.recipient);
        }
        if (s_clientConfig.recipient != address(0)) {
            revert FeeDistributor__ClientAlreadySet(s_clientConfig.recipient);
        }
        if (_clientConfig.basisPoints > 10000) {
            revert FeeDistributor__InvalidClientBasisPoints(_clientConfig.basisPoints);
        }
        if (_validatorData.clientOnlyClRewards != 0) {
            revert FeeDistributor__NonZeroInitialClientOnlyClRewards(_validatorData.clientOnlyClRewards);
        }
        if (_validatorData.firstValidatorId == 0) {
            revert FeeDistributor__InvalidFirstValidatorId(_validatorData.firstValidatorId);
        }
        if (_validatorData.validatorCount == 0) {
            revert FeeDistributor__InvalidValidatorCount(_validatorData.validatorCount);
        }

        if (_referrerConfig.recipient != address(0)) {// if there is a referrer
            if (_referrerConfig.recipient == i_service) {
                revert FeeDistributor__ReferrerAddressEqualsService(_referrerConfig.recipient);
            }
            if (_referrerConfig.recipient == _clientConfig.recipient) {
                revert FeeDistributor__ReferrerAddressEqualsClient(_referrerConfig.recipient);
            }
            if (_clientConfig.basisPoints + _referrerConfig.basisPoints > 10000) {
                revert FeeDistributor__ClientPlusReferralBasisPointsExceed10000(_clientConfig.basisPoints, _referrerConfig.basisPoints);
            }

            // set referrer config
            s_referrerConfig = _referrerConfig;

        } else {// if there is no referrer
            if (_referrerConfig.basisPoints != 0) {
                revert FeeDistributor__ReferrerBasisPointsMustBeZeroIfAddressIsZero(_referrerConfig.basisPoints);
            }
        }

        // set client config
        s_clientConfig = _clientConfig;

        // set validator data
        s_validatorData = _validatorData;

        emit Initialized(
            _clientConfig.recipient,
            _clientConfig.basisPoints,
            _referrerConfig.recipient,
            _referrerConfig.basisPoints
        );

        bool clientCanReceiveEther = _sendValue(_clientConfig.recipient, 0);
        if (!clientCanReceiveEther) {
            revert FeeDistributor__ClientCannotReceiveEther(_clientConfig.recipient);
        }
        if (_referrerConfig.recipient != address(0)) {// if there is a referrer
            bool referrerCanReceiveEther = _sendValue(_referrerConfig.recipient, 0);
            if (!referrerCanReceiveEther) {
                revert FeeDistributor__ReferrerCannotReceiveEther(_referrerConfig.recipient);
            }
        }
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

            revert FeeDistributor__WaitForEnoughRewardsToWithdraw();
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
        s_validatorData.clientOnlyClRewards = uint176(vd.clientOnlyClRewards + (totalAmountToSplit - balance));

        // how much should referrer get
        uint256 referrerAmount;

        if (s_referrerConfig.recipient != address(0)) {
            // if there is a referrer

            referrerAmount = (totalAmountToSplit * s_referrerConfig.basisPoints) / 10000;

            serviceAmount -= referrerAmount;

            // Send ETH to referrer. Ignore the possible yet unlikely revert in the receive function.
            _sendValue(s_referrerConfig.recipient, referrerAmount);
        }

        // Send ETH to service. Ignore the possible yet unlikely revert in the receive function.
        _sendValue(i_service, serviceAmount);

        // Send ETH to client. Ignore the possible yet unlikely revert in the receive function.
        _sendValue(s_clientConfig.recipient, clientAmount);

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
            bool success = _sendValue(_to, balance);

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
        s_validatorData.clientOnlyClRewards = uint176(s_validatorData.clientOnlyClRewards + (totalAmountToSplit - balance));

        // how much should referrer get
        uint256 referrerAmount;

        if (s_referrerConfig.recipient != address(0)) {
            // if there is a referrer

            referrerAmount = (totalAmountToSplit * s_referrerConfig.basisPoints) / 10000;

            serviceAmount -= referrerAmount;

            // Send ETH to referrer. Ignore the possible yet unlikely revert in the receive function.
            _sendValue(s_referrerConfig.recipient, referrerAmount);
        }

        // Send ETH to service. Ignore the possible yet unlikely revert in the receive function.
        _sendValue(i_service, serviceAmount);

        // Send ETH to client. Ignore the possible yet unlikely revert in the receive function.
        _sendValue(s_clientConfig.recipient, clientAmount);

        emit Withdrawn(serviceAmount, clientAmount, referrerAmount);
    }

    function factory() external view returns (address) {
        return address(i_factory);
    }

    function service() external view returns (address) {
        return i_service;
    }

    function client() external view returns (address) {
        return s_clientConfig.recipient;
    }

    function clientBasisPoints() external view returns (uint256) {
        return s_clientConfig.basisPoints;
    }

    function referrer() external view returns (address) {
        return s_referrerConfig.recipient;
    }

    function referrerBasisPoints() external view returns (uint256) {
        return s_referrerConfig.basisPoints;
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
        return interfaceId == type(IFeeDistributor).interfaceId || super.supportsInterface(interfaceId);
    }

    function owner() public view override returns (address) {
        return i_factory.owner();
    }

    function _sendValue(address payable _recipient, uint256 _amount) internal returns (bool) {
        (bool success, ) = _recipient.call{
            value: _amount,
            gas: gasleft() / 4 // to prevent DOS, should be enough in normal cases
        }("");

        return success;
    }
}
