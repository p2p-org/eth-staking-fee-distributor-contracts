import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import fs from "fs";

// (1)
// @ts-ignore
const tree = StandardMerkleTree.load(JSON.parse(fs.readFileSync("tree.json")));

// (2)
for (const [i, v] of tree.entries()) {
    if (v[0] === '0x1111111111111111111111111111111111111111') {
        // (3)
        const proof = tree.getProof(i);
        console.log('Value:', v);
        console.log('Proof:', proof);
    }
}
