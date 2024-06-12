// SPDX-FileCopyrightText: 2024 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/console2.sol";
import "../../contracts/p2pEth2Depositor/P2pOrgUnlimitedEthDepositor.sol";
import "../../contracts/feeDistributorFactory/FeeDistributorFactory.sol";
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

    bytes pubKey02;
    bytes signature02;
    bytes32 depositDataRoot02;

    bytes[] pubKeys02;
    bytes[] signatures02;
    bytes32[] depositDataRoots02;

    bytes pubKey02_42eth;
    bytes signature02_42eth;
    bytes32 depositDataRoot02_42eth;

    bytes[] pubKeys02_42eth;
    bytes[] signatures02_42eth;
    bytes32[] depositDataRoots02_42eth;

    bytes pubKey02_2050eth;
    bytes signature02_2050eth;
    bytes32 depositDataRoot02_2050eth;

    bytes pubKey_CustomFd;
    bytes signature_CustomFd;
    bytes32 depositDataRoot_CustomFd;

    bytes[] pubKeys02_2050eth;
    bytes[] signatures02_2050eth;
    bytes32[] depositDataRoots02_2050eth;

    bytes[] pubKeysForZeroAddressWc;
    bytes[] signaturesForZeroAddressWc;
    bytes32[] depositDataRootsForZeroAddressWc;

    bytes[] pubKeys_CustomFd;
    bytes[] signatures_CustomFd;
    bytes32[] depositDataRoots_CustomFd;

    address payable constant serviceAddress =
        payable(0x6Bb8b45a1C6eA816B70d76f83f7dC4f0f87365Ff);
    uint96 constant defaultClientBasisPoints = 9000;
    uint256 constant clientDepositedEth = 320000 ether;

    bytes32 merkleRoot;
    bytes32[] merkleProof;
    uint256 constant amountInGweiFromOracle = 20 gwei; //

    uint256 operatorPrivateKey = 42; // needed for signature
    address payable bundler = payable(address(100500));

    address constant clientDepositorAddress =
        0xBE0eB53F46cd790Cd13851d5EFf43D12404d33E8;
    address payable constant clientWcAddress =
        payable(0xB3E84B6C6409826DC45432B655D8C9489A14A0D7);

    bytes32 constant withdrawalCredentials_01 =
        0x010000000000000000000000B3E84B6C6409826DC45432B655D8C9489A14A0D7;
    bytes32 constant withdrawalCredentials_02 =
        0x020000000000000000000000B3E84B6C6409826DC45432B655D8C9489A14A0D7;
    bytes32 constant withdrawalCredentials_01_CustomFd =
        0x0100000000000000000000002F3B0cde60F8885809B2F347b99d54315ae716A3;

    address constant p2pDeployerAddress =
        0x5a52E96BAcdaBb82fd05763E25335261B270Efcb;
    address operatorAddress;
    address constant extraSecureP2pAddress =
        0xb0d0f9e74e15345D9E618C6f4Ca1C9Cb061C613A;
    address constant beaconDepositContractAddress =
        0x00000000219ab540356cBB839Cbe05303d7705Fa;
    address payable constant entryPointAddress =
        payable(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);

    bytes32 depositId_32_01;
    bytes32 depositId_42_02;
    bytes32 depositId_2050_02;
    bytes32 depositId_32_01_ForCustomFeeDistributorInstance;

    IEntryPoint entryPoint;
    P2pOrgUnlimitedEthDepositor p2pEthDepositor;
    FeeDistributorFactory factory;
    Oracle oracle;

    OracleFeeDistributor oracleFeeDistributorTemplate;
    MockClientFeeDistributor customFeeDistributorTemplate;

    // predictable due to CREATE2
    address constant oracleFeeDistributorInstanceAddress =
        0x1A11782051858A95266109DaED1576eD28e48393;
    address constant customFeeDistributorInstanceAddress =
        0x2F3B0cde60F8885809B2F347b99d54315ae716A3;

    OracleFeeDistributor oracleFeeDistributorInstance;
    MockClientFeeDistributor customFeeDistributorInstance;

    FeeRecipient clientFeeRecipientDefault =
        FeeRecipient({
            recipient: clientWcAddress,
            basisPoints: defaultClientBasisPoints
        });

    FeeRecipient referrerFeeRecipientDefault =
        FeeRecipient({recipient: payable(address(0)), basisPoints: 0});

    function setUp() public {
        vm.createSelectFork("mainnet", 17434740);

        entryPoint = IEntryPoint(entryPointAddress);
        operatorAddress = vm.addr(operatorPrivateKey);
        vm.deal(operatorAddress, 42 ether);

        merkleRoot = bytes32(
            hex"b51c3cf6fac55fc8cf8a1cff1eb8a22566e681a4825a7c5579b48788e6e2a41b"
        );
        merkleProof.push(
            hex"ea7773ca72d6e586f0761520294c857b89081782a32223940d8906ba675c04ca"
        );

        pubKey = bytes(
            hex"87f08e27a19e0d15764838e3af5c33645545610f268c2dadba3c2c789e2579a5d5300a3d72c6fb5fce4e9aa1c2f32d40"
        );
        signature = bytes(
            hex"816597afd6c13068692512ed57e7c6facde10be01b247c58d67f15e3716ec7eb9856d28e25e1375ab526b098fdd3094405435a9bf7bf95369697365536cb904f0ae4f8da07f830ae1892182e318588ce8dd6220be2145f6c29d28e0d57040d42"
        );
        depositDataRoot = bytes32(
            hex"34b7017543befa837eb0af8a32b2c6e543b1d869ff526680c9d59291b742d5b7"
        );

        pubKey02 = bytes(
            hex"a9ff619fbfedc3178cd401526b8320590903f8278c00ab1bf791b836cce92f2afa7c884dca2684a0a835a588e8661fa7"
        );
        signature02 = bytes(
            hex"84d94d74997ab4d4138421c11ba57c93ba5db613f7cba69b9cc4ff2e0ccd3e77694a731a4cbd38a73a1a66cb6fc45c3206dd5ec97733bb9bcca351301845c28de368b77dc01e15a2fed8e8c607e06f737591cefd1af14251c4c0228762fcc695"
        );
        depositDataRoot02 = bytes32(
            hex"0588bf26fe5bee3ab89a604f9eba3afee8eb4a5add07f7e809951ab6db48fb1c"
        );

        pubKey02_42eth = bytes(
            hex"a9ff619fbfedc3178cd401526b8320590903f8278c00ab1bf791b836cce92f2afa7c884dca2684a0a835a588e8661fa7"
        );
        signature02_42eth = bytes(
            hex"ad3600ea1b55dfcbec64e5e52ee4b26e49a9e06889c245b0c5e2c76eb0aeef460dcf50ba5417d2105d578053c3d6154d0386d695d5506b1c0ab1e6220d7114796725d2e62f70fdbdc29415801ef7898b2d6979ec25bf29c2ed9589031bf3ca2f"
        );
        depositDataRoot02_42eth = bytes32(
            hex"123d461cc2b770c761da60918b1a5873730e9bc9cc9d4d2f146404d8be16fae9"
        );

        pubKey02_2050eth = bytes(
            hex"a9ff619fbfedc3178cd401526b8320590903f8278c00ab1bf791b836cce92f2afa7c884dca2684a0a835a588e8661fa7"
        );
        signature02_2050eth = bytes(
            hex"85680774d1b83e52fa327d7bf640e513dcd0b97eb0d8c854aa2209cfcf249cb327946b41a72ef7271ec0c3e3b169f03b0b6ed092feb8f1ab88d47b2002e25a2a29b316be4ab2a78c18ab02b6a64a95953e21893e77a11bcd7ae54699a0c129f4"
        );
        depositDataRoot02_2050eth = bytes32(
            hex"2e3b263532435ba176dbd7d0442a99bb062525bc994af41447957450ae062691"
        );

        pubKey_CustomFd = bytes(
            hex"944a91ae380a0ece1a41a9cf22729d4af45373308400b2b178f56eaa9322d55b85bd97bd4d82aec8fb8b0fe4152a0ab0"
        );
        signature_CustomFd = bytes(
            hex"8a7e148dd76c5ce6cfcba6522d0a65f6b20124027fba69c602a85868f91899f0e257800d282e5f60ebe24e8041668f200c039dbf2413f63dfe997f02f008d3605167cd93a7fb71095bf45164e97a95f01195556f2c9899f9aaa8240914b877a2"
        );
        depositDataRoot_CustomFd = bytes32(
            hex"21cb4c3055a11918f01af6a7a8dfaf29a6c979c57e72bd1a2d2ee2b5852d18cf"
        );

        for (uint256 i = 0; i < VALIDATORS_MAX_AMOUNT; i++) {
            pubKeys.push(pubKey);
            signatures.push(signature);
            depositDataRoots.push(depositDataRoot);

            pubKeys02.push(pubKey02);
            signatures02.push(signature02);
            depositDataRoots02.push(depositDataRoot02);

            pubKeys02_42eth.push(pubKey02_42eth);
            signatures02_42eth.push(signature02_42eth);
            depositDataRoots02_42eth.push(depositDataRoot02_42eth);

            pubKeys02_2050eth.push(pubKey02_2050eth);
            signatures02_2050eth.push(signature02_2050eth);
            depositDataRoots02_2050eth.push(depositDataRoot02_2050eth);

            pubKeys_CustomFd.push(pubKey_CustomFd);
            signatures_CustomFd.push(signature_CustomFd);
            depositDataRoots_CustomFd.push(depositDataRoot_CustomFd);

            pubKeysForZeroAddressWc.push(
                bytes(
                    hex"b1c9ac4f20bca70faf03d1afa308912073753d3f7a54aa205604f411feacf26243bcf5119fcbf2ebde1b34327c80506b"
                )
            );
            signaturesForZeroAddressWc.push(
                bytes(
                    hex"adfdd15ae10ecd6d53f5d66b6344542ee1195fa128bd20025136eb2e828fe787ec8244510561d833153dfa47367c32d601a9ddd31494daa8926cb596e5490df3dcfdc719e09c18d9fb3e2d059769433fa2b72de1b59e0416376b60edf2af7c8d"
                )
            );
            depositDataRootsForZeroAddressWc.push(
                bytes32(
                    hex"11ac2aa82040395c3ee36e21486d58820dae708cf7359c06b44c8975f7b7cf98"
                )
            );
        }

        vm.startPrank(p2pDeployerAddress);
        oracle = new Oracle();
        factory = new FeeDistributorFactory(defaultClientBasisPoints);
        oracleFeeDistributorTemplate = new OracleFeeDistributor(
            address(oracle),
            address(factory),
            serviceAddress
        );
        p2pEthDepositor = new P2pOrgUnlimitedEthDepositor(address(factory));
        vm.stopPrank();

        checkOwnership();
        setOperator();
        setOwner();
        setP2pEth2Depositor();

        depositId_32_01 = p2pEthDepositor.getDepositId(
            withdrawalCredentials_01,
            32 ether,
            address(oracleFeeDistributorTemplate),
            clientFeeRecipientDefault,
            referrerFeeRecipientDefault
        );

        depositId_42_02 = p2pEthDepositor.getDepositId(
            withdrawalCredentials_02,
            42 ether,
            address(oracleFeeDistributorTemplate),
            clientFeeRecipientDefault,
            referrerFeeRecipientDefault
        );

        depositId_2050_02 = p2pEthDepositor.getDepositId(
            withdrawalCredentials_02,
            2050 ether,
            address(oracleFeeDistributorTemplate),
            clientFeeRecipientDefault,
            referrerFeeRecipientDefault
        );
    }

    function test_Main_Use_Case() public {
        console.log("MainUseCase started");

        addEthToOracleFeeDistributor();
        makeBeaconDepositForOracleFeeDistributor();
        withdrawOracleFeeDistributor({clientOnlyClRewards: 0});

        console.log("MainUseCase finished");
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

        UserOperation
            memory userOp = getUserOperationWithoutSignatureForOracleFeeDistributor(
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

        assertGt(
            serviceBalanceAfter - serviceBalanceBefore,
            (((totalRewards * (10000 - defaultClientBasisPoints)) / 10000) *
                98) / 100
        ); // >98%
        assertGt(
            clientBalanceAfter - clientBalanceBefore,
            (((totalRewards * defaultClientBasisPoints) / 10000 - clRewards) *
                98) / 100
        ); // >98%
        assertLt(
            (beneficiaryBalanceAfter - beneficiaryBalanceBefore),
            (((totalRewards * defaultClientBasisPoints) / 10000) * 2) / 100
        );

        console.log("testErc4337WithdrawOracleFeeDistributor finished");
    }

    function getOps(
        UserOperation memory userOpWithoutSignature
    ) private returns (UserOperation[] memory) {
        bytes32 userOpHash = entryPoint.getUserOpHash(userOpWithoutSignature);
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(operatorPrivateKey, hash);
        userOpWithoutSignature.signature = abi.encodePacked(r, s, v);
        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = userOpWithoutSignature;
        return ops;
    }

    function getUserOperationWithoutSignature(
        Erc4337Account sender
    ) private pure returns (UserOperation memory) {
        return
            UserOperation({
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
    ) private pure returns (UserOperation memory) {
        return
            UserOperation({
                sender: address(sender),
                nonce: 0,
                initCode: bytes(""),
                callData: abi.encodeWithSelector(
                    sender.withdrawSelector(),
                    _proof,
                    _amountInGwei
                ),
                callGasLimit: 100000,
                verificationGasLimit: 100000,
                preVerificationGas: 100000,
                maxFeePerGas: 50 gwei,
                maxPriorityFeePerGas: 0,
                paymasterAndData: bytes(""),
                signature: bytes("")
            });
    }

    function test_Custom_Client_FeeDistributor() public {
        console.log("testCustomClientFeeDistributor started");

        addEthToCustomFeeDistributor();
        makeBeaconDepositForCustomFeeDistributor();

        console.log("testCustomClientFeeDistributor finished");
    }

    function test_Null_basis_points_will_lead_to_the_lock_of_funds() public {
        console.log(
            "test_Null_basis_points_will_lead_to_the_lock_of_funds started"
        );

        uint256 deposit = 1 ether;

        vm.startPrank(clientDepositorAddress);
        (bytes32 depositId, address fdInstance) = p2pEthDepositor.addEth{
            value: deposit
        }(
            withdrawalCredentials_01,
            MIN_ACTIVATION_BALANCE,
            address(oracleFeeDistributorTemplate),
            FeeRecipient({recipient: clientWcAddress, basisPoints: 0}),
            FeeRecipient({recipient: payable(address(0)), basisPoints: 0}),
            ""
        );
        vm.stopPrank();

        uint256 depositAmount = p2pEthDepositor.depositAmount(depositId);
        assertEq(depositAmount, deposit);

        vm.startPrank(clientWcAddress);
        vm.warp(block.timestamp + TIMEOUT + 1);
        uint256 clientWcAddressBalanceBefore = clientWcAddress.balance;

        p2pEthDepositor.refund(
            withdrawalCredentials_01,
            MIN_ACTIVATION_BALANCE,
            fdInstance
        );

        vm.stopPrank();
        uint256 clientWcAddressBalanceAfter = clientWcAddress.balance;

        assertEq(
            clientWcAddressBalanceAfter - clientWcAddressBalanceBefore,
            deposit
        );
        uint256 depositAmountAfterRefund = p2pEthDepositor.depositAmount(
            depositId
        );
        assertEq(depositAmountAfterRefund, 0);

        console.log(
            "test_Null_basis_points_will_lead_to_the_lock_of_funds finished"
        );
    }

    function test_OracleFeeDistributor_withdraw_after_emergencyEtherRecoveryWithoutOracleData()
        public
    {
        console.log(
            "test_OracleFeeDistributor_withdraw_after_emergencyEtherRecoveryWithoutOracleData started"
        );

        address newFeeDistributorAddress = deployOracleFeeDistributorCreationWithoutDepositor();
        oracleFeeDistributorInstance = OracleFeeDistributor(
            payable(newFeeDistributorAddress)
        );

        uint256 elRewards = 6 ether;
        vm.deal(address(oracleFeeDistributorInstance), elRewards);

        uint256 serviceBalanceBefore = serviceAddress.balance;
        uint256 clientBalanceBefore = clientWcAddress.balance;

        vm.startPrank(clientWcAddress);
        oracleFeeDistributorInstance.emergencyEtherRecoveryWithoutOracleData();
        vm.stopPrank();

        uint256 serviceBalanceAfter = serviceAddress.balance;
        uint256 clientBalanceAfter = clientWcAddress.balance;

        assertEq(serviceBalanceAfter - serviceBalanceBefore, elRewards / 2);
        assertEq(clientBalanceAfter - clientBalanceBefore, elRewards / 2);

        vm.startPrank(operatorAddress);
        oracle.report(merkleRoot);
        vm.stopPrank();

        elRewards = 5 ether;
        vm.deal(address(oracleFeeDistributorInstance), elRewards);

        vm.expectRevert(
            OracleFeeDistributor__WaitForEnoughRewardsToWithdraw.selector
        );
        oracleFeeDistributorInstance.withdraw(
            merkleProof,
            amountInGweiFromOracle
        );

        console.log(
            "test_OracleFeeDistributor_withdraw_after_emergencyEtherRecoveryWithoutOracleData finished"
        );
    }

    function test_OracleFeeDistributor_withdraw_with_the_same_proof() public {
        console.log(
            "test_OracleFeeDistributor_withdraw_with_the_same_proof started"
        );

        address newFeeDistributorAddress = deployOracleFeeDistributorCreationWithoutDepositor();
        oracleFeeDistributorInstance = OracleFeeDistributor(
            payable(newFeeDistributorAddress)
        );

        uint256 elRewards = 10 ether;
        vm.deal(address(oracleFeeDistributorInstance), elRewards);

        vm.startPrank(operatorAddress);
        oracle.report(merkleRoot);
        vm.stopPrank();

        uint256 serviceBalanceBefore = serviceAddress.balance;
        uint256 clientBalanceBefore = clientWcAddress.balance;

        oracleFeeDistributorInstance.withdraw(
            merkleProof,
            amountInGweiFromOracle
        );

        uint256 serviceBalanceAfter = serviceAddress.balance;
        uint256 clientBalanceAfter = clientWcAddress.balance;

        uint256 clRewards = amountInGweiFromOracle * 1 gwei;
        uint256 totalRewards = clRewards + elRewards;

        assertEq(
            serviceBalanceAfter - serviceBalanceBefore,
            (totalRewards * (10000 - defaultClientBasisPoints)) / 10000
        );
        assertEq(
            clientBalanceAfter - clientBalanceBefore,
            (totalRewards * defaultClientBasisPoints) / 10000 - clRewards
        );

        vm.deal(address(oracleFeeDistributorInstance), elRewards); // add more elRewards

        serviceBalanceBefore = serviceAddress.balance;
        clientBalanceBefore = clientWcAddress.balance;

        oracleFeeDistributorInstance.withdraw(
            merkleProof,
            amountInGweiFromOracle
        );

        serviceBalanceAfter = serviceAddress.balance;
        clientBalanceAfter = clientWcAddress.balance;

        assertEq(
            serviceBalanceAfter - serviceBalanceBefore,
            (elRewards * (10000 - defaultClientBasisPoints)) / 10000
        );
        assertEq(
            clientBalanceAfter - clientBalanceBefore,
            (elRewards * defaultClientBasisPoints) / 10000
        );

        console.log(
            "test_OracleFeeDistributor_withdraw_with_the_same_proof finished"
        );
    }

    function test_OracleFeeDistributor_Creation_Without_Depositor() public {
        console.log("testOracleFeeDistributorCreationWithoutDepositor started");

        address newFeeDistributorAddress;

        vm.startPrank(operatorAddress);
        vm.expectRevert(
            OracleFeeDistributor__ClientBasisPointsShouldBeHigherThan5000
                .selector
        );
        newFeeDistributorAddress = factory.createFeeDistributor(
            address(oracleFeeDistributorTemplate),
            FeeRecipient({recipient: clientWcAddress, basisPoints: 4000}),
            FeeRecipient({recipient: payable(address(0)), basisPoints: 0})
        );
        vm.stopPrank();

        newFeeDistributorAddress = deployOracleFeeDistributorCreationWithoutDepositor();

        assertEq(newFeeDistributorAddress, oracleFeeDistributorInstanceAddress);

        oracleFeeDistributorInstance = OracleFeeDistributor(
            payable(newFeeDistributorAddress)
        );

        assertEq(oracleFeeDistributorInstance.clientOnlyClRewards(), 0);

        uint256 clientOnlyClRewards = 15 ether;
        vm.startPrank(operatorAddress);
        oracleFeeDistributorInstance.setClientOnlyClRewards(
            clientOnlyClRewards
        );

        vm.expectRevert(
            OracleFeeDistributor__CannotResetClientOnlyClRewards.selector
        );
        oracleFeeDistributorInstance.setClientOnlyClRewards(42);
        vm.stopPrank();

        assertEq(
            oracleFeeDistributorInstance.clientOnlyClRewards(),
            clientOnlyClRewards
        );

        withdrawOracleFeeDistributor({
            clientOnlyClRewards: clientOnlyClRewards
        });

        console.log(
            "testOracleFeeDistributorCreationWithoutDepositor finished"
        );
    }

    function test_P2pOrgUnlimitedEthDepositor_makeBeaconDepositWithEip7251()
        public
    {
        console.log(
            "test_P2pOrgUnlimitedEthDepositor_makeBeaconDepositWithEip7251 started"
        );

        bytes32 depositId = addEthToOracleFeeDistributor();

        vm.startPrank(operatorAddress);

        uint256 balanceBefore = p2pEthDepositor.totalBalance();

        assertEq(p2pEthDepositor.depositAmount(depositId), clientDepositedEth);

        vm.expectRevert(
            P2pOrgUnlimitedEthDepositor__Eip7251NotEnabledYet.selector
        );
        p2pEthDepositor.makeBeaconDeposit(
            withdrawalCredentials_02,
            1 ether,
            address(oracleFeeDistributorInstance),
            pubKeys,
            signatures,
            depositDataRoots
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                P2pOrgUnlimitedEthDepositor__CallerNotEip7251Enabler.selector,
                operatorAddress,
                extraSecureP2pAddress
            )
        );
        p2pEthDepositor.enableEip7251();

        vm.stopPrank();
        vm.startPrank(extraSecureP2pAddress);

        p2pEthDepositor.enableEip7251();

        vm.stopPrank();
        vm.startPrank(operatorAddress);

        vm.expectRevert(
            abi.encodeWithSelector(
                P2pOrgUnlimitedEthDepositor__EthAmountPerValidatorInWeiOutOfRange
                    .selector,
                1 ether
            )
        );
        p2pEthDepositor.makeBeaconDeposit(
            withdrawalCredentials_02,
            1 ether,
            address(oracleFeeDistributorInstance),
            pubKeys02,
            signatures02,
            depositDataRoots02
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                P2pOrgUnlimitedEthDepositor__EthAmountPerValidatorInWeiOutOfRange
                    .selector,
                2050 ether
            )
        );
        p2pEthDepositor.makeBeaconDeposit(
            withdrawalCredentials_02,
            2050 ether,
            address(oracleFeeDistributorInstance),
            pubKeys02_2050eth,
            signatures02_2050eth,
            depositDataRoots02_2050eth
        );

        p2pEthDepositor.makeBeaconDeposit(
            withdrawalCredentials_02,
            32 ether,
            address(oracleFeeDistributorInstance),
            pubKeys02,
            signatures02,
            depositDataRoots02
        );

        uint256 balanceAfter = balanceBefore -
            MIN_ACTIVATION_BALANCE *
            VALIDATORS_MAX_AMOUNT;
        assertEq(p2pEthDepositor.totalBalance(), balanceAfter);
        assertEq(
            p2pEthDepositor.depositAmount(depositId),
            clientDepositedEth - MIN_ACTIVATION_BALANCE * VALIDATORS_MAX_AMOUNT
        );

        p2pEthDepositor.makeBeaconDeposit(
            withdrawalCredentials_02,
            42 ether,
            address(oracleFeeDistributorInstance),
            pubKeys02_42eth,
            signatures02_42eth,
            depositDataRoots02_42eth
        );

        vm.stopPrank();

        uint256 balanceAfter_42eth = balanceAfter -
            42 ether *
            VALIDATORS_MAX_AMOUNT;
        assertEq(p2pEthDepositor.totalBalance(), balanceAfter_42eth);
        assertEq(
            p2pEthDepositor.depositAmount(depositId),
            clientDepositedEth -
                MIN_ACTIVATION_BALANCE *
                VALIDATORS_MAX_AMOUNT -
                42 ether *
                VALIDATORS_MAX_AMOUNT
        );

        console.log(
            "test_P2pOrgUnlimitedEthDepositor_makeBeaconDepositWithEip7251 finished"
        );
    }

    function deployOracleFeeDistributorCreationWithoutDepositor()
        private
        returns (address newFeeDistributorAddress)
    {
        vm.startPrank(operatorAddress);

        newFeeDistributorAddress = factory.createFeeDistributor(
            address(oracleFeeDistributorTemplate),
            FeeRecipient({
                recipient: clientWcAddress,
                basisPoints: defaultClientBasisPoints
            }),
            FeeRecipient({recipient: payable(address(0)), basisPoints: 0})
        );

        vm.stopPrank();
    }

    function withdrawOracleFeeDistributor(uint256 clientOnlyClRewards) private {
        console.log("withdrawOracleFeeDistributor");

        uint256 elRewards = 10 ether;

        vm.deal(address(oracleFeeDistributorInstance), elRewards);

        vm.expectRevert(Oracle__InvalidProof.selector);
        oracleFeeDistributorInstance.withdraw(
            merkleProof,
            amountInGweiFromOracle
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                Access__CallerNeitherOperatorNorOwner.selector,
                address(this),
                operatorAddress,
                extraSecureP2pAddress
            )
        );
        oracle.report(merkleRoot);

        vm.startPrank(operatorAddress);
        oracle.report(merkleRoot);
        vm.stopPrank();

        uint256 serviceBalanceBefore = serviceAddress.balance;
        uint256 clientBalanceBefore = clientWcAddress.balance;

        oracleFeeDistributorInstance.withdraw(
            merkleProof,
            amountInGweiFromOracle
        );

        uint256 serviceBalanceAfter = serviceAddress.balance;
        uint256 clientBalanceAfter = clientWcAddress.balance;

        uint256 clRewards = amountInGweiFromOracle *
            1 gwei -
            clientOnlyClRewards;
        uint256 totalRewards = clRewards + elRewards;

        assertEq(
            serviceBalanceAfter - serviceBalanceBefore,
            (totalRewards * (10000 - defaultClientBasisPoints)) / 10000
        );
        assertEq(
            clientBalanceAfter - clientBalanceBefore,
            (totalRewards * defaultClientBasisPoints) / 10000 - clRewards
        );
    }

    function makeBeaconDepositForOracleFeeDistributor() private {
        console.log("makeBeaconDepositForOracleFeeDistributor");

        vm.startPrank(operatorAddress);

        uint256 balanceBefore = p2pEthDepositor.totalBalance();

        assertEq(
            p2pEthDepositor.depositAmount(depositId_32_01),
            clientDepositedEth
        );

        p2pEthDepositor.makeBeaconDeposit(
            withdrawalCredentials_01,
            MIN_ACTIVATION_BALANCE,
            address(oracleFeeDistributorInstance),
            pubKeys,
            signatures,
            depositDataRoots
        );

        uint256 balanceAfter = balanceBefore -
            MIN_ACTIVATION_BALANCE *
            VALIDATORS_MAX_AMOUNT;
        assertEq(p2pEthDepositor.totalBalance(), balanceAfter);
        assertEq(
            p2pEthDepositor.depositAmount(depositId_32_01),
            clientDepositedEth - MIN_ACTIVATION_BALANCE * VALIDATORS_MAX_AMOUNT
        );

        vm.stopPrank();
    }

    function makeBeaconDepositForCustomFeeDistributor() private {
        console.log("makeBeaconDepositForCustomFeeDistributor");

        vm.startPrank(operatorAddress);

        uint256 balanceBefore = p2pEthDepositor.totalBalance();

        assertEq(
            p2pEthDepositor.depositAmount(
                depositId_32_01_ForCustomFeeDistributorInstance
            ),
            clientDepositedEth
        );

        p2pEthDepositor.makeBeaconDeposit(
            withdrawalCredentials_01_CustomFd,
            MIN_ACTIVATION_BALANCE,
            address(customFeeDistributorInstance),
            pubKeys_CustomFd,
            signatures_CustomFd,
            depositDataRoots_CustomFd
        );

        uint256 balanceAfter = balanceBefore -
            MIN_ACTIVATION_BALANCE *
            VALIDATORS_MAX_AMOUNT;
        assertEq(p2pEthDepositor.totalBalance(), balanceAfter);
        assertEq(
            p2pEthDepositor.depositAmount(
                depositId_32_01_ForCustomFeeDistributorInstance
            ),
            clientDepositedEth - MIN_ACTIVATION_BALANCE * VALIDATORS_MAX_AMOUNT
        );

        vm.stopPrank();
    }

    function addEthToOracleFeeDistributor() private returns (bytes32) {
        console.log("addEthToOracleFeeDistributor");

        vm.startPrank(clientDepositorAddress);

        assertTrue(address(oracleFeeDistributorInstance) == address(0));

        uint256 totalBalanceBefore = p2pEthDepositor.totalBalance();

        (bytes32 depositId, address feeDistributorInstance) = p2pEthDepositor
            .addEth{value: clientDepositedEth}(
            withdrawalCredentials_01,
            MIN_ACTIVATION_BALANCE,
            address(oracleFeeDistributorTemplate),
            clientFeeRecipientDefault,
            referrerFeeRecipientDefault,
            ""
        );

        oracleFeeDistributorInstance = OracleFeeDistributor(
            payable(feeDistributorInstance)
        );

        uint256 totalBalanceAfter = p2pEthDepositor.totalBalance();

        assertTrue(address(oracleFeeDistributorInstance) != address(0));
        assertEq(totalBalanceAfter - totalBalanceBefore, clientDepositedEth);

        vm.stopPrank();

        vm.expectRevert("ERC1167: create2 failed");
        deployOracleFeeDistributorCreationWithoutDepositor();

        return depositId;
    }

    function addEthToCustomFeeDistributor() private {
        console.log("addEthToCustomFeeDistributor");

        vm.startPrank(clientDepositorAddress);

        customFeeDistributorTemplate = new MockClientFeeDistributor();

        assertTrue(address(customFeeDistributorInstance) == address(0));

        uint256 totalBalanceBefore = p2pEthDepositor.totalBalance();

        (bytes32 depositId, address fdInstanceAddress) = p2pEthDepositor.addEth{
            value: clientDepositedEth
        }(
            withdrawalCredentials_01_CustomFd,
            MIN_ACTIVATION_BALANCE,
            address(customFeeDistributorTemplate),
            clientFeeRecipientDefault,
            referrerFeeRecipientDefault,
            ""
        );

        customFeeDistributorInstance = MockClientFeeDistributor(
            payable(fdInstanceAddress)
        );
        depositId_32_01_ForCustomFeeDistributorInstance = depositId;

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
        assertEq(oracleFeeDistributorTemplate.owner(), extraSecureP2pAddress);
        vm.stopPrank();
    }
}
