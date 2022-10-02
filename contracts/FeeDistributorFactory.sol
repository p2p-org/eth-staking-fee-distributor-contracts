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
    address private s_referenceFeeDistributor;

    // Events
    event FeeDistributorCreated(address newFeeDistributorAddrress);

    function initialize(address _referenceFeeDistributor) external onlyOwner {
        s_referenceFeeDistributor = _referenceFeeDistributor;
    }

    function createFeeDistributor(address _client) external onlyOwner {
        address newFeeDistributorAddrress = s_referenceFeeDistributor.clone();
        FeeDistributor newFeeDistributor = FeeDistributor(newFeeDistributorAddrress);
        newFeeDistributor.initialize(_client);
        emit FeeDistributorCreated(newFeeDistributorAddrress);
    }
}
