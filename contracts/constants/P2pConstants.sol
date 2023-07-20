// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

/// @dev Maximal number of ETH2 deposits within a single transaction
/// @dev 400 deposits (12800 ETH) is determined by calldata size limit of 128 kb
/// https://ethereum.stackexchange.com/questions/144120/maximum-calldata-size-per-block
uint256 constant VALIDATORS_MAX_AMOUNT = 400;

/// @dev Collateral size of 1 validator
uint256 constant COLLATERAL = 32 ether;

/// @dev Lockup time to allow P2P to make ETH2 deposits
/// @dev If there is leftover ETH after this time, it can be refunded
uint40 constant TIMEOUT = 1 days;

/// @dev Cooldown period for the client to restore their ETH receiving ability to receive their collaterals
uint256 constant COOLDOWN = 30 days;
