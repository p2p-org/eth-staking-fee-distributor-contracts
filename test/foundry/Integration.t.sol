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
import "../../contracts/mocks/MockClientFeeDistributor.sol";
import "../../contracts/mocks/IEntryPoint.sol";
import "../../contracts/erc4337/UserOperation.sol";
import "../../contracts/mocks/MockAlteringReceive.sol";

contract Integration is Test {
    using ECDSA for bytes32;

    bytes pubKey;
    bytes signature;
    bytes32 depositDataRoot;

    bytes[] pubKeys;
    bytes[] signatures;
    bytes32[] depositDataRoots;

    bytes[] pubKeysForContractWc;
    bytes[] signaturesForContractWc;
    bytes32[] depositDataRootsForContractWc;

    bytes[] pubKeysForZeroAddressWc;
    bytes[] signaturesForZeroAddressWc;
    bytes32[] depositDataRootsForZeroAddressWc;

    address payable constant serviceAddress = payable(0x6Bb8b45a1C6eA816B70d76f83f7dC4f0f87365Ff);
    uint96 constant defaultClientBasisPoints = 9000;
    uint256 constant clientDepositedEth = 32000 ether;

    bytes32 merkleRoot;
    bytes32[] merkleProof;
    uint256 constant amountInGweiFromOracle = 20 gwei; //

    uint256 operatorPrivateKey = 42; // needed for signature
    address payable bundler = payable(address(100500));
    address constant clientDepositorAddress = 0xBE0eB53F46cd790Cd13851d5EFf43D12404d33E8;
    address payable constant clientWcAddress = payable(0xB3E84B6C6409826DC45432B655D8C9489A14A0D7);
    address constant p2pDeployerAddress = 0x5a52E96BAcdaBb82fd05763E25335261B270Efcb;
    address operatorAddress;
    address constant extraSecureP2pAddress = 0xb0d0f9e74e15345D9E618C6f4Ca1C9Cb061C613A;
    address constant beaconDepositContractAddress = 0x00000000219ab540356cBB839Cbe05303d7705Fa;
    address payable constant entryPointAddress = payable(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);

    IEntryPoint entryPoint;
    P2pOrgUnlimitedEthDepositor p2pEthDepositor;
    FeeDistributorFactory factory;
    Oracle oracle;

    ContractWcFeeDistributor contractWcFeeDistributorTemplate;
    ElOnlyFeeDistributor elOnlyFeeDistributorTemplate;
    OracleFeeDistributor oracleFeeDistributorTemplate;
    MockClientFeeDistributor customFeeDistributorTemplate;

    // predictable due to CREATE2
    address constant contractWcFeeDistributorInstanceAddress = 0x1A11782051858A95266109DaED1576eD28e48393;
    address constant elFeeDistributorInstanceAddress = 0x2ead271163a1b59346879452228250c1114dE3b8;
    address constant oracleFeeDistributorInstanceAddress = 0x4b08827F4a9a56bdE2D93a28DcDd7db066AdA23D;
    address constant customFeeDistributorInstanceAddress = 0x2F3B0cde60F8885809B2F347b99d54315ae716A3;

    ContractWcFeeDistributor contractWcFeeDistributorInstance;
    ElOnlyFeeDistributor elFeeDistributorInstance;
    OracleFeeDistributor oracleFeeDistributorInstance;
    MockClientFeeDistributor customFeeDistributorInstance;

    function setUp() public {
        vm.createSelectFork("mainnet", 17434740);

        entryPoint = IEntryPoint(entryPointAddress);
        operatorAddress = vm.addr(operatorPrivateKey);
        vm.deal(operatorAddress, 42 ether);

        merkleRoot = bytes32(hex'86832f5c3d135fccdea12889e7c4f7820727285c5b8d18a29c5589d203cfd8a4');
        merkleProof.push(hex'889ef4a2d6b0f2788dc17d863eb2448ab11ede0cc997e21ea48120b6426418ed');
        merkleProof.push(hex'a2d2d9599717e5e4d3e14d43cfd1d2cdf6befc8d91af26a12c7bad79e308050f');

        pubKey = bytes(hex'87f08e27a19e0d15764838e3af5c33645545610f268c2dadba3c2c789e2579a5d5300a3d72c6fb5fce4e9aa1c2f32d40');
        signature = bytes(hex'816597afd6c13068692512ed57e7c6facde10be01b247c58d67f15e3716ec7eb9856d28e25e1375ab526b098fdd3094405435a9bf7bf95369697365536cb904f0ae4f8da07f830ae1892182e318588ce8dd6220be2145f6c29d28e0d57040d42');
        depositDataRoot = bytes32(hex'34b7017543befa837eb0af8a32b2c6e543b1d869ff526680c9d59291b742d5b7');

        for (uint256 i = 0; i < VALIDATORS_MAX_AMOUNT; i++) {
            pubKeys.push(pubKey);
            signatures.push(signature);
            depositDataRoots.push(depositDataRoot);

            pubKeysForContractWc.push(bytes(hex'8ac881a1fe216fa252f63ef3967484cbd89396de26d7908f82c3ac895d92fe44adaefbe914c6ca3d0f8eb0f37acf4771'));
            signaturesForContractWc.push(bytes(hex'964b3a3913d001a524af456437f78b2eb5f7c2b30e7cee08cd3283019aefb1dee72ecca1a4d4da7c7602bc5ea5afe85510f7f45dab312c7243a61482908900b1ded150d64a3afdcab2a18f8b091f579aecded6a108e6060a62c636d8ea1dc36b'));
            depositDataRootsForContractWc.push(bytes32(hex'a45088a6edc1d3731bfbe77069a15c6f82cafec3deca39e35b770a951173dd30'));

            pubKeysForZeroAddressWc.push(bytes(hex'b1c9ac4f20bca70faf03d1afa308912073753d3f7a54aa205604f411feacf26243bcf5119fcbf2ebde1b34327c80506b'));
            signaturesForZeroAddressWc.push(bytes(hex'adfdd15ae10ecd6d53f5d66b6344542ee1195fa128bd20025136eb2e828fe787ec8244510561d833153dfa47367c32d601a9ddd31494daa8926cb596e5490df3dcfdc719e09c18d9fb3e2d059769433fa2b72de1b59e0416376b60edf2af7c8d'));
            depositDataRootsForZeroAddressWc.push(bytes32(hex'11ac2aa82040395c3ee36e21486d58820dae708cf7359c06b44c8975f7b7cf98'));
        }

        vm.startPrank(p2pDeployerAddress);
        oracle = new Oracle();
        factory = new FeeDistributorFactory(defaultClientBasisPoints);
        contractWcFeeDistributorTemplate = new ContractWcFeeDistributor(address(factory), serviceAddress);
        elOnlyFeeDistributorTemplate = new ElOnlyFeeDistributor(address(factory), serviceAddress);
        oracleFeeDistributorTemplate = new OracleFeeDistributor(address(oracle), address(factory), serviceAddress);
        p2pEthDepositor = new P2pOrgUnlimitedEthDepositor(address(factory));
        vm.stopPrank();

        checkOwnership();
        setOperator();
        setOwner();
        setP2pEth2Depositor();
    }

    function test_Main_Use_Case() public {
        console.log("MainUseCase started");

        addEthToElFeeDistributor({callNumber: 1});
        refund();

        addEthToElFeeDistributor({callNumber: 2});
        makeBeaconDepositForElFeeDistributor();
        withdrawElFeeDistributor();

        addEthToOracleFeeDistributor();
        addEthToContractWcFeeDistributor();

        makeBeaconDepositForOracleFeeDistributor();
        makeBeaconDepositForContractWcFeeDistributor();

        withdrawOracleFeeDistributor({clientOnlyClRewards: 0});
        withdrawContractWcFeeDistributor();

        console.log("MainUseCase finished");
    }

    function test_ERC_4337_Withdraw_ContractWcFeeDistributor() public {
        console.log("testErc4337WithdrawContractWcFeeDistributor started");

        addEthToContractWcFeeDistributor();
        makeBeaconDepositForContractWcFeeDistributor();

        vm.startPrank(extraSecureP2pAddress);
        contractWcFeeDistributorInstance.changeOperator(operatorAddress);
        vm.stopPrank();

        uint256 rewards = 1 ether;

        vm.deal(address(contractWcFeeDistributorInstance), rewards);

        UserOperation memory userOp = getUserOperationWithoutSignature(Erc4337Account(contractWcFeeDistributorInstance));
        UserOperation[] memory ops = getOps(userOp);

        uint256 beneficiaryBalanceBefore = bundler.balance;
        uint256 serviceBalanceBefore = serviceAddress.balance;
        uint256 clientBalanceBefore = clientWcAddress.balance;

        entryPoint.handleOps(ops, bundler);

        uint256 beneficiaryBalanceAfter = bundler.balance;
        uint256 serviceBalanceAfter = serviceAddress.balance;
        uint256 clientBalanceAfter = clientWcAddress.balance;

        assertGt((serviceBalanceAfter - serviceBalanceBefore), rewards * (10000 - defaultClientBasisPoints) / 10000 * 98 / 100); // >98%
        assertGt((clientBalanceAfter - clientBalanceBefore), rewards * defaultClientBasisPoints / 10000 * 98 / 100); // >98%
        assertLt((beneficiaryBalanceAfter - beneficiaryBalanceBefore), rewards * defaultClientBasisPoints / 10000 * 2 / 100);

        console.log("testErc4337WithdrawContractWcFeeDistributor finished");
    }

    function test_ERC_4337_Withdraw_ElOnlyFeeDistributor() public {
        console.log("testErc4337WithdrawElOnlyFeeDistributor started");

        addEthToElFeeDistributor(1);
        makeBeaconDepositForElFeeDistributor();

        vm.startPrank(extraSecureP2pAddress);
        elFeeDistributorInstance.changeOperator(operatorAddress);
        vm.stopPrank();

        uint256 rewards = 1 ether;

        vm.deal(address(elFeeDistributorInstance), rewards);

        UserOperation memory userOp = getUserOperationWithoutSignature(Erc4337Account(elFeeDistributorInstance));
        UserOperation[] memory ops = getOps(userOp);

        uint256 beneficiaryBalanceBefore = bundler.balance;
        uint256 serviceBalanceBefore = serviceAddress.balance;
        uint256 clientBalanceBefore = clientWcAddress.balance;

        entryPoint.handleOps(ops, bundler);

        uint256 beneficiaryBalanceAfter = bundler.balance;
        uint256 serviceBalanceAfter = serviceAddress.balance;
        uint256 clientBalanceAfter = clientWcAddress.balance;

        assertGt((serviceBalanceAfter - serviceBalanceBefore), rewards * (10000 - defaultClientBasisPoints) / 10000 * 98 / 100); // >98%
        assertGt((clientBalanceAfter - clientBalanceBefore), rewards * defaultClientBasisPoints / 10000 * 98 / 100); // >98%
        assertLt((beneficiaryBalanceAfter - beneficiaryBalanceBefore), rewards * defaultClientBasisPoints / 10000 * 2 / 100);

        console.log("testErc4337WithdrawElOnlyFeeDistributor finished");
    }

    function test_ERC_4337_Withdraw_OracleFeeDistributor() public {
        console.log("testErc4337WithdrawOracleFeeDistributor started");

        addEthToOracleFeeDistributor();
        makeBeaconDepositForOracleFeeDistributor();

        vm.startPrank(extraSecureP2pAddress);
        oracleFeeDistributorInstance.changeOperator(operatorAddress);
        vm.stopPrank();

        uint256 elRewards = 10 ether;
        vm.deal(address(oracleFeeDistributorInstance), elRewards);

        vm.startPrank(operatorAddress);
        oracle.report(merkleRoot);
        vm.stopPrank();

        UserOperation memory userOp = getUserOperationWithoutSignatureForOracleFeeDistributor(
            oracleFeeDistributorInstance,
            merkleProof,
            amountInGweiFromOracle
        );
        UserOperation[] memory ops = getOps(userOp);

        uint256 serviceBalanceBefore = serviceAddress.balance;
        uint256 clientBalanceBefore = clientWcAddress.balance;
        uint256 beneficiaryBalanceBefore = bundler.balance;

        entryPoint.handleOps(ops, bundler);

        uint256 serviceBalanceAfter = serviceAddress.balance;
        uint256 clientBalanceAfter = clientWcAddress.balance;
        uint256 beneficiaryBalanceAfter = bundler.balance;

        uint256 clRewards = amountInGweiFromOracle * 1 gwei;
        uint256 totalRewards = clRewards + elRewards;

        assertGt(serviceBalanceAfter - serviceBalanceBefore, totalRewards * (10000 - defaultClientBasisPoints) / 10000 * 98 / 100); // >98%
        assertGt(clientBalanceAfter - clientBalanceBefore, (totalRewards * defaultClientBasisPoints / 10000 - clRewards) * 98 / 100); // >98%
        assertLt((beneficiaryBalanceAfter - beneficiaryBalanceBefore), totalRewards * defaultClientBasisPoints / 10000 * 2 / 100);

        console.log("testErc4337WithdrawOracleFeeDistributor finished");
    }

    function getOps(UserOperation memory userOpWithoutSignature) private returns(UserOperation[] memory) {
        bytes32 userOpHash = entryPoint.getUserOpHash(userOpWithoutSignature);
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(operatorPrivateKey, hash);
        userOpWithoutSignature.signature = abi.encodePacked(r, s, v);
        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = userOpWithoutSignature;
        return ops;
    }

    function getUserOperationWithoutSignature(Erc4337Account sender) private pure returns(UserOperation memory) {
        return UserOperation({
            sender: address(sender),
            nonce: 0,
            initCode: bytes(""),
            callData: abi.encodeWithSelector(sender.withdrawSelector()),
            callGasLimit: 100000,
            verificationGasLimit: 100000,
            preVerificationGas: 100000,
            maxFeePerGas: 50 gwei,
            maxPriorityFeePerGas: 0,
            paymasterAndData: bytes(""),
            signature: bytes("")
        });
    }

    function getUserOperationWithoutSignatureForOracleFeeDistributor(
        OracleFeeDistributor sender,
        bytes32[] memory _proof,
        uint256 _amountInGwei
    ) private pure returns(UserOperation memory) {
        return UserOperation({
        sender: address(sender),
        nonce: 0,
        initCode: bytes(""),
        callData: abi.encodeWithSelector(sender.withdrawSelector(), _proof, _amountInGwei),
        callGasLimit: 100000,
        verificationGasLimit: 100000,
        preVerificationGas: 100000,
        maxFeePerGas: 50 gwei,
        maxPriorityFeePerGas: 0,
        paymasterAndData: bytes(""),
        signature: bytes("")
        });
    }

    function test_ContractWcFeeDistributor_Voluntary_Exit() public {
        console.log("testContractWcFeeDistributorVoluntaryExit started");

        addEthToContractWcFeeDistributor();
        makeBeaconDepositForContractWcFeeDistributor();

        vm.expectRevert(abi.encodeWithSelector(FeeDistributor__CallerNotClient.selector, address(this), clientWcAddress));
        contractWcFeeDistributorInstance.voluntaryExit(pubKeysForContractWc);

        vm.startPrank(clientWcAddress);
        contractWcFeeDistributorInstance.voluntaryExit(pubKeysForContractWc);
        vm.stopPrank();

        withdrawContractWcFeeDistributorAfterVoluntaryExit();

        console.log("testContractWcFeeDistributorVoluntaryExit finished");
    }

    function test_Custom_Client_FeeDistributor() public {
        console.log("testCustomClientFeeDistributor started");

        addEthToCustomFeeDistributor();
        makeBeaconDepositForCustomFeeDistributor();

        console.log("testCustomClientFeeDistributor finished");
    }

    function test_Clients_stopping_and_starting_again_receiving_collaterals() public {
        console.log("test_Clients_stopping_and_starting_again_receiving_collaterals started");

        MockAlteringReceive mockAlteringReceive = new MockAlteringReceive();
        address payable mockAlteringReceiveAddress = payable(address(mockAlteringReceive));

        vm.startPrank(operatorAddress);
        address newFeeDistributorAddress = factory.createFeeDistributor(
            address(contractWcFeeDistributorTemplate),
            FeeRecipient({
                recipient: mockAlteringReceiveAddress,
                basisPoints: defaultClientBasisPoints
            }),
            FeeRecipient({
                recipient: payable(address(0)),
                basisPoints: 0
            })
        );
        vm.stopPrank();

        contractWcFeeDistributorInstance = ContractWcFeeDistributor(payable(newFeeDistributorAddress));

        vm.startPrank(operatorAddress);
        contractWcFeeDistributorInstance.increaseDepositedCount(1);
        vm.stopPrank();

        bytes[] memory dummyPubKeys = new bytes[](1);
        dummyPubKeys[0] = "test";
        vm.startPrank(mockAlteringReceiveAddress);
        contractWcFeeDistributorInstance.voluntaryExit(dummyPubKeys);
        vm.stopPrank();

        uint256 serviceBalanceBefore = serviceAddress.balance;
        uint256 clientBalanceBefore = mockAlteringReceiveAddress.balance;

        vm.deal(address(contractWcFeeDistributorInstance), COLLATERAL);
        mockAlteringReceive.startRevertingOnReceive();
        contractWcFeeDistributorInstance.withdraw();

        uint256 serviceBalanceAfter = serviceAddress.balance;
        uint256 clientBalanceAfter = mockAlteringReceiveAddress.balance;

        assertEq(
            serviceBalanceAfter - serviceBalanceBefore,
            0
        );
        assertEq(
            clientBalanceAfter - clientBalanceBefore,
            0
        );

        mockAlteringReceive.stopRevertingOnReceive();
        contractWcFeeDistributorInstance.withdraw();

        serviceBalanceAfter = serviceAddress.balance;
        clientBalanceAfter = mockAlteringReceiveAddress.balance;

        assertEq(
            serviceBalanceAfter - serviceBalanceBefore,
            0
        );
        assertEq(
            clientBalanceAfter - clientBalanceBefore,
            COLLATERAL
        );

        console.log("test_Clients_stopping_and_starting_again_receiving_collaterals finished");
    }

    function test_Clients_stopping_receiving_collaterals_cooldown() public {
        console.log("test_Clients_stopping_receiving_collaterals_cooldown started");

        MockAlteringReceive mockAlteringReceive = new MockAlteringReceive();
        address payable mockAlteringReceiveAddress = payable(address(mockAlteringReceive));

        vm.startPrank(operatorAddress);
        address newFeeDistributorAddress = factory.createFeeDistributor(
            address(contractWcFeeDistributorTemplate),
            FeeRecipient({
        recipient: mockAlteringReceiveAddress,
        basisPoints: defaultClientBasisPoints
        }),
            FeeRecipient({
        recipient: payable(address(0)),
        basisPoints: 0
        })
        );
        vm.stopPrank();

        contractWcFeeDistributorInstance = ContractWcFeeDistributor(payable(newFeeDistributorAddress));

        vm.startPrank(operatorAddress);
        contractWcFeeDistributorInstance.increaseDepositedCount(1);
        vm.stopPrank();

        bytes[] memory dummyPubKeys = new bytes[](1);
        dummyPubKeys[0] = "test";
        vm.startPrank(mockAlteringReceiveAddress);
        contractWcFeeDistributorInstance.voluntaryExit(dummyPubKeys);
        vm.stopPrank();

        uint256 serviceBalanceBefore = serviceAddress.balance;
        uint256 clientBalanceBefore = mockAlteringReceiveAddress.balance;

        vm.deal(address(contractWcFeeDistributorInstance), COLLATERAL);
        mockAlteringReceive.startRevertingOnReceive();
        contractWcFeeDistributorInstance.withdraw();

        uint256 serviceBalanceAfter = serviceAddress.balance;
        uint256 clientBalanceAfter = mockAlteringReceiveAddress.balance;

        assertEq(
            serviceBalanceAfter - serviceBalanceBefore,
            0
        );
        assertEq(
            clientBalanceAfter - clientBalanceBefore,
            0
        );

        vm.warp(block.timestamp + COOLDOWN + 1);
        contractWcFeeDistributorInstance.withdraw();

        serviceBalanceAfter = serviceAddress.balance;
        clientBalanceAfter = mockAlteringReceiveAddress.balance;

        assertEq(
            serviceBalanceAfter - serviceBalanceBefore,
            COLLATERAL * (10000 - defaultClientBasisPoints) / 10000
        );
        assertEq(
            clientBalanceAfter - clientBalanceBefore,
            0
        );

        console.log("test_Clients_stopping_receiving_collaterals_cooldown finished");
    }

    function test_Null_basis_points_will_lead_to_the_lock_of_funds() public {
        console.log("test_Null_basis_points_will_lead_to_the_lock_of_funds started");

        uint256 deposit = 1 ether;

        vm.startPrank(clientDepositorAddress);
        elFeeDistributorInstance = ElOnlyFeeDistributor(payable(
            p2pEthDepositor.addEth{value: deposit}(
                address(elOnlyFeeDistributorTemplate),
                FeeRecipient({
                    recipient: clientWcAddress,
                    basisPoints: 0
                }),
                FeeRecipient({
                    recipient: payable(address(0)),
                    basisPoints: 0
                })
        )));
        vm.stopPrank();

        uint256 depositAmount = p2pEthDepositor.depositAmount(address(elFeeDistributorInstance));
        assertEq(depositAmount, deposit);

        vm.startPrank(clientWcAddress);
        vm.warp(block.timestamp + TIMEOUT + 1);
        uint256 clientWcAddressBalanceBefore = clientWcAddress.balance;

        p2pEthDepositor.refund(address(elFeeDistributorInstance));

        vm.stopPrank();
        uint256 clientWcAddressBalanceAfter = clientWcAddress.balance;

        assertEq(clientWcAddressBalanceAfter - clientWcAddressBalanceBefore, deposit);
        uint256 depositAmountAfterRefund = p2pEthDepositor.depositAmount(address(elFeeDistributorInstance));
        assertEq(depositAmountAfterRefund, 0);

        console.log("test_Null_basis_points_will_lead_to_the_lock_of_funds finished");
    }

    function test_OracleFeeDistributor_withdraw_after_emergencyEtherRecoveryWithoutOracleData() public {
        console.log("test_OracleFeeDistributor_withdraw_after_emergencyEtherRecoveryWithoutOracleData started");

        address newFeeDistributorAddress = deployOracleFeeDistributorCreationWithoutDepositor();
        oracleFeeDistributorInstance = OracleFeeDistributor(payable(newFeeDistributorAddress));

        uint256 elRewards = 6 ether;
        vm.deal(address(oracleFeeDistributorInstance), elRewards);

        uint256 serviceBalanceBefore = serviceAddress.balance;
        uint256 clientBalanceBefore = clientWcAddress.balance;

        vm.startPrank(clientWcAddress);
        oracleFeeDistributorInstance.emergencyEtherRecoveryWithoutOracleData();
        vm.stopPrank();

        uint256 serviceBalanceAfter = serviceAddress.balance;
        uint256 clientBalanceAfter = clientWcAddress.balance;

        assertEq(
            serviceBalanceAfter - serviceBalanceBefore,
                elRewards / 2
        );
        assertEq(
            clientBalanceAfter - clientBalanceBefore,
                elRewards / 2
        );

        vm.startPrank(operatorAddress);
        oracle.report(merkleRoot);
        vm.stopPrank();

        elRewards = 5 ether;
        vm.deal(address(oracleFeeDistributorInstance), elRewards);

        vm.expectRevert(OracleFeeDistributor__WaitForEnoughRewardsToWithdraw.selector);
        oracleFeeDistributorInstance.withdraw(merkleProof, amountInGweiFromOracle);

        console.log("test_OracleFeeDistributor_withdraw_after_emergencyEtherRecoveryWithoutOracleData finished");
    }

    function test_OracleFeeDistributor_withdraw_with_the_same_proof() public {
        console.log("test_OracleFeeDistributor_withdraw_with_the_same_proof started");

        address newFeeDistributorAddress = deployOracleFeeDistributorCreationWithoutDepositor();
        oracleFeeDistributorInstance = OracleFeeDistributor(payable(newFeeDistributorAddress));

        uint256 elRewards = 10 ether;
        vm.deal(address(oracleFeeDistributorInstance), elRewards);

        vm.startPrank(operatorAddress);
        oracle.report(merkleRoot);
        vm.stopPrank();

        uint256 serviceBalanceBefore = serviceAddress.balance;
        uint256 clientBalanceBefore = clientWcAddress.balance;

        oracleFeeDistributorInstance.withdraw(merkleProof, amountInGweiFromOracle);

        uint256 serviceBalanceAfter = serviceAddress.balance;
        uint256 clientBalanceAfter = clientWcAddress.balance;

        uint256 clRewards = amountInGweiFromOracle * 1 gwei;
        uint256 totalRewards = clRewards + elRewards;

        assertEq(
            serviceBalanceAfter - serviceBalanceBefore,
            totalRewards * (10000 - defaultClientBasisPoints) / 10000
        );
        assertEq(
            clientBalanceAfter - clientBalanceBefore,
            totalRewards * defaultClientBasisPoints / 10000 - clRewards
        );

        vm.deal(address(oracleFeeDistributorInstance), elRewards); // add more elRewards

        serviceBalanceBefore = serviceAddress.balance;
        clientBalanceBefore = clientWcAddress.balance;

        oracleFeeDistributorInstance.withdraw(merkleProof, amountInGweiFromOracle);

        serviceBalanceAfter = serviceAddress.balance;
        clientBalanceAfter = clientWcAddress.balance;

        assertEq(
            serviceBalanceAfter - serviceBalanceBefore,
                elRewards * (10000 - defaultClientBasisPoints) / 10000
        );
        assertEq(
            clientBalanceAfter - clientBalanceBefore,
                elRewards * defaultClientBasisPoints / 10000
        );

        console.log("test_OracleFeeDistributor_withdraw_with_the_same_proof finished");
    }

    function test_OracleFeeDistributor_Creation_Without_Depositor() public {
        console.log("testOracleFeeDistributorCreationWithoutDepositor started");

        address newFeeDistributorAddress;

        vm.startPrank(operatorAddress);
        vm.expectRevert(OracleFeeDistributor__ClientBasisPointsShouldBeHigherThan5000.selector);
        newFeeDistributorAddress = factory.createFeeDistributor(
            address(oracleFeeDistributorTemplate),
            FeeRecipient({
                recipient: clientWcAddress,
                basisPoints: 4000
            }),
            FeeRecipient({
                recipient: payable(address(0)),
                basisPoints: 0
            })
        );
        vm.stopPrank();

        newFeeDistributorAddress = deployOracleFeeDistributorCreationWithoutDepositor();

        assertEq(newFeeDistributorAddress, oracleFeeDistributorInstanceAddress);

        oracleFeeDistributorInstance = OracleFeeDistributor(payable(newFeeDistributorAddress));

        assertEq(oracleFeeDistributorInstance.clientOnlyClRewards(), 0);

        uint256 clientOnlyClRewards = 15 ether;
        vm.startPrank(operatorAddress);
        oracleFeeDistributorInstance.setClientOnlyClRewards(clientOnlyClRewards);

        vm.expectRevert(OracleFeeDistributor__CannotResetClientOnlyClRewards.selector);
        oracleFeeDistributorInstance.setClientOnlyClRewards(42);
        vm.stopPrank();

        assertEq(oracleFeeDistributorInstance.clientOnlyClRewards(), clientOnlyClRewards);

        withdrawOracleFeeDistributor({clientOnlyClRewards: clientOnlyClRewards});

        console.log("testOracleFeeDistributorCreationWithoutDepositor finished");
    }

    function test_ContractWcFeeDistributor_Rewards_can_be_accounted_as_collateral() public {
        console.log("test_ContractWcFeeDistributor_Rewards_can_be_accounted_as_collateral started");

        address newFeeDistributorAddress = deployContractWcFeeDistributorCreationWithoutDepositor();
        contractWcFeeDistributorInstance = ContractWcFeeDistributor(payable(newFeeDistributorAddress));

        vm.startPrank(operatorAddress);
        contractWcFeeDistributorInstance.increaseDepositedCount(1);
        vm.stopPrank();

        bytes[] memory dummyPubKeys = new bytes[](1);
        dummyPubKeys[0] = "test";
        vm.startPrank(clientWcAddress);
        contractWcFeeDistributorInstance.voluntaryExit(dummyPubKeys);
        vm.stopPrank();

        uint256 rewards = 31 ether;
        uint256 clientSent = 1 ether;

        uint256 serviceBalanceBefore = serviceAddress.balance;
        uint256 clientBalanceBefore = clientWcAddress.balance;

        vm.deal(address(contractWcFeeDistributorInstance), rewards + COLLATERAL + clientSent);

        contractWcFeeDistributorInstance.withdraw();

        uint256 serviceBalanceAfter = serviceAddress.balance;
        uint256 clientBalanceAfter = clientWcAddress.balance;

        assertEq(
            serviceBalanceAfter - serviceBalanceBefore,
            (rewards + clientSent) * (10000 - defaultClientBasisPoints) / 10000
        );
        assertEq(
            clientBalanceAfter - clientBalanceBefore,
            (rewards + clientSent) * defaultClientBasisPoints / 10000 + COLLATERAL
        );

        console.log("test_ContractWcFeeDistributor_Rewards_can_be_accounted_as_collateral finished");
    }

    function test_ContractWcFeeDistributor_Creation_Without_Depositor() public {
        console.log("testContractWcFeeDistributorCreationWithoutDepositor started");

        address newFeeDistributorAddress = deployContractWcFeeDistributorCreationWithoutDepositor();

        assertEq(newFeeDistributorAddress, contractWcFeeDistributorInstanceAddress);

        contractWcFeeDistributorInstance = ContractWcFeeDistributor(payable(newFeeDistributorAddress));

        assertEq(contractWcFeeDistributorInstance.depositedCount(), 0);

        vm.expectRevert(ContractWcFeeDistributor__TooManyPubkeysPassed.selector);
        contractWcFeeDistributorInstance.voluntaryExit(pubKeys);

        uint32 depositedCount = uint32(VALIDATORS_MAX_AMOUNT);

        vm.expectRevert(abi.encodeWithSelector(FeeDistributorFactory__CallerNotAuthorized.selector, address(this)));
        contractWcFeeDistributorInstance.increaseDepositedCount(depositedCount);

        vm.startPrank(operatorAddress);
        contractWcFeeDistributorInstance.increaseDepositedCount(depositedCount);
        vm.stopPrank();

        assertEq(contractWcFeeDistributorInstance.depositedCount(), depositedCount);
        assertEq(contractWcFeeDistributorInstance.exitedCount(), 0);

        vm.expectRevert(abi.encodeWithSelector(FeeDistributor__CallerNotClient.selector, address(this), clientWcAddress));
        contractWcFeeDistributorInstance.voluntaryExit(pubKeys);

        vm.startPrank(clientWcAddress);
        contractWcFeeDistributorInstance.voluntaryExit(pubKeys);
        vm.stopPrank();

        assertEq(contractWcFeeDistributorInstance.exitedCount(), depositedCount);

        withdrawContractWcFeeDistributorAfterVoluntaryExit();

        console.log("testContractWcFeeDistributorCreationWithoutDepositor finished");
    }

    function deployOracleFeeDistributorCreationWithoutDepositor() private returns(address newFeeDistributorAddress) {
        vm.startPrank(operatorAddress);

        newFeeDistributorAddress = factory.createFeeDistributor(
            address(oracleFeeDistributorTemplate),
            FeeRecipient({
                recipient: clientWcAddress,
                basisPoints: defaultClientBasisPoints
            }),
            FeeRecipient({
                recipient: payable(address(0)),
                basisPoints: 0
            })
        );

        vm.stopPrank();
    }

    function deployContractWcFeeDistributorCreationWithoutDepositor() private returns(address newFeeDistributorAddress) {
        vm.startPrank(operatorAddress);

        newFeeDistributorAddress = factory.createFeeDistributor(
            address(contractWcFeeDistributorTemplate),
            FeeRecipient({
        recipient: clientWcAddress,
        basisPoints: defaultClientBasisPoints
        }),
            FeeRecipient({
        recipient: payable(address(0)),
        basisPoints: 0
        })
        );

        vm.stopPrank();
    }

    function withdrawOracleFeeDistributor(uint256 clientOnlyClRewards) private {
        console.log("withdrawOracleFeeDistributor");

        uint256 elRewards = 10 ether;

        vm.deal(address(oracleFeeDistributorInstance), elRewards);

        vm.expectRevert(Oracle__InvalidProof.selector);
        oracleFeeDistributorInstance.withdraw(merkleProof, amountInGweiFromOracle);

        vm.expectRevert(abi.encodeWithSelector(Access__CallerNeitherOperatorNorOwner.selector, address(this), operatorAddress, extraSecureP2pAddress));
        oracle.report(merkleRoot);

        vm.startPrank(operatorAddress);
        oracle.report(merkleRoot);
        vm.stopPrank();

        uint256 serviceBalanceBefore = serviceAddress.balance;
        uint256 clientBalanceBefore = clientWcAddress.balance;

        oracleFeeDistributorInstance.withdraw(merkleProof, amountInGweiFromOracle);

        uint256 serviceBalanceAfter = serviceAddress.balance;
        uint256 clientBalanceAfter = clientWcAddress.balance;

        uint256 clRewards = amountInGweiFromOracle * 1 gwei - clientOnlyClRewards;
        uint256 totalRewards = clRewards + elRewards;

        assertEq(serviceBalanceAfter - serviceBalanceBefore, totalRewards * (10000 - defaultClientBasisPoints) / 10000);
        assertEq(clientBalanceAfter - clientBalanceBefore, totalRewards * defaultClientBasisPoints / 10000 - clRewards);
    }

    function withdrawContractWcFeeDistributorAfterVoluntaryExit() private {
        console.log("withdrawContractWcFeeDistributorAfterVoluntaryExit");

        uint256 rewards = 10 ether;
        uint256 collaterals = COLLATERAL * VALIDATORS_MAX_AMOUNT;

        uint256 serviceBalanceBefore = serviceAddress.balance;
        uint256 clientBalanceBefore = clientWcAddress.balance;

        vm.deal(address(contractWcFeeDistributorInstance), rewards + collaterals);

        contractWcFeeDistributorInstance.withdraw();

        uint256 serviceBalanceAfter = serviceAddress.balance;
        uint256 clientBalanceAfter = clientWcAddress.balance;

        assertEq(serviceBalanceAfter - serviceBalanceBefore, rewards * (10000 - defaultClientBasisPoints) / 10000);
        assertEq(clientBalanceAfter - clientBalanceBefore, rewards * defaultClientBasisPoints / 10000 + collaterals);
    }

    function withdrawContractWcFeeDistributor() private {
        console.log("withdrawContractWcFeeDistributor");

        vm.deal(address(contractWcFeeDistributorInstance), 10 ether);

        uint256 serviceBalanceBefore = serviceAddress.balance;
        uint256 clientBalanceBefore = clientWcAddress.balance;

        contractWcFeeDistributorInstance.withdraw();

        uint256 serviceBalanceAfter = serviceAddress.balance;
        uint256 clientBalanceAfter = clientWcAddress.balance;

        assertEq(serviceBalanceAfter - serviceBalanceBefore, 1 ether);
        assertEq(clientBalanceAfter - clientBalanceBefore, 9 ether);
    }

    function withdrawElFeeDistributor() private {
        console.log("withdrawElFeeDistributor");

        vm.deal(address(elFeeDistributorInstance), 10 ether);

        uint256 serviceBalanceBefore = serviceAddress.balance;
        uint256 clientBalanceBefore = clientWcAddress.balance;

        elFeeDistributorInstance.withdraw();

        uint256 serviceBalanceAfter = serviceAddress.balance;
        uint256 clientBalanceAfter = clientWcAddress.balance;

        assertEq(serviceBalanceAfter - serviceBalanceBefore, 1 ether);
        assertEq(clientBalanceAfter - clientBalanceBefore, 9 ether);
    }

    function makeBeaconDepositForElFeeDistributor() private {
        console.log("makeBeaconDepositForElFeeDistributor");

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

    function makeBeaconDepositForOracleFeeDistributor() private {
        console.log("makeBeaconDepositForOracleFeeDistributor");

        vm.startPrank(operatorAddress);

        uint256 balanceBefore = p2pEthDepositor.totalBalance();

        assertEq(p2pEthDepositor.depositAmount(address(oracleFeeDistributorInstance)), clientDepositedEth);

        p2pEthDepositor.makeBeaconDeposit(
            address(oracleFeeDistributorInstance),
            pubKeys,
            signatures,
            depositDataRoots
        );

        uint256 balanceAfter = balanceBefore - COLLATERAL * VALIDATORS_MAX_AMOUNT;
        assertEq(p2pEthDepositor.totalBalance(), balanceAfter);
        assertEq(p2pEthDepositor.depositAmount(address(oracleFeeDistributorInstance)), clientDepositedEth - COLLATERAL * VALIDATORS_MAX_AMOUNT);

        vm.stopPrank();
    }

    function makeBeaconDepositForContractWcFeeDistributor() private {
        console.log("makeBeaconDepositForContractWcFeeDistributor");

        vm.startPrank(operatorAddress);

        uint256 balanceBefore = p2pEthDepositor.totalBalance();

        assertEq(p2pEthDepositor.depositAmount(address(contractWcFeeDistributorInstance)), clientDepositedEth);

        p2pEthDepositor.makeBeaconDeposit(
            address(contractWcFeeDistributorInstance),
            pubKeysForContractWc,
            signaturesForContractWc,
            depositDataRootsForContractWc
        );

        uint256 balanceAfter = balanceBefore - COLLATERAL * VALIDATORS_MAX_AMOUNT;
        assertEq(p2pEthDepositor.totalBalance(), balanceAfter);
        assertEq(p2pEthDepositor.depositAmount(address(contractWcFeeDistributorInstance)), clientDepositedEth - COLLATERAL * VALIDATORS_MAX_AMOUNT);

        vm.stopPrank();
    }

    function makeBeaconDepositForCustomFeeDistributor() private {
        console.log("makeBeaconDepositForCustomFeeDistributor");

        vm.startPrank(operatorAddress);

        uint256 balanceBefore = p2pEthDepositor.totalBalance();

        assertEq(p2pEthDepositor.depositAmount(address(customFeeDistributorInstance)), clientDepositedEth);

        p2pEthDepositor.makeBeaconDeposit(
            address(customFeeDistributorInstance),
            pubKeysForZeroAddressWc,
            signaturesForZeroAddressWc,
            depositDataRootsForZeroAddressWc
        );

        uint256 balanceAfter = balanceBefore - COLLATERAL * VALIDATORS_MAX_AMOUNT;
        assertEq(p2pEthDepositor.totalBalance(), balanceAfter);
        assertEq(p2pEthDepositor.depositAmount(address(customFeeDistributorInstance)), clientDepositedEth - COLLATERAL * VALIDATORS_MAX_AMOUNT);

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

        vm.expectRevert("ERC1167: create2 failed");
        deployOracleFeeDistributorCreationWithoutDepositor();
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

    function addEthToCustomFeeDistributor() private {
        console.log("addEthToCustomFeeDistributor");

        vm.startPrank(clientDepositorAddress);

        customFeeDistributorTemplate = new MockClientFeeDistributor();

        assertTrue(address(customFeeDistributorInstance) == address(0));

        uint256 totalBalanceBefore = p2pEthDepositor.totalBalance();

        customFeeDistributorInstance = MockClientFeeDistributor(payable(
                p2pEthDepositor.addEth{value: (clientDepositedEth)}(
                    address(customFeeDistributorTemplate),
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

        assertTrue(address(customFeeDistributorInstance) != address(0));
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
