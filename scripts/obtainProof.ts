import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import fs from "fs";

// (1)
// @ts-ignore
const tree = StandardMerkleTree.load(JSON.parse(fs.readFileSync("tree.json")));

// (2)
for (const [i, v] of tree.entries()) {
    if (v[0] === '0x7a3ca3eb219c12175b02f0b8131c927ee67e43eb81adab3e2d77d727be4ff5533cdf0ee1300e49f34b63a96786b86a9b') {
        // (3)
        const proof = tree.getProof(i);
        console.log('Value:', v);
        console.log('Proof:', proof);
    }
}
