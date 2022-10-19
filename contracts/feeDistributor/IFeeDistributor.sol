// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @dev External interface of FeeDistributor declared to support ERC165 detection.
 */
interface IFeeDistributor is IERC165 {
    // Events

    /**
    * @notice Emits on successful withdrawal
    * @param _serviceAmount how much wei service received
    * @param _clientAmount how much wei client received
    */
    event Withdrawn(uint256 _serviceAmount, uint256 _clientAmount);

    /**
    * @notice Emits once the client address has been set.
    * @param _client address of the client.
    */
    event Initialized(address indexed _client);

    // Functions

    /**
    * @notice Set client address.
    * @dev Could not be in the constructor since it is different for different clients.
    * @param _client the address of the client
    */
    function initialize(address _client) external;

    /**
    * @notice Withdraw the whole balance of the contract according to the pre-defined percentages.
    */
    function withdraw() external;

    /**
     * @dev Returns the factory address
     */
    function getFactory() external view returns (address);

    /**
     * @dev Returns the service address
     */
    function getService() external view returns (address);

    /**
     * @dev Returns the client address
     */
    function getClient() external view returns (address);

    /**
     * @dev Returns the service percent
     */
    function getServicePercent() external view returns (uint256);
}
