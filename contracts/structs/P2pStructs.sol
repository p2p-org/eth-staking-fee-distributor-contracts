// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../feeDistributor/IFeeDistributor.sol";

struct FeeRecipient {
    uint96 basisPoints;
    address payable recipient;
}

struct ValidatorData {
    uint112 clientOnlyClRewards;
    uint64 firstValidatorId;
    uint32 validatorCount;
    uint48 reservedForFutureUse;
}

struct ClientDeposit {
    uint112 amount;
    uint40 expiration;
    IFeeDistributor feeDistributorTemplate;
    uint96 reservedForFutureUse;
}
