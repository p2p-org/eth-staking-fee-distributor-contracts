// SPDX-FileCopyrightText: 2024 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/console2.sol";
import "../../contracts/p2pEth2Depositor/P2pOrgUnlimitedEthDepositor.sol";
import "../../contracts/feeDistributorFactory/FeeDistributorFactory.sol";
import "../../contracts/feeDistributor/DeoracleizedFeeDistributor.sol";
import "../../contracts/structs/P2pStructs.sol";

contract Deoracleized is Test {
    bytes pubKey;
    bytes signature;
    bytes32 depositDataRoot;

    bytes[] pubKeys;
    bytes[] signatures;
    bytes32[] depositDataRoots;

    FeeDistributorFactory constant factory =
        FeeDistributorFactory(0xecA6e48C44C7c0cAf4651E5c5089e564031E8b90);
    P2pOrgUnlimitedEthDepositor constant p2pEthDepositor =
        P2pOrgUnlimitedEthDepositor(
            payable(0x23BE839a14cEc3D6D716D904f09368Bbf9c750eb)
        );
    DeoracleizedFeeDistributor deoracleizedFeeDistributorTemplate;
    DeoracleizedFeeDistributor deoracleizedFeeDistributorInstance;

    address constant p2pDeployerAddress =
        0x588ede4403DF0082C5ab245b35F0f79EB2d8033a;
    address constant extraSecureP2pAddress =
        0xb0d0f9e74e15345D9E618C6f4Ca1C9Cb061C613A;
    address constant clientDepositorAddress =
        0xBE0eB53F46cd790Cd13851d5EFf43D12404d33E8;
    address payable constant clientWcAddress =
        payable(0xB3E84B6C6409826DC45432B655D8C9489A14A0D7);
    address payable constant serviceAddress =
        payable(0x6Bb8b45a1C6eA816B70d76f83f7dC4f0f87365Ff);

    uint96 constant defaultClientBasisPoints = 9000;
    uint256 constant clientDepositedEth = 320000 ether;

    address private operatorAddress;
    uint256 private operatorPrivateKey;

    bytes32 constant withdrawalCredentials_01 =
        0x010000000000000000000000B3E84B6C6409826DC45432B655D8C9489A14A0D7;
    bytes32 depositId_32_01;

    FeeRecipient clientFeeRecipientDefault =
        FeeRecipient({
            recipient: clientWcAddress,
            basisPoints: defaultClientBasisPoints
        });
    FeeRecipient referrerFeeRecipientDefault =
        FeeRecipient({recipient: payable(address(0)), basisPoints: 0});

    function setUp() public {
        vm.createSelectFork("mainnet", 20819000);

        (operatorAddress, operatorPrivateKey) = makeAddrAndKey("operator");

        vm.startPrank(p2pDeployerAddress);
        deoracleizedFeeDistributorTemplate = new DeoracleizedFeeDistributor(
            address(factory),
            serviceAddress
        );
        vm.stopPrank();

        checkOwnership();
        setOperator();
        setOwner();
        depositId_32_01 = p2pEthDepositor.getDepositId(
            withdrawalCredentials_01,
            32 ether,
            address(deoracleizedFeeDistributorTemplate),
            clientFeeRecipientDefault,
            referrerFeeRecipientDefault
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
        for (uint256 i = 0; i < VALIDATORS_MAX_AMOUNT; i++) {
            pubKeys.push(pubKey);
            signatures.push(signature);
            depositDataRoots.push(depositDataRoot);
        }
    }

    function test_Main_Use_Case_Deoracleized() public {
        console.log("test_Main_Use_Case_Deoracleized started");

        addEthToDeoracleizedFeeDistributor();
        makeBeaconDepositForDeoracleizedFeeDistributor();
        withdrawDeoracleizedFeeDistributor();

        console.log("test_Main_Use_Case_Deoracleized finished");
    }

    function withdrawDeoracleizedFeeDistributor() private {
        console.log("withdrawDeoracleizedFeeDistributor");

        uint256 clientAmount = 9 ether;
        uint256 serviceAmount = 0.6 ether;
        uint256 referrerAmount = 0.4 ether;

        uint256 elRewards = clientAmount + serviceAmount + referrerAmount;

        vm.deal(address(deoracleizedFeeDistributorInstance), elRewards);

        uint256 serviceBalanceBefore = serviceAddress.balance;
        uint256 clientBalanceBefore = clientWcAddress.balance;

        vm.expectRevert(
            abi.encodeWithSelector(
                Access__AddressNeitherOperatorNorOwner.selector,
                address(this),
                operatorAddress,
                extraSecureP2pAddress
            )
        );
        deoracleizedFeeDistributorInstance.withdraw(
            clientAmount,
            serviceAmount,
            referrerAmount
        );

        vm.startPrank(operatorAddress);
        vm.expectRevert(FeeDistributor__ReferrerNotSet.selector);
        deoracleizedFeeDistributorInstance.withdraw(
            clientAmount,
            serviceAmount,
            referrerAmount
        );

        deoracleizedFeeDistributorInstance.withdraw(
            clientAmount,
            serviceAmount,
            0
        );
        vm.stopPrank();

        uint256 serviceBalanceAfter = serviceAddress.balance;
        uint256 clientBalanceAfter = clientWcAddress.balance;

        assertEq(serviceBalanceAfter - serviceBalanceBefore, serviceAmount);
        assertEq(clientBalanceAfter - clientBalanceBefore, clientAmount);
    }

    function makeBeaconDepositForDeoracleizedFeeDistributor() private {
        console.log("makeBeaconDepositForDeoracleizedFeeDistributor");

        vm.startPrank(operatorAddress);

        uint256 balanceBefore = p2pEthDepositor.totalBalance();

        assertEq(
            p2pEthDepositor.depositAmount(depositId_32_01),
            clientDepositedEth
        );

        p2pEthDepositor.makeBeaconDeposit(
            withdrawalCredentials_01,
            MIN_ACTIVATION_BALANCE,
            address(deoracleizedFeeDistributorInstance),
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

    function checkOwnership() private {
        console.log("checkOwnership");

        assertEq(factory.owner(), p2pDeployerAddress);
        assertEq(
            deoracleizedFeeDistributorTemplate.owner(),
            p2pDeployerAddress
        );
    }

    function setOperator() private {
        console.log("setOperator");

        vm.startPrank(p2pDeployerAddress);

        assertTrue(factory.operator() != operatorAddress);
        factory.changeOperator(operatorAddress);
        assertEq(factory.operator(), operatorAddress);

        vm.stopPrank();
    }

    function setOwner() private {
        console.log("setOwner");

        vm.startPrank(p2pDeployerAddress);
        assertTrue(factory.owner() != extraSecureP2pAddress);
        factory.transferOwnership(extraSecureP2pAddress);
        assertTrue(factory.owner() != extraSecureP2pAddress);
        vm.startPrank(extraSecureP2pAddress);
        factory.acceptOwnership();
        assertEq(factory.owner(), extraSecureP2pAddress);
        assertEq(
            deoracleizedFeeDistributorTemplate.owner(),
            extraSecureP2pAddress
        );
        vm.stopPrank();
    }

    function addEthToDeoracleizedFeeDistributor() private {
        console.log("addEthToDeoracleizedFeeDistributor");

        vm.startPrank(clientDepositorAddress);

        assertTrue(address(deoracleizedFeeDistributorInstance) == address(0));

        uint256 totalBalanceBefore = p2pEthDepositor.totalBalance();

        (, address feeDistributorInstance) = p2pEthDepositor.addEth{
            value: clientDepositedEth
        }(
            withdrawalCredentials_01,
            MIN_ACTIVATION_BALANCE,
            address(deoracleizedFeeDistributorTemplate),
            clientFeeRecipientDefault,
            referrerFeeRecipientDefault,
            ""
        );

        deoracleizedFeeDistributorInstance = DeoracleizedFeeDistributor(
            payable(feeDistributorInstance)
        );

        uint256 totalBalanceAfter = p2pEthDepositor.totalBalance();

        assertTrue(address(deoracleizedFeeDistributorInstance) != address(0));
        assertEq(totalBalanceAfter - totalBalanceBefore, clientDepositedEth);

        vm.stopPrank();

        vm.expectRevert("ERC1167: create2 failed");
        deployDeoracleizedFeeDistributorCreationWithoutDepositor();
    }

    function deployDeoracleizedFeeDistributorCreationWithoutDepositor()
        private
        returns (address newFeeDistributorAddress)
    {
        vm.startPrank(operatorAddress);

        newFeeDistributorAddress = factory.createFeeDistributor(
            address(deoracleizedFeeDistributorTemplate),
            clientFeeRecipientDefault,
            referrerFeeRecipientDefault
        );

        vm.stopPrank();
    }
}
