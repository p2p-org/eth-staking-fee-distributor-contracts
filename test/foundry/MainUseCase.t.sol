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
    Vm cheats = Vm(HEVM_ADDRESS);

    address payable serviceAddress = payable(0x6Bb8b45a1C6eA816B70d76f83f7dC4f0f87365Ff);
    uint96 defaultClientBasisPoints = 9000;
    uint256 clientDepositedEth = 32000 ether;

    address clientDepositorAddress = 0xBE0eB53F46cd790Cd13851d5EFf43D12404d33E8;
    address payable clientWcAddress = payable(0x6D5a7597896A703Fe8c85775B23395a48f971305);
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

    function setUp() public {
        cheats.createSelectFork("mainnet", 17434740);

        cheats.startPrank(p2pDeployerAddress);
        oracle = new Oracle();
        factory = new FeeDistributorFactory(defaultClientBasisPoints);
        contractWcFeeDistributorTemplate = new ContractWcFeeDistributor(address(factory), serviceAddress);
        elOnlyFeeDistributorTemplate = new ElOnlyFeeDistributor(address(factory), serviceAddress);
        oracleFeeDistributorTemplate = new OracleFeeDistributor(address(oracle), address(factory), serviceAddress);
        p2pEthDepositor = new P2pOrgUnlimitedEthDepositor(true, address(factory));
        cheats.stopPrank();
    }

    function testMainUseCase() public {
        console.log("MainUseCase started");

        checkOwnership();
        setOperator();
        setOwner();
        setP2pEth2Depositor();
        addEth();

        console.log("MainUseCase finished");
    }

    function addEth() private {
        console.log("addEth");

        cheats.startPrank(clientDepositorAddress);

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
        );

        assertEq(p2pEthDepositor.totalBalance(), 1 ether);

        p2pEthDepositor.addEth{value: (clientDepositedEth - 1 ether)}(
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
    }

    function setP2pEth2Depositor() private {
        console.log("setP2pEth2Depositor");

        cheats.startPrank(extraSecureP2pAddress);

        assertTrue(factory.p2pEth2Depositor() != address(p2pEthDepositor));
        factory.setP2pEth2Depositor(address(p2pEthDepositor));
        assertTrue(factory.p2pEth2Depositor() == address(p2pEthDepositor));

        cheats.stopPrank();
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

        cheats.startPrank(p2pDeployerAddress);

        assertTrue(oracle.operator() != operatorAddress);
        oracle.changeOperator(operatorAddress);
        assertEq(oracle.operator(), operatorAddress);

        assertTrue(factory.operator() != operatorAddress);
        factory.changeOperator(operatorAddress);
        assertEq(factory.operator(), operatorAddress);

        cheats.stopPrank();
    }

    function setOwner() private {
        console.log("setOwner");

        cheats.startPrank(p2pDeployerAddress);
        assertTrue(oracle.owner() != extraSecureP2pAddress);
        oracle.transferOwnership(extraSecureP2pAddress);
        assertTrue(oracle.owner() != extraSecureP2pAddress);
        cheats.startPrank(extraSecureP2pAddress);
        oracle.acceptOwnership();
        assertEq(oracle.owner(), extraSecureP2pAddress);
        cheats.stopPrank();

        cheats.startPrank(p2pDeployerAddress);
        assertTrue(factory.owner() != extraSecureP2pAddress);
        factory.transferOwnership(extraSecureP2pAddress);
        assertTrue(factory.owner() != extraSecureP2pAddress);
        cheats.startPrank(extraSecureP2pAddress);
        factory.acceptOwnership();
        assertEq(factory.owner(), extraSecureP2pAddress);
        assertEq(contractWcFeeDistributorTemplate.owner(), extraSecureP2pAddress);
        assertEq(elOnlyFeeDistributorTemplate.owner(), extraSecureP2pAddress);
        assertEq(oracleFeeDistributorTemplate.owner(), extraSecureP2pAddress);
        cheats.stopPrank();
    }
}
