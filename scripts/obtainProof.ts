import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import fs from "fs";

// (1)
// @ts-ignore
const tree = StandardMerkleTree.load(JSON.parse(fs.readFileSync("tree.json")));

// (2)
for (const [i, v] of tree.entries()) {
    if (v[0] === '0x8d82b56734553df587aeeacf0dc883025014842bf47a6c3f2b31c26f6d8db5783fded3b58a0d29f86bfd727bb122d3be') {
        // (3)
        const proof = tree.getProof(i);
        console.log('Value:', v);
        console.log('Proof:', proof);
    }
}
