import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import fs from "fs";
import { generateMockOracleData } from "./generateMockOracleData"

// (1)
const values = generateMockOracleData(10);

console.log(values);

// (2)
const tree = StandardMerkleTree.of(values, ["bytes", "uint256"]);

// (3)
console.log('Merkle Root:', tree.root);

// (4)
fs.writeFileSync("tree.json", JSON.stringify(tree.dump()));
