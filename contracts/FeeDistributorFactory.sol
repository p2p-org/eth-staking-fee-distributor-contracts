// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./FeeDistributor.sol";

/** @title Factory for cloning (EIP-1167) FeeDistributor instances pre client
*/
contract FeeDistributorFactory {
    // Type Declarations
    using Clones for address;

    // State variables
    address private immutable i_referenceFeeDistributor;

    function initialize(address _referenceFeeDistributor) external onlyFactory {
        i_referenceFeeDistributor = _referenceFeeDistributor;
    }

    function createFeeDistributor(address _client) external returns (address) {
        address newFeeDistributorAddrress = i_referenceFeeDistributor.clone();
        FeeDistributor newFeeDistributor = FeeDistributor(newFeeDistributorAddrress);
        newFeeDistributor.initialize(_client);
        return newFeeDistributorAddrress;
    }
}
