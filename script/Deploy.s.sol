// SPDX-FileCopyrightText: 2024 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import "../contracts/oracle/Oracle.sol";
import "../contracts/feeDistributorFactory/FeeDistributorFactory.sol";
import "../contracts/feeDistributor/OracleFeeDistributor.sol";
import "../contracts/p2pEth2Depositor/P2pOrgUnlimitedEthDepositor.sol";

contract Deploy is Script {
    uint96 constant defaultClientBasisPoints = 9000;
    address payable constant serviceAddress = payable(0x6Bb8b45a1C6eA816B70d76f83f7dC4f0f87365Ff);
    address constant oracleAddress = 0x4E67DfF29304075A383D877F0BA760b94FE38803;

    function run() external returns (
        FeeDistributorFactory,
        OracleFeeDistributor,
        P2pOrgUnlimitedEthDepositor
    ) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        Oracle oracle = new Oracle();
        FeeDistributorFactory factory = new FeeDistributorFactory(defaultClientBasisPoints);
        OracleFeeDistributor oracleFeeDistributorTemplate = new OracleFeeDistributor(address(oracle), address(factory), serviceAddress);
        P2pOrgUnlimitedEthDepositor p2pEthDepositor = new P2pOrgUnlimitedEthDepositor(address(factory));
        factory.setP2pEth2Depositor(address(p2pEthDepositor));

        vm.stopBroadcast();

        return (
            factory,
            oracleFeeDistributorTemplate,
            p2pEthDepositor
        );
    }
}
