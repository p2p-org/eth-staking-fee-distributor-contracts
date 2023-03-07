import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import fs from "fs";
import { generateMockOracleData } from "./generateMockOracleData"

// (1)
// replace it with data from BigQuery
const mockOracleData = generateMockOracleData(1000000);

// (2)
const tree = StandardMerkleTree.of(mockOracleData, ["bytes", "uint256"]);

// (3)
// Send it to the Oracle contract
console.log('Merkle Root:', tree.root);

// (4)
// Send tree.json file to the website and to the withdrawer
fs.writeFileSync("tree.json", JSON.stringify(tree.dump()));
