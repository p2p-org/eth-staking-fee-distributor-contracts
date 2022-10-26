// SPDX-FileCopyrightText: 2022 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/console2.sol";
import "../../contracts/feeDistributorFactory/FeeDistributorFactory.sol";
import "../../contracts/feeDistributor/FeeDistributor.sol";

/**
* @title Happy path test with fuzzing
*/
contract HappyPathWithFuzzingTest is Test {
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

        // deploy factory
        factory = new FeeDistributorFactory();
    }

    function testFuzzing(address service, address client, uint96 serviceBasisPoints) public {
        assertEq(factory.owner(), deployer);

        factory.transferOwnership(owner);

        assertEq(factory.owner(), owner);

        cheats.startPrank(owner);

        bool serviceCanReceiveEther;
        if (service == address(0)) {
            vm.expectRevert(FeeDistributor__ZeroAddressService.selector);
        } else {
            (serviceCanReceiveEther, ) = payable(service).call{value: 0}("");
            if (!serviceCanReceiveEther) {
                vm.expectRevert(abi.encodeWithSelector(FeeDistributor__ServiceCannotReceiveEther.selector, service));
            }
        }
        // deploy reference instance of FeeDistributor
        FeeDistributor referenceInstance = new FeeDistributor(address(factory), service);
        if (service == address(0) || !serviceCanReceiveEther) {
            return;
        }

        factory.setReferenceInstance(address(referenceInstance));
        factory.changeOperator(operator);
        
        cheats.stopPrank();
        cheats.startPrank(operator);

        vm.recordLogs();
        bool clientCanReceiveEther;
        if (client == address(0)) {
            vm.expectRevert(FeeDistributor__ZeroAddressClient.selector);
        } else if (client == service) {
            vm.expectRevert(abi.encodeWithSelector(FeeDistributor__ClientAddressEqualsService.selector, client));
        } else if (serviceBasisPoints > 10000) {
            vm.expectRevert(abi.encodeWithSelector(FeeDistributor__InvalidServiceBasisPoints.selector, serviceBasisPoints));
        } else {
            (clientCanReceiveEther, ) = payable(client).call{value: 0}("");
            if (!clientCanReceiveEther) {
                vm.expectRevert(abi.encodeWithSelector(FeeDistributor__ClientCannotReceiveEther.selector, client));
            }
        }
        // create a client instance of FeeDistributor
        factory.createFeeDistributor(client, serviceBasisPoints);
        if (client == address(0) || serviceBasisPoints > 10000 || !clientCanReceiveEther) {
            return;
        }
        Vm.Log[] memory createFeeDistributorLogs = vm.getRecordedLogs();
        assertEq(createFeeDistributorLogs.length, 2);
        assertEq(createFeeDistributorLogs[0].topics[0], keccak256("Initialized(address,uint256)"));
        assertEq(createFeeDistributorLogs[1].topics[0], keccak256("FeeDistributorCreated(address,address)"));

        // get the client instance of FeeDistributor from event logs
        FeeDistributor clientInstanceOfFeeDistributor = FeeDistributor(address(uint160(uint256(createFeeDistributorLogs[1].topics[1]))));

        uint256 reward = 1 ether;

        // simulate generation of rewards for the client instance
        vm.deal(address(clientInstanceOfFeeDistributor), reward);

        uint256 serviceBalanceBefore = service.balance;
        uint256 clientBalanceBefore = client.balance;

        cheats.stopPrank();
        cheats.startPrank(nobody);
        vm.recordLogs();

        // call withdraw to distribute rewards
        clientInstanceOfFeeDistributor.withdraw();

        Vm.Log[] memory withdrawLogs = vm.getRecordedLogs();
        assertEq(withdrawLogs.length, 1);
        assertEq(withdrawLogs[0].topics[0], keccak256("Withdrawn(uint256,uint256)"));

        uint256 serviceExpectedReward = reward * serviceBasisPoints / 10000;
        uint256 serviceActualReward = service.balance - serviceBalanceBefore;

        uint256 clientExpectedReward = reward - reward * serviceBasisPoints / 10000;
        uint256 clientActualReward = client.balance - clientBalanceBefore;

        assertEq(serviceExpectedReward, serviceActualReward);
        assertEq(clientExpectedReward, clientActualReward);

        (uint256 serviceRewardFromLogs, uint256 clientRewardFromLogs) = abi.decode(withdrawLogs[0].data, (uint256, uint256));

        assertEq(serviceExpectedReward, serviceRewardFromLogs);
        assertEq(clientExpectedReward, clientRewardFromLogs);
    }
}
