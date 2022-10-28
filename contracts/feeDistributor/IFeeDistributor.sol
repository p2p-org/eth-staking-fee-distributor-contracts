// SPDX-FileCopyrightText: 2022 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

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
    * @param _serviceBasisPoints basis points (percent * 100) of EL rewards that should go to the service (P2P)
    */
    event Initialized(address indexed _client, uint256 _serviceBasisPoints);

    // Functions

    /**
    * @notice Set client address.
    * @dev Could not be in the constructor since it is different for different clients.
    * @param _client the address of the client
    * @param _serviceBasisPoints basis points (percent * 100) of EL rewards that should go to the service (P2P)
    */
    function initialize(address _client, uint96 _serviceBasisPoints) external;

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
     * @dev Returns the service basis points
     */
    function getServiceBasisPoints() external view returns (uint256);
}
