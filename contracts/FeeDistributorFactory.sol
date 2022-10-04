// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./FeeDistributor.sol";

/** @title Factory for cloning (EIP-1167) FeeDistributor instances pre client
*/
contract FeeDistributorFactory is Ownable {
    // Type Declarations
    using Clones for address;

    // State variables

    /** @dev The address of the reference implementation of FeeDistributor
    * that is used as the basis for clones
    */
    address private s_referenceFeeDistributor;

    // Events

    /** @dev Emits when a new FeeDistributor instance has been created for a client
    */
    event FeeDistributorCreated(address newFeeDistributorAddrress);

    // Functions

    /** @dev Set a new reference implementation of FeeDistributor
    */
    function initialize(address _referenceFeeDistributor) external onlyOwner {
        s_referenceFeeDistributor = _referenceFeeDistributor;
    }

    /** @dev Creates a FeeDistributor instance for a client
    * Emits `FeeDistributorCreated` event with the address of the newly created instance
    */
    function createFeeDistributor(address _client) external onlyOwner {
        // clone the reference implementation of FeeDistributor
        address newFeeDistributorAddrress = s_referenceFeeDistributor.clone();

        // cast address to FeeDistributor
        FeeDistributor newFeeDistributor = FeeDistributor(newFeeDistributorAddrress);

        // set the client address to the cloned FeeDistributor instance
        newFeeDistributor.initialize(_client);

        // emit event with the address of the newly created instance for the external listener
        emit FeeDistributorCreated(newFeeDistributorAddrress);
    }
}
