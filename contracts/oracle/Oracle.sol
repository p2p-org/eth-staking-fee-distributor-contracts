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

    /**
    * @notice Set a new oracle report (Merkle root)
    * @param _root Merkle root
    */
    function report(bytes32 _root) external onlyOperatorOrOwner {
        s_root = _root;
    }

    /**
    * @notice Verify Merkle proof (that the leaf belongs to the tree)
    * @param _proof Merkle proof (the leaf's sibling, and each non-leaf hash that could not otherwise be calculated without additional leaf nodes)
    * @param _firstValidatorId Validator Id (number of all deposits previously made to ETH2 DepositContract plus 1)
    * @param _validatorCount (number of validators corresponding to a given FeeDistributor instance, eqaul to the number of ETH2 deposits made with 1 P2pEth2Depositor's deposit)
    * @param _amount total CL rewards earned by all validators (see _validatorCount)
    */
    function verify(
        bytes32[] calldata _proof,
        uint256 _firstValidatorId,
        uint256 _validatorCount,
        uint256 _amount
    ) external {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(_firstValidatorId, _validatorCount, _amount))));

        if (!MerkleProof.verify(_proof, root, leaf)) {
            revert Oracle__InvalidProof();
        }
    }
}
