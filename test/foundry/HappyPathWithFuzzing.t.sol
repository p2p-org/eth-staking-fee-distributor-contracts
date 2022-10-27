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

        deployFactory();
    }

    function testFuzzing(address service, address client, uint96 serviceBasisPoints) public {
        transferOwnership();
        (bool shouldQuit, FeeDistributor referenceInstance) = deployReferenceInstance(service);
        if (shouldQuit) {
            return;
        }
        setReferenceInstance(referenceInstance);
        changeOperator(referenceInstance);

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

    function deployFactory() internal {
        bytes32[] memory reads;
        bytes32[] memory writes;
        vm.record();

        // deploy factory
        factory = new FeeDistributorFactory();

        (reads, writes) = vm.accesses(
            address(factory)
        );

        assertEq(reads.length, 2);
        assertEq(uint256(reads[0]), 0);
        assertEq(uint256(reads[1]), 0);

        assertEq(writes.length, 1);
        assertEq(uint256(writes[0]), 0);

        bytes32 slot0 = cheats.load(address(factory), bytes32(uint256(0)));
        assertEq(address(uint160(uint256(slot0))), deployer);

        bytes32 slot1 = cheats.load(address(factory), bytes32(uint256(1)));
        assertEq(uint256(slot1), 0);

        bytes32 slot2 = cheats.load(address(factory), bytes32(uint256(1)));
        assertEq(uint256(slot2), 0);
    }

    function transferOwnership() internal {
        assertEq(factory.owner(), deployer);

        bytes32[] memory reads;
        bytes32[] memory writes;
        vm.record();

        factory.transferOwnership(owner);

        (reads, writes) = vm.accesses(
            address(factory)
        );

        assertEq(reads.length, 3);
        assertEq(uint256(reads[0]), 0);
        assertEq(uint256(reads[1]), 0);
        assertEq(uint256(reads[2]), 0);

        assertEq(writes.length, 1);
        assertEq(uint256(writes[0]), 0);

        bytes32 slot0 = cheats.load(address(factory), bytes32(uint256(0)));
        assertEq(address(uint160(uint256(slot0))), owner);

        bytes32 slot1 = cheats.load(address(factory), bytes32(uint256(1)));
        assertEq(uint256(slot1), 0);

        bytes32 slot2 = cheats.load(address(factory), bytes32(uint256(1)));
        assertEq(uint256(slot2), 0);

        assertEq(factory.owner(), owner);

        cheats.startPrank(owner);
    }

    function deployReferenceInstance(address service) internal returns (bool shouldQuit, FeeDistributor referenceInstance) {
        bytes32[] memory readsFactory;
        bytes32[] memory writesFactory;
        bytes32[] memory readsReferenceInstance;
        bytes32[] memory writesReferenceInstance;
        vm.record();

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
        referenceInstance = new FeeDistributor(address(factory), service);

        if (service == address(0) || !serviceCanReceiveEther) {
            shouldQuit = true;
        }

        (readsFactory, writesFactory) = vm.accesses(
            address(factory)
        );

        assertEq(readsFactory.length, 0);
        assertEq(writesFactory.length, 0);

        (readsReferenceInstance, writesReferenceInstance) = vm.accesses(
            address(referenceInstance)
        );

        assertEq(readsReferenceInstance.length, 1);
        assertEq(uint256(readsReferenceInstance[0]), 0);

        assertEq(writesReferenceInstance.length, 1);
        assertEq(uint256(writesReferenceInstance[0]), 0);

        // ReentrancyGuard _NOT_ENTERED
        bytes32 slot0 = cheats.load(address(referenceInstance), bytes32(uint256(0)));
        assertEq(uint256(slot0), 1);

        return (shouldQuit, referenceInstance);
    }

    function setReferenceInstance(FeeDistributor referenceInstance) internal {
        bytes32[] memory reads;
        bytes32[] memory writes;
        vm.record();

        factory.setReferenceInstance(address(referenceInstance));

        (reads, writes) = vm.accesses(
            address(factory)
        );

        assertEq(reads.length, 3);
        assertEq(uint256(reads[0]), 0);
        assertEq(uint256(reads[1]), 2);
        assertEq(uint256(reads[2]), 2);

        assertEq(writes.length, 1);
        assertEq(uint256(writes[0]), 2);

        bytes32 slot0 = cheats.load(address(factory), bytes32(uint256(0)));
        assertEq(address(uint160(uint256(slot0))), owner);

        bytes32 slot1 = cheats.load(address(factory), bytes32(uint256(1)));
        assertEq(uint256(slot1), 0);

        bytes32 slot2 = cheats.load(address(factory), bytes32(uint256(2)));
        assertEq(address(uint160(uint256(slot2))), address(referenceInstance));
    }

    function changeOperator(FeeDistributor referenceInstance) internal {
        bytes32[] memory reads;
        bytes32[] memory writes;
        vm.record();

        factory.changeOperator(operator);

        (reads, writes) = vm.accesses(
            address(factory)
        );

        assertEq(reads.length, 4);
        assertEq(uint256(reads[0]), 0);
        assertEq(uint256(reads[1]), 1);
        assertEq(uint256(reads[2]), 1);
        assertEq(uint256(reads[3]), 1);

        assertEq(writes.length, 1);
        assertEq(uint256(writes[0]), 1);

        bytes32 slot0 = cheats.load(address(factory), bytes32(uint256(0)));
        assertEq(address(uint160(uint256(slot0))), owner);

        bytes32 slot1 = cheats.load(address(factory), bytes32(uint256(1)));
        assertEq(address(uint160(uint256(slot1))), operator);

        bytes32 slot2 = cheats.load(address(factory), bytes32(uint256(2)));
        assertEq(address(uint160(uint256(slot2))), address(referenceInstance));

        bytes32 slot3 = cheats.load(address(factory), bytes32(uint256(3)));
        assertEq(uint256(slot3), 0);

        cheats.stopPrank();
        cheats.startPrank(operator);
    }
}
