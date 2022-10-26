// SPDX-FileCopyrightText: 2022 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../@openzeppelin/contracts/utils/Address.sol";
import "../@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "../feeDistributorFactory/IFeeDistributorFactory.sol";
import "../assetRecovering/OwnableTokenRecoverer.sol";
import "./IFeeDistributor.sol";

/**
* @notice Should be a FeeDistributorFactory contract
* @param _passedAddress passed address that does not support IFeeDistributorFactory interface
*/
error FeeDistributor__NotFactory(address _passedAddress);

/**
* @notice Service address should be a secure P2P address, not zero.
*/
error FeeDistributor__ZeroAddressService();

/**
* @notice Client address should be different from service address.
* @param _passedAddress passed client address that equals to the service address
*/
error FeeDistributor__ClientAddressEqualsService(address _passedAddress);

/**
* @notice Client address should be an actual client address, not zero.
*/
error FeeDistributor__ZeroAddressClient();

/**
* @notice Service basis points should be >= 0 and <= 10000
* @param _serviceBasisPoints passed incorrect service basis points
*/
error FeeDistributor__InvalidServiceBasisPoints(uint256 _serviceBasisPoints);

/**
* @notice Only factory can call `initialize`.
* @param _msgSender sender address.
* @param _actualFactory the actual factory address that can call `initialize`.
*/
error FeeDistributor__NotFactoryCalled(address _msgSender, IFeeDistributorFactory _actualFactory);

/**
* @notice `initialize` should only be called once.
* @param _existingClient address of the client with which the contact has already been initialized.
*/
error FeeDistributor__ClientAlreadySet(address _existingClient);

/**
* @notice Cannot call `withdraw` if the client address is not set yet.
* @dev The client address is supposed to be set by the factory.
*/
error FeeDistributor__ClientNotSet();

/**
* @notice service should be able to receive ether.
* @param _service address of the service.
*/
error FeeDistributor__ServiceCannotReceiveEther(address _service);

/**
* @notice client should be able to receive ether.
* @param _client address of the client.
*/
error FeeDistributor__ClientCannotReceiveEther(address _client);

/**
* @title Contract receiving MEV and priority fees
* and distributing them to the service and the client.
*/
contract FeeDistributor is OwnableTokenRecoverer, ReentrancyGuard, ERC165, IFeeDistributor {
    // Type Declarations

    using Address for address payable;

    struct ClientConfig {
        /**
        * @notice basis points (percent * 100) of EL rewards that should go to the service (P2P)
        */
        uint96 serviceBasisPoints;

        /**
        * @notice address of the client
        */
        address payable client;
    } // 256bits-wide structure

    // State variables

    /**
    * @notice address of FeeDistributorFactory
    */
    IFeeDistributorFactory private immutable i_factory;

    /**
    * @notice address of the service (P2P) fee recipient
    */
    address payable private immutable i_service;

    /**
    * @notice client config (address of the client, service basis points)
    */
    ClientConfig private s_clientConfig;

    /**
    * @dev Set values that are constant, common for all the clients, known at the initial deploy time.
    * @param _factory address of FeeDistributorFactory
    * @param _service address of the service (P2P) fee recipient
    */
    constructor(
        address _factory,
        address _service
    ) {
        if (!ERC165Checker.supportsInterface(_factory, type(IFeeDistributorFactory).interfaceId)) {
            revert FeeDistributor__NotFactory(_factory);
        }
        if (_service == address(0)) {
            revert FeeDistributor__ZeroAddressService();
        }

        (bool serviceCanReceiveEther, ) = payable(_service).call{value: 0}("");
        if (!serviceCanReceiveEther) {
            revert FeeDistributor__ServiceCannotReceiveEther(_service);
        }

        i_factory = IFeeDistributorFactory(_factory);
        i_service = payable(_service);
    }

    // Functions

    /**
    * @notice Set client address.
    * @dev Could not be in the constructor since it is different for different clients.
    * @param _client the address of the client
    * @param _serviceBasisPoints basis points (percent * 100) of EL rewards that should go to the service (P2P)
    */
    function initialize(address _client, uint96 _serviceBasisPoints) external {
        if (msg.sender != address(i_factory)) {
            revert FeeDistributor__NotFactoryCalled(msg.sender, i_factory);
        }
        if (_client == address(0)) {
            revert FeeDistributor__ZeroAddressClient();
        }
        if (_client == i_service) {
            revert FeeDistributor__ClientAddressEqualsService(_client);
        }
        if (s_clientConfig.client != address(0)) {
            revert FeeDistributor__ClientAlreadySet(s_clientConfig.client);
        }
        if (_serviceBasisPoints > 10000) {
            revert FeeDistributor__InvalidServiceBasisPoints(_serviceBasisPoints);
        }

        (bool clientCanReceiveEther, ) = payable(_client).call{value: 0}("");
        if (!clientCanReceiveEther) {
            revert FeeDistributor__ClientCannotReceiveEther(_client);
        }

        s_clientConfig = ClientConfig({
            client: payable(_client),
            serviceBasisPoints: _serviceBasisPoints
        });

        emit Initialized(_client, _serviceBasisPoints);
    }

    /**
    * @notice Withdraw the whole balance of the contract according to the pre-defined basis points.
    */
    function withdraw() external nonReentrant {
        ClientConfig memory clientConfig = s_clientConfig;

        if (clientConfig.client == address(0)) {
            revert FeeDistributor__ClientNotSet();
        }

        // get the contract's balance
        uint256 balance = address(this).balance;

        // how much should service get
        uint256 serviceAmount = (balance * clientConfig.serviceBasisPoints) / 10000;

        // how much should client get
        uint256 clientAmount = balance - serviceAmount;

        // send ETH to service
        i_service.sendValue(serviceAmount);

        // send ETH to client
        clientConfig.client.sendValue(clientAmount);

        emit Withdrawn(serviceAmount, clientAmount);
    }

    /**
     * @dev Returns the factory address
     */
    function getFactory() external view returns (address) {
        return address(i_factory);
    }

    /**
     * @dev Returns the service address
     */
    function getService() external view returns (address) {
        return i_service;
    }

    /**
     * @dev Returns the client address
     */
    function getClient() external view returns (address) {
        return s_clientConfig.client;
    }

    /**
     * @dev Returns the service basis points
     */
    function getServiceBasisPoints() external view returns (uint256) {
        return s_clientConfig.serviceBasisPoints;
    }

    /**
    * @dev See {IERC165-supportsInterface}.
    */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IFeeDistributor).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view override returns (address) {
        return i_factory.owner();
    }
}
