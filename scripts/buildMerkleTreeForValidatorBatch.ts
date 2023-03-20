import { StandardMerkleTree } from "@openzeppelin/merkle-tree"

export function buildMerkleTreeForValidatorBatch(oracleData: number[][]) {
    const allValidatorsTree = StandardMerkleTree.of(oracleData, ["uint64", "uint16", "uint256"]);
    return allValidatorsTree
}
