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
    using Address for address;

    // State variables
    address private immutable i_factory;
    address private immutable i_owner;
    address private immutable i_service;
    uint256 private immutable i_servicePercent;
    uint256 private immutable i_clientPercent;

    address private s_client;

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

    // Functions Order:
    //// constructor
    //// receive
    //// fallback
    //// external
    //// public
    //// internal
    //// private
    //// view / pure

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
        i_service = _service;
        i_servicePercent = _servicePercent;
        i_clientPercent = _clientPercent;
    }

    function initialize(address _client) external onlyFactory {
        s_client = _client;
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        uint256 serviceAmount = balance * 100 / i_servicePercent;
        uint256 clientAmount = balance * 100 / i_clientPercent;

        i_service.sendValue(serviceAmount);
        s_client.sendValue(clientAmount);
    }
}
