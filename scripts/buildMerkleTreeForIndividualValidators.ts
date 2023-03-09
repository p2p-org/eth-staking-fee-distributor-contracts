import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import { PubkeyReward } from "./models/PubkeyReward"

export function buildMerkleTreeForIndividualValidators(pubkeyRewardData: PubkeyReward[]) {
    const allValidatorsTree = StandardMerkleTree.of(pubkeyRewardData, ["bytes", "uint256"]);
    return allValidatorsTree
}
