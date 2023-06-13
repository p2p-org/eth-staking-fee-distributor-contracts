import { StandardMerkleTree } from "@openzeppelin/merkle-tree"

export function buildMerkleTreeForFeeDistributorAddress(oracleData: string[][]) {
    const allValidatorsTree = StandardMerkleTree.of(oracleData, ["address", "uint256"]);
    return allValidatorsTree
}
