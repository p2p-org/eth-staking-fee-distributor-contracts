// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

library P2pAddressLib {
    function _sendValue(address payable _recipient, uint256 _amount) internal returns (bool) {
        (bool success, ) = _recipient.call{
            value: _amount,
            gas: gasleft() / 4 // to prevent DOS, should be enough in normal cases
        }("");

        return success;
    }
}
