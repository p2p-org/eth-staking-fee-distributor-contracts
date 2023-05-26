// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

/**
* @dev 400 deposits (12800 ETH) is determined by calldata size limit of 128 kb
* @dev https://ethereum.stackexchange.com/questions/144120/maximum-calldata-size-per-block
*/
uint256 constant VALIDATORS_MAX_AMOUNT = 400;

/**
* @dev Collateral size of one node.
*/
uint256 constant COLLATERAL = 32 ether;

uint64 constant TIMEOUT = 1 days;
