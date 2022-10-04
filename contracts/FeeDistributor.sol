// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;
import "@openzeppelin/contracts/utils/Address.sol";

error FeeDistributor__NotOwner();
error FeeDistributor__NotFactory();
error PercentsDoNotMatch();

/** @title Contract receiving MEV and priority fees
* and distibuting them to the service and the client
*/
contract FeeDistributor {
    // Type Declarations
    using Address for address payable;

    // State variables

    /// address of FeeDistributorFactory
    address private immutable i_factory;

    /// address of the owner
    address private immutable i_owner;

    /// address of the service (P2P) fee recipient
    address payable private immutable i_service;

    /// % of EL rewards that should go to the service (P2P)
    uint256 private immutable i_servicePercent;

    /// % of EL rewards that should go to the client
    uint256 private immutable i_clientPercent;

    /// address of the client
    address payable private s_client;

    // Events

    // Modifiers
    modifier onlyOwner() {
        if (msg.sender != i_owner) revert FeeDistributor__NotOwner();
        _;
    }

    modifier onlyFactory() {
        if (msg.sender != i_factory) revert FeeDistributor__NotFactory();
        _;
    }

    /** @dev Set values that are constant, common for all the clients, known at the initial deploy time.
    */
    constructor(
        address _factory,
        address _owner,
        address _service,
        uint256 _servicePercent,
        uint256 _clientPercent
    ) {
        if (_servicePercent + _clientPercent != 100) {
            revert PercentsDoNotMatch();
        }

        i_factory = _factory;
        i_owner = _owner;
        i_service = payable(_service);
        i_servicePercent = _servicePercent;
        i_clientPercent = _clientPercent;
    }

    // Functions

    /** @dev Set client address. Could not be in the constructor since it is different for different clients.
    */
    function initialize(address _client) external onlyFactory {
        s_client = payable(_client);
    }

    /** @dev Withdraw the whole balance of the contract according to the pre-defined percentages.
    */
    function withdraw() external {
        // get the contract's balance
        uint256 balance = address(this).balance;

        // how much should service get
        uint256 serviceAmount = balance * i_servicePercent / 100;

        // how much should client get
        uint256 clientAmount = balance * i_clientPercent / 100;

        // send ETH to service
        i_service.sendValue(serviceAmount);

        // send ETH to client
        s_client.sendValue(clientAmount);
    }
}
