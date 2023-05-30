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

contract ElOnlyFeeDistributor is OwnableTokenRecoverer, ReentrancyGuard, ERC165, IFeeDistributor {

    IFeeDistributorFactory private immutable i_factory;
    address payable private immutable i_service;

    FeeRecipient private s_clientConfig;
    FeeRecipient private s_referrerConfig;

    constructor(
        address _factory,
        address payable _service
    ) {
        if (!ERC165Checker.supportsInterface(_factory, type(IFeeDistributorFactory).interfaceId)) {
            revert FeeDistributor__NotFactory(_factory);
        }
        if (_service == address(0)) {
            revert FeeDistributor__ZeroAddressService();
        }

        i_factory = IFeeDistributorFactory(_factory);
        i_service = _service;

        bool serviceCanReceiveEther = P2pAddressLib._sendValue(_service, 0);
        if (!serviceCanReceiveEther) {
            revert FeeDistributor__ServiceCannotReceiveEther(_service);
        }
    }

    receive() external payable {
        // only accept ether in an instance, not in a template
        if (s_clientConfig.recipient == address(0)) {
            revert FeeDistributor__ClientNotSet();
        }
    }

    function initialize(
        FeeRecipient calldata _clientConfig,
        FeeRecipient calldata _referrerConfig
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

        emit Initialized(
            _clientConfig.recipient,
            _clientConfig.basisPoints,
            _referrerConfig.recipient,
            _referrerConfig.basisPoints
        );

        bool clientCanReceiveEther = P2pAddressLib._sendValue(_clientConfig.recipient, 0);
        if (!clientCanReceiveEther) {
            revert FeeDistributor__ClientCannotReceiveEther(_clientConfig.recipient);
        }
        if (_referrerConfig.recipient != address(0)) {// if there is a referrer
            bool referrerCanReceiveEther = P2pAddressLib._sendValue(_referrerConfig.recipient, 0);
            if (!referrerCanReceiveEther) {
                revert FeeDistributor__ReferrerCannotReceiveEther(_referrerConfig.recipient);
            }
        }
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

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IFeeDistributor).interfaceId || super.supportsInterface(interfaceId);
    }

    function owner() public view override returns (address) {
        return i_factory.owner();
    }
}
