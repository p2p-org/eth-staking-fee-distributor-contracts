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

    function testFuzzing(
        address service,
        address client,
        uint96 clientBasisPoints,
        address referrer,
        uint96 referrerBasisPoints
    ) public {
        clientBasisPoints = uint96(bound(clientBasisPoints, 0, 10000));
        referrerBasisPoints = uint96(bound(referrerBasisPoints, 0, 10000));

        transferOwnership();
        acceptOwnership();

        (bool shouldQuit1, FeeDistributor referenceInstance) = deployReferenceInstance(service);
        if (shouldQuit1) {
            return;
        }
        setReferenceInstance(referenceInstance);
        changeOperator(referenceInstance);
        (bool shouldQuit2, FeeDistributor clientInstanceOfFeeDistributor) = createFeeDistributor(
            service,
            client,
            clientBasisPoints,
            referrer,
            referrerBasisPoints
        );
        if (shouldQuit2) {
            emit log_string("shouldQuit2");
            return;
        }

        withdraw(
            service,
            client,
            clientBasisPoints,
            referrer,
            referrerBasisPoints,
            clientInstanceOfFeeDistributor
        );

        checkReferenceInstanceRevertOnReceive(referenceInstance);
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

        assertEq(reads.length, 4);
        assertEq(uint256(reads[0]), 1);
        assertEq(uint256(reads[1]), 1);
        assertEq(uint256(reads[2]), 0);
        assertEq(uint256(reads[3]), 0);

        assertEq(writes.length, 2);
        assertEq(uint256(writes[0]), 1);
        assertEq(uint256(writes[1]), 0);

        bytes32 slot0 = cheats.load(address(factory), bytes32(uint256(0)));
        assertEq(address(uint160(uint256(slot0))), deployer);

        bytes32 slot1 = cheats.load(address(factory), bytes32(uint256(1)));
        assertEq(uint256(slot1), 0);

        bytes32 slot2 = cheats.load(address(factory), bytes32(uint256(1)));
        assertEq(uint256(slot2), 0);

        bytes32 slot3 = cheats.load(address(factory), bytes32(uint256(1)));
        assertEq(uint256(slot3), 0);
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

        assertEq(reads.length, 4);
        assertEq(uint256(reads[0]), 0);
        assertEq(uint256(reads[1]), 1);
        assertEq(uint256(reads[2]), 1);
        assertEq(uint256(reads[3]), 0);

        assertEq(writes.length, 1);
        assertEq(uint256(writes[0]), 1);

        bytes32 slot0 = cheats.load(address(factory), bytes32(uint256(0)));
        assertEq(address(uint160(uint256(slot0))), deployer);

        bytes32 slot1 = cheats.load(address(factory), bytes32(uint256(1)));
        assertEq(address(uint160(uint256(slot1))), owner);

        bytes32 slot2 = cheats.load(address(factory), bytes32(uint256(2)));
        assertEq(uint256(slot2), 0);

        assertEq(factory.owner(), deployer);
        assertEq(factory.pendingOwner(), owner);
    }

    function acceptOwnership() internal {
        assertEq(factory.owner(), deployer);

        bytes32[] memory reads;
        bytes32[] memory writes;
        vm.record();

        cheats.startPrank(owner);

        factory.acceptOwnership();

        (reads, writes) = vm.accesses(
            address(factory)
        );

        assertEq(reads.length, 5);
        assertEq(uint256(reads[0]), 1);
        assertEq(uint256(reads[1]), 1);
        assertEq(uint256(reads[2]), 1);
        assertEq(uint256(reads[3]), 0);
        assertEq(uint256(reads[4]), 0);

        assertEq(writes.length, 2);
        assertEq(uint256(writes[0]), 1);
        assertEq(uint256(writes[1]), 0);

        bytes32 slot0 = cheats.load(address(factory), bytes32(uint256(0)));
        assertEq(address(uint160(uint256(slot0))), owner);

        bytes32 slot1 = cheats.load(address(factory), bytes32(uint256(1)));
        assertEq(uint256(slot1), 0);

        bytes32 slot2 = cheats.load(address(factory), bytes32(uint256(2)));
        assertEq(uint256(slot2), 0);

        assertEq(factory.owner(), owner);
        assertEq(factory.pendingOwner(), address(0));
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
        referenceInstance = new FeeDistributor(address(factory), payable(service));

        if (service == address(0) || !serviceCanReceiveEther) {
            shouldQuit = true;
            return (shouldQuit, referenceInstance);
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
        assertEq(uint256(reads[1]), 3);
        assertEq(uint256(reads[2]), 3);

        assertEq(writes.length, 1);
        assertEq(uint256(writes[0]), 3);

        bytes32 slot0 = cheats.load(address(factory), bytes32(uint256(0)));
        assertEq(address(uint160(uint256(slot0))), owner);

        bytes32 slot1 = cheats.load(address(factory), bytes32(uint256(1)));
        assertEq(uint256(slot1), 0);

        bytes32 slot2 = cheats.load(address(factory), bytes32(uint256(2)));
        assertEq(uint256(slot2), 0);

        bytes32 slot3 = cheats.load(address(factory), bytes32(uint256(3)));
        assertEq(address(uint160(uint256(slot3))), address(referenceInstance));
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
        assertEq(uint256(reads[1]), 2);
        assertEq(uint256(reads[2]), 2);
        assertEq(uint256(reads[3]), 2);

        assertEq(writes.length, 1);
        assertEq(uint256(writes[0]), 2);

        bytes32 slot0 = cheats.load(address(factory), bytes32(uint256(0)));
        assertEq(address(uint160(uint256(slot0))), owner);

        bytes32 slot1 = cheats.load(address(factory), bytes32(uint256(1)));
        assertEq(uint256(slot1), 0);

        bytes32 slot2 = cheats.load(address(factory), bytes32(uint256(2)));
        assertEq(address(uint160(uint256(slot2))), operator);

        bytes32 slot3 = cheats.load(address(factory), bytes32(uint256(3)));
        assertEq(address(uint160(uint256(slot3))), address(referenceInstance));

        bytes32 slot4 = cheats.load(address(factory), bytes32(uint256(4)));
        assertEq(uint256(slot4), 0);

        cheats.stopPrank();
        cheats.startPrank(operator);
    }

    function createFeeDistributor(
        address service,
        address client,
        uint96 clientBasisPoints,
        address referrer,
        uint96 referrerBasisPoints
    ) internal returns (bool shouldQuit, FeeDistributor clientInstanceOfFeeDistributor) {
        vm.recordLogs();
        bool clientCanReceiveEther;
        bool referrerCanReceiveEther;
        bool failedBefore;

        if (client == address(0)) {
            vm.expectRevert(FeeDistributor__ZeroAddressClient.selector);
            failedBefore = true;
        } else if (client == service) {
            vm.expectRevert(abi.encodeWithSelector(FeeDistributor__ClientAddressEqualsService.selector, client));
            failedBefore = true;
        } else if (clientBasisPoints > 10000) {
            vm.expectRevert(abi.encodeWithSelector(FeeDistributor__InvalidClientBasisPoints.selector, clientBasisPoints));
            failedBefore = true;
        } else if (referrer != address(0)) {// if there is a referrer
            if (referrer == service) {
                vm.expectRevert(abi.encodeWithSelector(FeeDistributor__ReferrerAddressEqualsService.selector, referrer));
                failedBefore = true;
            } else if (referrer == client) {
                vm.expectRevert(abi.encodeWithSelector(FeeDistributor__ReferrerAddressEqualsClient.selector, referrer));
                failedBefore = true;
            } else if (referrerBasisPoints > type(uint96).max - 10000) {
                vm.expectRevert();
                failedBefore = true;
            } else if (clientBasisPoints + referrerBasisPoints > 10000) {
                vm.expectRevert(abi.encodeWithSelector(
                    FeeDistributor__ClientPlusReferralBasisPointsExceed10000.selector,
                    clientBasisPoints,
                    referrerBasisPoints
                ));
                failedBefore = true;
            }
        } else if (referrerBasisPoints != 0) {
            vm.expectRevert(abi.encodeWithSelector(FeeDistributor__ReferrerBasisPointsMustBeZeroIfAddressIsZero.selector, referrerBasisPoints));
            failedBefore = true;
        }

        if (!failedBefore) {
            (clientCanReceiveEther, ) = payable(client).call{value: 0}("");
            if (!clientCanReceiveEther) {
                vm.expectRevert(abi.encodeWithSelector(FeeDistributor__ClientCannotReceiveEther.selector, client));
                failedBefore = true;
            }
        }

        if (!failedBefore) {
            (referrerCanReceiveEther,) = payable(referrer).call{value : 0}("");
            if (!referrerCanReceiveEther) {
                vm.expectRevert(abi.encodeWithSelector(FeeDistributor__ReferrerCannotReceiveEther.selector, referrer));
            }
        }

        // create a client instance of FeeDistributor
        factory.createFeeDistributor(
            IFeeDistributor.FeeRecipient({recipient: payable(client), basisPoints: clientBasisPoints}),
            IFeeDistributor.FeeRecipient({recipient: payable(referrer), basisPoints: referrerBasisPoints})
        );
        if (client == address(0)
            || clientBasisPoints > 10000
            || referrerBasisPoints > 10000
            || !clientCanReceiveEther
            || !referrerCanReceiveEther) {

            shouldQuit = true;
            return (shouldQuit, clientInstanceOfFeeDistributor);
        }
        Vm.Log[] memory createFeeDistributorLogs = vm.getRecordedLogs();
        assertEq(createFeeDistributorLogs.length, 2);
        assertEq(createFeeDistributorLogs[0].topics[0], keccak256("Initialized(address,uint96,address,uint96)"));
        assertEq(createFeeDistributorLogs[1].topics[0], keccak256("FeeDistributorCreated(address,address)"));

        // get the client instance of FeeDistributor from event logs
        clientInstanceOfFeeDistributor = FeeDistributor(payable(address(uint160(uint256(
            createFeeDistributorLogs[1].topics[1]
        )))));
        return (shouldQuit, clientInstanceOfFeeDistributor);
    }

    function withdraw(
        address service,
        address client,
        uint96 clientBasisPoints,
        address referrer,
        uint96 referrerBasisPoints,
        FeeDistributor clientInstanceOfFeeDistributor
    ) internal {
        cheats.stopPrank();

        uint256 totalRewards;
        {
            uint256 directRewards = 1 ether;

            // simulate generation of rewards for the client instance
            vm.deal(address(clientInstanceOfFeeDistributor), directRewards);

            uint256 fromBuilders = 2 ether;

            // send ether in a regular transaction
            vm.deal(address(this), fromBuilders);
            payable(address(clientInstanceOfFeeDistributor)).call{value: fromBuilders}("");

            totalRewards = directRewards + fromBuilders;
        }

        uint256 serviceBalanceBefore = service.balance;
        uint256 clientBalanceBefore = client.balance;
        uint256 referrerBalanceBefore = referrer.balance;

        cheats.startPrank(nobody);
        vm.recordLogs();

        // call withdraw to distribute rewards
        clientInstanceOfFeeDistributor.withdraw();

        assertEq(
            totalRewards - totalRewards * clientBasisPoints / 10000 - totalRewards * referrerBasisPoints / 10000,
            service.balance - serviceBalanceBefore
        );
        assertEq(
            totalRewards * clientBasisPoints / 10000,
            client.balance - clientBalanceBefore
        );
        assertEq(
            totalRewards * referrerBasisPoints / 10000,
            referrer.balance - referrerBalanceBefore
        );

        {
            Vm.Log[] memory withdrawLogs = vm.getRecordedLogs();
            assertEq(withdrawLogs.length, 1);
            assertEq(withdrawLogs[0].topics[0], keccak256("Withdrawn(uint256,uint256,uint256)"));

            (
                uint256 serviceRewardFromLogs,
                uint256 clientRewardFromLogs,
                uint256 referrerRewardFromLogs
            ) = abi.decode(withdrawLogs[0].data, (uint256, uint256, uint256));

            assertEq(
                totalRewards - totalRewards * clientBasisPoints / 10000 - totalRewards * referrerBasisPoints / 10000,
                serviceRewardFromLogs
            );
            assertEq(
                totalRewards * clientBasisPoints / 10000,
                clientRewardFromLogs
            );
            assertEq(
                totalRewards * referrerBasisPoints / 10000,
                referrerRewardFromLogs
            );
        }
    }

    function checkReferenceInstanceRevertOnReceive(
        FeeDistributor referenceInstance
    ) internal {
        cheats.stopPrank();
        vm.deal(address(this), 1 ether);
        vm.expectRevert(FeeDistributor__ClientNotSet.selector);
        payable(address(referenceInstance)).call{value: 1 ether}("");
    }
}
