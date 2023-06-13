import { buildMerkleTreeForFeeDistributorAddress } from "./buildMerkleTreeForFeeDistributorAddress"
import fs from "fs"
import { obtainProof } from "./obtainProof"

const values = [
    ["0x1111111111111111111111111111111111111111", "5000000"],
    ["0x2222222222222222222222222222222222222222", "250000000000"],
    ["0x4b08827f4a9a56bde2d93a28dcdd7db066ada23d", "20000000000"],
];

async function main() {
    const tree = buildMerkleTreeForFeeDistributorAddress(values)
    console.log("Root: " + tree.root)

    // Send tree.json file to the website and to the withdrawer
    fs.writeFileSync("tree.json", JSON.stringify(tree.dump()));

    const {proof, value} = obtainProof("0x4b08827f4a9a56bde2d93a28dcdd7db066ada23d")

    console.log("Proof:")
    proof.map(console.log)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
