// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";

contract MockERC721 is ERC721PresetMinterPauserAutoId {
    constructor() ERC721PresetMinterPauserAutoId("MockERC721", "MOCK721", "test-url") {
        mint(msg.sender);
    }
}
