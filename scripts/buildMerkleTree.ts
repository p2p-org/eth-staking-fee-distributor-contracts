import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import fs from "fs";

// (1)
const values = [
    ["0x92bf19f1b7ce8a942f5f40eeb7fecba0fd331d7674477240bc6de3430fb40b60e030b9cf4dce63a93e98844a2da4f211", "5000000000000000000"],
    ["0x8d82b56734553df587aeeacf0dc883025014842bf47a6c3f2b31c26f6d8db5783fded3b58a0d29f86bfd727bb122d3be", "2500000000000000000"]
];

// (2)
const tree = StandardMerkleTree.of(values, ["bytes", "uint256"]);

// (3)
console.log('Merkle Root:', tree.root);

// (4)
fs.writeFileSync("tree.json", JSON.stringify(tree.dump()));
