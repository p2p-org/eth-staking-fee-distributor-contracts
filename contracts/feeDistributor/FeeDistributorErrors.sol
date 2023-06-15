// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../feeDistributorFactory/IFeeDistributorFactory.sol";

error FeeDistributor__NotFactory(address _passedAddress);
error FeeDistributor__ZeroAddressService();
error FeeDistributor__ClientAddressEqualsService(address _passedAddress);
error FeeDistributor__ZeroAddressClient();
error FeeDistributor__InvalidClientBasisPoints(uint96 _clientBasisPoints);
error FeeDistributor__ClientPlusReferralBasisPointsExceed10000(uint96 _clientBasisPoints, uint96 _referralBasisPoints);
error FeeDistributor__ReferrerAddressEqualsService(address _passedAddress);
error FeeDistributor__ReferrerAddressEqualsClient(address _passedAddress);
error FeeDistributor__NotFactoryCalled(address _msgSender, IFeeDistributorFactory _actualFactory);
error FeeDistributor__ClientAlreadySet(address _existingClient);
error FeeDistributor__ClientNotSet();
error FeeDistributor__ReferrerBasisPointsMustBeZeroIfAddressIsZero(uint96 _referrerBasisPoints);
error FeeDistributor__ServiceCannotReceiveEther(address _service);
error FeeDistributor__ClientCannotReceiveEther(address _client);
error FeeDistributor__ReferrerCannotReceiveEther(address _referrer);
error FeeDistributor__NothingToWithdraw();
error FeeDistributor__CallerNotClient(address _caller, address _client);
