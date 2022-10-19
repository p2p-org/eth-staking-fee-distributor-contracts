// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../@openzeppelin/contracts/utils/Address.sol";
import "../@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "../feeDistributorFactory/IFeeDistributorFactory.sol";
import "../assetRecovering/PublicTokenRecoverer.sol";
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
* @notice Client address should be an actual client address, not zero.
*/
error FeeDistributor__ZeroAddressClient();

/**
* @notice Service percent should be >= 0 and <= 100
* @param _servicePercent passed incorrect service percent
*/
error FeeDistributor__InvalidServicePercent(uint256 _servicePercent);

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
* @title Contract receiving MEV and priority fees
* and distibuting them to the service and the client.
*/
contract FeeDistributor is PublicTokenRecoverer, ReentrancyGuard, ERC165, IFeeDistributor {
    // Type Declarations

    using Address for address payable;

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
    * @notice % of EL rewards that should go to the service (P2P)
    */
    uint256 private immutable i_servicePercent;

    /**
    * @notice address of the client
    */
    address payable private s_client;

    /**
    * @dev Set values that are constant, common for all the clients, known at the initial deploy time.
    * @param _factory address of FeeDistributorFactory
    * @param _service address of the service (P2P) fee recipient
    * @param _servicePercent % of EL rewards that should go to the service (P2P)
    */
    constructor(
        address _factory,
        address _service,
        uint256 _servicePercent
    ) {
        if (!ERC165Checker.supportsInterface(_factory, type(IFeeDistributorFactory).interfaceId)) {
            revert FeeDistributor__NotFactory(_factory);
        }
        if (_service == address(0)) {
            revert FeeDistributor__ZeroAddressService();
        }
        if (_servicePercent > 100) {
            revert FeeDistributor__InvalidServicePercent(_servicePercent);
        }

        i_factory = IFeeDistributorFactory(_factory);
        i_service = payable(_service);
        i_servicePercent = _servicePercent;
    }

    // Functions

    /**
    * @notice Set client address.
    * @dev Could not be in the constructor since it is different for different clients.
    * @param _client the address of the client
    */
    function initialize(address _client) external {
        if (msg.sender != address(i_factory)) {
            revert FeeDistributor__NotFactoryCalled(msg.sender, i_factory);
        }
        if (_client == address(0)) {
            revert FeeDistributor__ZeroAddressClient();
        }
        if (s_client != address(0)) {
            revert FeeDistributor__ClientAlreadySet(s_client);
        }

        s_client = payable(_client);
        emit Initialized(_client);
    }

    /**
    * @notice Withdraw the whole balance of the contract according to the pre-defined percentages.
    */
    function withdraw() external nonReentrant {
        if (s_client == address(0)) {
            revert FeeDistributor__ClientNotSet();
        }

        // get the contract's balance
        uint256 balance = address(this).balance;

        // how much should service get
        uint256 serviceAmount = (balance * i_servicePercent) / 100;

        // how much should client get
        uint256 clientAmount = balance - serviceAmount;

        // send ETH to service
        i_service.sendValue(serviceAmount);

        // send ETH to client
        s_client.sendValue(clientAmount);

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
        return s_client;
    }

    /**
     * @dev Returns the service percent
     */
    function getServicePercent() external view returns (uint256) {
        return i_servicePercent;
    }

    /**
    * @dev See {IERC165-supportsInterface}.
    */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IFeeDistributor).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Ownership of this contract is managed by the factory.
     */
    function _transferOwnership(address newOwner) internal override {
        // Do nothing. Cannot revert because otherwise the constructor would revert too.
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view override returns (address) {
        return i_factory.owner();
    }
}
