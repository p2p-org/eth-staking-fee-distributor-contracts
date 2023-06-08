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

contract MainUseCase is Test {
    Vm cheats = Vm(HEVM_ADDRESS);

    address payable serviceAddress = payable(0x6Bb8b45a1C6eA816B70d76f83f7dC4f0f87365Ff);
    uint96 defaultClientBasisPoints = 9000;

    address clientDepositorAddress = 0xBE0eB53F46cd790Cd13851d5EFf43D12404d33E8;
    address p2pDeployerAddress = 0x5a52E96BAcdaBb82fd05763E25335261B270Efcb;
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
        assertEq(oracle.owner(), p2pDeployerAddress);
        assertEq(factory.owner(), p2pDeployerAddress);
        assertEq(contractWcFeeDistributorTemplate.owner(), p2pDeployerAddress);
        assertEq(elOnlyFeeDistributorTemplate.owner(), p2pDeployerAddress);
        assertEq(oracleFeeDistributorTemplate.owner(), p2pDeployerAddress);

        emit log_uint(42);
    }
}
