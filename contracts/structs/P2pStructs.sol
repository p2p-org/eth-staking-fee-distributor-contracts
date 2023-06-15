// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../feeDistributor/IFeeDistributor.sol";

/// @member basisPoints TODO
/// @member recipient TODO
struct FeeRecipient {
    uint96 basisPoints;
    address payable recipient;
}

struct ValidatorData {
    uint32 depositedCount;
    uint32 exitedCount;
    uint32 collateralReturnedCount;
    uint160 reservedForFutureUse;
}

struct ClientDeposit {
    uint112 amount;
    uint40 expiration;
    uint104 reservedForFutureUse;
}
