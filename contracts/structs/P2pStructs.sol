// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../feeDistributor/IFeeDistributor.sol";

/// @dev 256 bit struct
/// @member basisPoints basis points (percent * 100) of EL rewards that should go to the recipient
/// @member recipient address of the recipient
struct FeeRecipient {
    uint96 basisPoints;
    address payable recipient;
}

/// @dev 256 bit struct
/// @member depositedCount the number of deposited validators
/// @member exitedCount the number of validators requested to exit
/// @member collateralReturnedCount the number of collaterals (multiples of 32 ETH) returned to the client
/// @member reservedForFutureUse unused space making up to 256 bit. Can be some address in the future.
struct ValidatorData {
    uint32 depositedCount;
    uint32 exitedCount;
    uint32 collateralReturnedCount;
    uint160 reservedForFutureUse;
}

/// @dev 256 bit struct
/// @member amount amount of ETH in wei to be used for an ETH2 deposit corresponding to a particular FeeDistributor instance
/// @member expiration block timestamp after which the client will be able to get a refund
/// @member reservedForFutureUse unused space making up to 256 bit
struct ClientDeposit {
    uint112 amount;
    uint40 expiration;
    uint104 reservedForFutureUse;
}
