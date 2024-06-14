// SPDX-FileCopyrightText: 2024 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

/**
* @title This is a mock for testing only.
* @dev DO NOT deploy in production!
*/
contract MockAlteringReceive {
    bool private s_shouldRevertOnReceive;

    receive() external payable {
        if (s_shouldRevertOnReceive) {
            revert("Intentional revert");
        }
    }

    function startRevertingOnReceive() external {
        s_shouldRevertOnReceive = true;
    }

    function stopRevertingOnReceive() external {
        s_shouldRevertOnReceive = false;
    }
}
