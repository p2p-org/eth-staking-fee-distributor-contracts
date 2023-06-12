// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/console2.sol";
import "../../contracts/p2pEth2Depositor/P2pOrgUnlimitedEthDepositor.sol";
import "../../contracts/feeDistributorFactory/FeeDistributorFactory.sol";
import "../../contracts/feeDistributor/ContractWcFeeDistributor.sol";
import "../../contracts/feeDistributor/ElOnlyFeeDistributor.sol";
import "../../contracts/feeDistributor/OracleFeeDistributor.sol";
import "../../contracts/oracle/Oracle.sol";
import "../../contracts/structs/P2pStructs.sol";

contract MainUseCase is Test {
    bytes pubKey;
    bytes signature;
    bytes32 depositDataRoot;

    bytes[] pubKeys;
    bytes[] signatures;
    bytes32[] depositDataRoots;

    address payable serviceAddress = payable(0x6Bb8b45a1C6eA816B70d76f83f7dC4f0f87365Ff);
    uint96 defaultClientBasisPoints = 9000;
    uint256 clientDepositedEth = 32000 ether;

    address clientDepositorAddress = 0xBE0eB53F46cd790Cd13851d5EFf43D12404d33E8;
    address payable clientWcAddress = payable(0xB3E84B6C6409826DC45432B655D8C9489A14A0D7);
    address p2pDeployerAddress = 0x5a52E96BAcdaBb82fd05763E25335261B270Efcb;
    address operatorAddress = 0xDc251802dCAF9a44409a254c04Fc19d22EDa36e2;
    address extraSecureP2pAddress = 0xb0d0f9e74e15345D9E618C6f4Ca1C9Cb061C613A;
    address beaconDepositContractAddress = 0x00000000219ab540356cBB839Cbe05303d7705Fa;

    P2pOrgUnlimitedEthDepositor p2pEthDepositor;
    FeeDistributorFactory factory;
    ContractWcFeeDistributor contractWcFeeDistributorTemplate;
    ElOnlyFeeDistributor elOnlyFeeDistributorTemplate;
    OracleFeeDistributor oracleFeeDistributorTemplate;
    Oracle oracle;

    ContractWcFeeDistributor contractWcFeeDistributorInstance;
    ElOnlyFeeDistributor elFeeDistributorInstance;
    OracleFeeDistributor oracleFeeDistributorInstance;

    function setUp() public {
        vm.createSelectFork("mainnet", 17434740);

        pubKey = bytes(hex'87f08e27a19e0d15764838e3af5c33645545610f268c2dadba3c2c789e2579a5d5300a3d72c6fb5fce4e9aa1c2f32d40');
        signature = bytes(hex'816597afd6c13068692512ed57e7c6facde10be01b247c58d67f15e3716ec7eb9856d28e25e1375ab526b098fdd3094405435a9bf7bf95369697365536cb904f0ae4f8da07f830ae1892182e318588ce8dd6220be2145f6c29d28e0d57040d42');
        depositDataRoot = bytes32(hex'34b7017543befa837eb0af8a32b2c6e543b1d869ff526680c9d59291b742d5b7');

        for (uint256 i = 0; i < VALIDATORS_MAX_AMOUNT; i++) {
            pubKeys.push(pubKey);
            signatures.push(signature);
            depositDataRoots.push(depositDataRoot);
        }

        vm.startPrank(p2pDeployerAddress);
        oracle = new Oracle();
        factory = new FeeDistributorFactory(defaultClientBasisPoints);
        contractWcFeeDistributorTemplate = new ContractWcFeeDistributor(address(factory), serviceAddress);
        elOnlyFeeDistributorTemplate = new ElOnlyFeeDistributor(address(factory), serviceAddress);
        oracleFeeDistributorTemplate = new OracleFeeDistributor(address(oracle), address(factory), serviceAddress);
        p2pEthDepositor = new P2pOrgUnlimitedEthDepositor(true, address(factory));
        vm.stopPrank();
    }

    function testMainUseCase() public {
        console.log("MainUseCase started");

        checkOwnership();
        setOperator();
        setOwner();
        setP2pEth2Depositor();
        addEthToElFeeDistributor({callNumber: 1});
        refund();
        addEthToElFeeDistributor({callNumber: 2});
        makeBeaconDeposit();
        withdrawElFeeDistributor();
        addEthToOracleFeeDistributor();
        addEthToContractWcFeeDistributor();

        console.log("MainUseCase finished");
    }

    function withdrawElFeeDistributor() private {
        vm.deal(address(elFeeDistributorInstance), 10 ether);

        uint256 serviceBalanceBefore = serviceAddress.balance;
        uint256 clientBalanceBefore = clientWcAddress.balance;

        elFeeDistributorInstance.withdraw();

        uint256 serviceBalanceAfter = serviceAddress.balance;
        uint256 clientBalanceAfter = clientWcAddress.balance;

        assertEq(serviceBalanceAfter - serviceBalanceBefore, 1 ether);
        assertEq(clientBalanceAfter - clientBalanceBefore, 9 ether);
    }

    function makeBeaconDeposit() private {
        console.log("makeBeaconDeposit");

        vm.expectRevert(abi.encodeWithSelector(Access__AddressNeitherOperatorNorOwner.selector, address(this), operatorAddress, extraSecureP2pAddress));
        p2pEthDepositor.makeBeaconDeposit(
            address(elFeeDistributorInstance),
            pubKeys,
            signatures,
            depositDataRoots
        );

        vm.startPrank(operatorAddress);

        assertEq(p2pEthDepositor.totalBalance(), clientDepositedEth);
        assertEq(p2pEthDepositor.depositAmount(address(elFeeDistributorInstance)), clientDepositedEth);

        p2pEthDepositor.makeBeaconDeposit(
            address(elFeeDistributorInstance),
            pubKeys,
            signatures,
            depositDataRoots
        );

        uint256 balanceAfter = clientDepositedEth - COLLATERAL * VALIDATORS_MAX_AMOUNT;
        assertEq(p2pEthDepositor.totalBalance(), balanceAfter);
        assertEq(p2pEthDepositor.depositAmount(address(elFeeDistributorInstance)), balanceAfter);

        vm.stopPrank();
    }

    function refund() private {
        console.log("refund");

        vm.startPrank(clientWcAddress);

        assertEq(p2pEthDepositor.totalBalance(), clientDepositedEth);
        assertEq(p2pEthDepositor.depositAmount(address(elFeeDistributorInstance)), clientDepositedEth);

        vm.expectRevert(abi.encodeWithSelector(P2pOrgUnlimitedEthDepositor__WaitForExpiration.selector, block.timestamp + TIMEOUT, block.timestamp));
        p2pEthDepositor.refund(address(elFeeDistributorInstance));

        vm.warp(block.timestamp + TIMEOUT + 1);

        assertEq(p2pEthDepositor.totalBalance(), clientDepositedEth);
        assertEq(p2pEthDepositor.depositAmount(address(elFeeDistributorInstance)), clientDepositedEth);

        p2pEthDepositor.refund(address(elFeeDistributorInstance));

        assertEq(p2pEthDepositor.totalBalance(), 0);
        assertEq(p2pEthDepositor.depositAmount(address(elFeeDistributorInstance)), 0);

        vm.stopPrank();
    }

    function addEthToElFeeDistributor(uint256 callNumber) private {
        console.log("addEthToElFeeDistributor #", callNumber);

        vm.startPrank(clientDepositorAddress);

        if (callNumber == 1) {
            assertTrue(address(elFeeDistributorInstance) == address(0));
        }

        elFeeDistributorInstance = ElOnlyFeeDistributor(payable(
            p2pEthDepositor.addEth{value: 1 ether}(
                address(elOnlyFeeDistributorTemplate),
                FeeRecipient({
                    recipient: clientWcAddress,
                    basisPoints: defaultClientBasisPoints
                }),
                FeeRecipient({
                    recipient: payable(address(0)),
                    basisPoints: 0
                })
        )));

        assertTrue(address(elFeeDistributorInstance) != address(0));
        assertEq(p2pEthDepositor.totalBalance(), 1 ether);

        address newElFeeDistributorInstanceAddress = p2pEthDepositor.addEth{value: (clientDepositedEth - 1 ether)}(
            address(elOnlyFeeDistributorTemplate),
            FeeRecipient({
                recipient: clientWcAddress,
                basisPoints: defaultClientBasisPoints
            }),
            FeeRecipient({
                recipient: payable(address(0)),
                basisPoints: 0
            })
        );

        assertEq(p2pEthDepositor.totalBalance(), clientDepositedEth);
        assertEq(newElFeeDistributorInstanceAddress, address(elFeeDistributorInstance));

        vm.stopPrank();
    }

    function addEthToOracleFeeDistributor() private {
        console.log("addEthToOracleFeeDistributor");

        vm.startPrank(clientDepositorAddress);

        assertTrue(address(oracleFeeDistributorInstance) == address(0));

        uint256 totalBalanceBefore = p2pEthDepositor.totalBalance();

        oracleFeeDistributorInstance = OracleFeeDistributor(payable(
        p2pEthDepositor.addEth{value: (clientDepositedEth)}(
            address(oracleFeeDistributorTemplate),
            FeeRecipient({
                recipient: clientWcAddress,
                basisPoints: defaultClientBasisPoints
            }),
            FeeRecipient({
                recipient: payable(address(0)),
                basisPoints: 0
            })
        )));

        uint256 totalBalanceAfter = p2pEthDepositor.totalBalance();

        assertTrue(address(oracleFeeDistributorInstance) != address(0));
        assertEq(totalBalanceAfter - totalBalanceBefore, clientDepositedEth);

        vm.stopPrank();
    }

    function addEthToContractWcFeeDistributor() private {
        console.log("addEthToContractWcFeeDistributor");

        vm.startPrank(clientDepositorAddress);

        assertTrue(address(contractWcFeeDistributorInstance) == address(0));

        uint256 totalBalanceBefore = p2pEthDepositor.totalBalance();

        contractWcFeeDistributorInstance = ContractWcFeeDistributor(payable(
                p2pEthDepositor.addEth{value: (clientDepositedEth)}(
                    address(contractWcFeeDistributorTemplate),
                    FeeRecipient({
                recipient: clientWcAddress,
                basisPoints: defaultClientBasisPoints
                }),
                    FeeRecipient({
                recipient: payable(address(0)),
                basisPoints: 0
                })
                )));

        uint256 totalBalanceAfter = p2pEthDepositor.totalBalance();

        assertTrue(address(contractWcFeeDistributorInstance) != address(0));
        assertEq(totalBalanceAfter - totalBalanceBefore, clientDepositedEth);

        vm.stopPrank();
    }

    function setP2pEth2Depositor() private {
        console.log("setP2pEth2Depositor");

        vm.startPrank(extraSecureP2pAddress);

        assertTrue(factory.p2pEth2Depositor() != address(p2pEthDepositor));
        factory.setP2pEth2Depositor(address(p2pEthDepositor));
        assertTrue(factory.p2pEth2Depositor() == address(p2pEthDepositor));

        vm.stopPrank();
    }

    function checkOwnership() private {
        console.log("checkOwnership");

        assertEq(oracle.owner(), p2pDeployerAddress);
        assertEq(factory.owner(), p2pDeployerAddress);
        assertEq(contractWcFeeDistributorTemplate.owner(), p2pDeployerAddress);
        assertEq(elOnlyFeeDistributorTemplate.owner(), p2pDeployerAddress);
        assertEq(oracleFeeDistributorTemplate.owner(), p2pDeployerAddress);
    }

    function setOperator() private {
        console.log("setOperator");

        vm.startPrank(p2pDeployerAddress);

        assertTrue(oracle.operator() != operatorAddress);
        oracle.changeOperator(operatorAddress);
        assertEq(oracle.operator(), operatorAddress);

        assertTrue(factory.operator() != operatorAddress);
        factory.changeOperator(operatorAddress);
        assertEq(factory.operator(), operatorAddress);

        vm.stopPrank();
    }

    function setOwner() private {
        console.log("setOwner");

        vm.startPrank(p2pDeployerAddress);
        assertTrue(oracle.owner() != extraSecureP2pAddress);
        oracle.transferOwnership(extraSecureP2pAddress);
        assertTrue(oracle.owner() != extraSecureP2pAddress);
        vm.startPrank(extraSecureP2pAddress);
        oracle.acceptOwnership();
        assertEq(oracle.owner(), extraSecureP2pAddress);
        vm.stopPrank();

        vm.startPrank(p2pDeployerAddress);
        assertTrue(factory.owner() != extraSecureP2pAddress);
        factory.transferOwnership(extraSecureP2pAddress);
        assertTrue(factory.owner() != extraSecureP2pAddress);
        vm.startPrank(extraSecureP2pAddress);
        factory.acceptOwnership();
        assertEq(factory.owner(), extraSecureP2pAddress);
        assertEq(contractWcFeeDistributorTemplate.owner(), extraSecureP2pAddress);
        assertEq(elOnlyFeeDistributorTemplate.owner(), extraSecureP2pAddress);
        assertEq(oracleFeeDistributorTemplate.owner(), extraSecureP2pAddress);
        vm.stopPrank();
    }
}
