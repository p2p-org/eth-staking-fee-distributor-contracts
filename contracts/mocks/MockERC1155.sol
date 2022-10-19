// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../@openzeppelin/contracts/token/ERC1155/presets/ERC1155PresetMinterPauser.sol";

contract MockERC1155 is ERC1155PresetMinterPauser {
    constructor(uint256 id, uint256 amount) ERC1155PresetMinterPauser("test-url") {
        _mint(msg.sender, id, amount, bytes("test-data"));
    }
}
