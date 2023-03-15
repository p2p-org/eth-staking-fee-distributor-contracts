import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import fs from "fs";

// (1)
// @ts-ignore
const tree = StandardMerkleTree.load(JSON.parse(fs.readFileSync("tree.json")));

// (2)
for (const [i, v] of tree.entries()) {
    if (v[0] === '0xa7a591c01356c89f6856eeb3b6226125d3b6364449d4d13dc10ff21454cbbc9e7bdf07312df2fa685e179bcfd1679050') {
        // (3)
        const proof = tree.getProof(i);
        console.log('Value:', v);
        console.log('Proof:', proof);
    }
}
