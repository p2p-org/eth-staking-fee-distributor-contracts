import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import fs from "fs";

export function obtainProof(firstValidatorId: number) {
    // @ts-ignore
    const tree = StandardMerkleTree.load(JSON.parse(fs.readFileSync("tree.json")));

    for (const [i, value] of tree.entries()) {
        if (value[0] === firstValidatorId) {
            // (3)
            const proof = tree.getProof(i);
            console.log('Value:', value);
            console.log('Proof:', proof);

            return ({proof, value})
        }
    }

    throw new Error(`Validator with ID=${firstValidatorId} not found`)
}
