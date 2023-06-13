import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import fs from "fs";

export function obtainProof(feeDistributorAddress: string) {
    // @ts-ignore
    const tree = StandardMerkleTree.load(JSON.parse(fs.readFileSync("tree.json")));

    for (const [i, value] of tree.entries()) {
        if (value[0] === feeDistributorAddress) {
            const proof = tree.getProof(i);
            return ({proof, value})
        }
    }

    throw new Error(`feeDistributorAddress=${feeDistributorAddress} not found`)
}
