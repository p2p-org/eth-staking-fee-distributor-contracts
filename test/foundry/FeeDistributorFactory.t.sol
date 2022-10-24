// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "../../contracts/feeDistributorFactory/FeeDistributorFactory.sol";

contract FeeDistributorTest is Test {
    FeeDistributorFactory public factory;

    function setUp() public {
        factory = new FeeDistributorFactory();
    }

    function testOwner() public {
        assertEq(factory.owner(), address(this));
    }
}
