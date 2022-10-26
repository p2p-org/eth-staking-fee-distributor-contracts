// SPDX-FileCopyrightText: 2022 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/console2.sol";
import "../../contracts/feeDistributorFactory/FeeDistributorFactory.sol";
import "../../contracts/feeDistributor/FeeDistributor.sol";


contract IntegrationTest is Test {
    address public deployer;
    address public owner;
    address public operator;
    address public nobody;

    Vm cheats = Vm(HEVM_ADDRESS);

    FeeDistributorFactory public factory;

    function setUp() public {
        // new deployed contracts will have Test as deployer
        deployer = address(this); 
       
        owner = cheats.addr(1);
        operator = cheats.addr(2);
        nobody = cheats.addr(3);
    }

    function testFuzzing(address service, address client,  uint96 serviceBasisPoints) public {
        factory = new FeeDistributorFactory();

        assertEq(factory.owner(), deployer);

        factory.transferOwnership(owner);

        assertEq(factory.owner(), owner);

        cheats.startPrank(owner);

        if (service == address(0)) {
            vm.expectRevert(FeeDistributor__ZeroAddressService.selector);
        }
        FeeDistributor referenceInstance = new FeeDistributor(address(factory), service);
        if (service == address(0)) {
            return;
        }

        factory.setReferenceInstance(address(referenceInstance));
        factory.changeOperator(operator);
        
        //cheats.stopPrank();
        //hoax(operator);
        //cheats.startPrank(operator);

        if (client == address(0)) {
            vm.expectRevert(FeeDistributor__ZeroAddressClient.selector);
        } else if (client == service) {
            vm.expectRevert(FeeDistributor__ClientAddressEqualsService.selector);
        } else if (serviceBasisPoints > 10000) {
            vm.expectRevert(FeeDistributor__InvalidServiceBasisPoints.selector);
        }
        factory.createFeeDistributor(client, serviceBasisPoints);
        if (client == address(0) || serviceBasisPoints > 10000) {
            return;
        }
    }
}
