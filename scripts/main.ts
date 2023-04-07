import fs from "fs"
import { buildMerkleTreeForValidatorBatch } from "./buildMerkleTreeForValidatorBatch"
import { generateBatchRewardData } from "./generateBatchRewardData"
import { makeOracleReport } from "./makeOracleReport"
import { withdrawAll } from "./withdrawAll"

async function main() {
    const feeDistributorFactoryAddress = "0xD00BFa0A263Bb29C383E1dB3493c3172dE0B367A"
    const batchRewardData = await generateBatchRewardData(feeDistributorFactoryAddress)

    const tree = buildMerkleTreeForValidatorBatch(batchRewardData)
    await makeOracleReport('0x5aBFeC1E3781f0a16241a82AA767041B7bd63F42', tree.root)
    // Send tree.json file to the website and to the withdrawer
    fs.writeFileSync("tree.json", JSON.stringify(tree.dump()));

    await withdrawAll(feeDistributorFactoryAddress)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
