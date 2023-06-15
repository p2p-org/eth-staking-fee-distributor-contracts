// SPDX-FileCopyrightText: 2022 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "../feeDistributorFactory/IFeeDistributorFactory.sol";
import "../assetRecovering/OwnableTokenRecoverer.sol";
import "./IFeeDistributor.sol";
import "./FeeDistributorErrors.sol";
import "../structs/P2pStructs.sol";
import "../lib/P2pAddressLib.sol";

abstract contract BaseFeeDistributor is OwnableTokenRecoverer, ReentrancyGuard, ERC165, IFeeDistributor {

    IFeeDistributorFactory internal immutable i_factory;
    address payable internal immutable i_service;

    FeeRecipient internal s_clientConfig;
    FeeRecipient internal s_referrerConfig;

    modifier onlyClient() {
        address clientAddress = s_clientConfig.recipient;

        if (clientAddress != msg.sender) {
            revert FeeDistributor__CallerNotClient(msg.sender, clientAddress);
        }
        _;
    }

    modifier onlyFactory() {
        if (msg.sender != address(i_factory)) {
            revert FeeDistributor__NotFactoryCalled(msg.sender, i_factory);
        }
        _;
    }

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

    function initialize(
        FeeRecipient calldata _clientConfig,
        FeeRecipient calldata _referrerConfig
    ) external onlyFactory {
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
                revert FeeDistributor__ClientPlusReferralBasisPointsExceed10000(
                    _clientConfig.basisPoints,
                    _referrerConfig.basisPoints
                );
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

        emit FeeDistributor__Initialized(
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

    receive() external payable {
        // only accept ether in an instance, not in a template
        if (s_clientConfig.recipient == address(0)) {
            revert FeeDistributor__ClientNotSet();
        }
    }

    function increaseDepositedCount(uint32 _validatorCountToAdd) external virtual {
        // Do nothing by defaulf. Can be overridden.
    }

    function voluntaryExit(bytes[] calldata _pubkeys) public virtual onlyClient {
        emit FeeDistributor__VoluntaryExit(_pubkeys);
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

    function eth2WithdrawalCredentialsAddress() external virtual view returns (address);

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IFeeDistributor).interfaceId || super.supportsInterface(interfaceId);
    }

    function owner() public view override returns (address) {
        return i_factory.owner();
    }
}
