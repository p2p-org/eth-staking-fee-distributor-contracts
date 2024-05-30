import { buildMerkleTreeForFeeDistributorAddress } from "./buildMerkleTreeForFeeDistributorAddress"
import fs from "fs"
import { obtainProof } from "./obtainProof"

const values = [
    ["0xc70ee116750Cbb9f589f774e4d463Be4Eb959267", "5000000"],
    ["0x2222222222222222222222222222222222222222", "250000000000"],
    ["0x1A11782051858A95266109DaED1576eD28e48393", "20000000000"],
];

async function main() {
    const tree = buildMerkleTreeForFeeDistributorAddress(values)
    console.log("Root: " + tree.root)

    // Send tree.json file to the website and to the withdrawer
    fs.writeFileSync("tree.json", JSON.stringify(tree.dump()));

    const {proof, value} = obtainProof("0x1A11782051858A95266109DaED1576eD28e48393")

    console.log("Proof:")
    console.log(proof)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
