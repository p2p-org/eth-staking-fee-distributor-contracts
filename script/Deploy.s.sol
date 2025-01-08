// SPDX-FileCopyrightText: 2024 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import "../contracts/feeDistributor/DeoracleizedFeeDistributor.sol";

contract Deploy is Script {
    address payable constant serviceAddress =
        payable(0x6Bb8b45a1C6eA816B70d76f83f7dC4f0f87365Ff);
    address constant factoryAddress =
        0x5cdF046Bd49629E5130a4A82400733523Ba5820C;

    function run() external returns (DeoracleizedFeeDistributor) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);
        DeoracleizedFeeDistributor deoracleizedFeeDistributorTemplate = new DeoracleizedFeeDistributor(
                factoryAddress,
                serviceAddress
            );

        vm.stopBroadcast();

        return (deoracleizedFeeDistributorTemplate);
    }
}
