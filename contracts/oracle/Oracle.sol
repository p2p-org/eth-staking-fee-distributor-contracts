// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "./@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "../assetRecovering/OwnableAssetRecoverer.sol";
import "../access/OwnableWithOperator.sol";
import "../@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "./IOracle.sol";

/**
* @notice Invalid Proof
*/
error Oracle__InvalidProof();

/**
* @title Oracle stores the Merkle root updated regularly
* @dev Leaves are hashes of:
* - first validator id
* - validator count
* - sum of CL rewards earned by all validators with ids [id, count])
*/
contract Oracle is OwnableAssetRecoverer, OwnableWithOperator, ERC165, IOracle {
    bytes32 private s_root;

    function report(bytes32 _root) external onlyOperatorOrOwner {
        s_root = _root;
    }

    function verify(
        bytes32[] calldata proof,
        uint256 firstValidatorId,
        uint256 validatorCount,
        uint256 amount
    ) external {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(firstValidatorId, validatorCount, amount))));

        if (!MerkleProof.verify(proof, root, leaf)) {
            revert Oracle__InvalidProof();
        }
    }
}
