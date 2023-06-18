pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/console2.sol";
import "../../contracts/erc4337/interfaces/IEntryPoint.sol";

contract Erc4337Withdraw is Test {

    address payable constant entryPointAddress = payable(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);
    IEntryPoint entryPoint;

    function setUp() public {
        vm.createSelectFork("mainnet", 17434740);

        entryPoint = IEntryPoint(entryPointAddress);
    }

    function testErc4337Withdraw() public {
        emit log_uint(entryPoint.SIG_VALIDATION_FAILED());
    }
}
