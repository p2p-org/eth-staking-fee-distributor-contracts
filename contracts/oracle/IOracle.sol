// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "../access/IOwnable.sol";

/**
 * @dev External interface of Oracle declared to support ERC165 detection.
 */
interface IOracle is IOwnable, IERC165 {
    // Events

    /**
    * @notice Emits when a new oracle report (Merkle root) recorded
    * @param _root Merkle root
    */
    event Reported(bytes32 indexed _root);

    // Functions

    /**
    * @notice Set a new oracle report (Merkle root)
    * @param _root Merkle root
    */
    function report(bytes32 _root) external;
}
