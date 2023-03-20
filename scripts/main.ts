import { generateMockBatchRewardData } from "./generateMockBatchRewardData"
import fs from "fs"
import { buildMerkleTreeForValidatorBatch } from "./buildMerkleTreeForValidatorBatch"
import { obtainProof } from "./obtainProof"

async function main() {
    const BatchCount = 100000
    const TestFirstValidatorId = 545253
    const testValidatorCount = 314
    const testAmountInGwei = 2340000000

    // replace it with data from BigQuery
    const batchRewardData = generateMockBatchRewardData(BatchCount, TestFirstValidatorId, testValidatorCount, testAmountInGwei);

    const tree = buildMerkleTreeForValidatorBatch(batchRewardData)

    // Send it to the Oracle contract
    console.log('Merkle Root:', tree.root);

    // Send tree.json file to the website and to the withdrawer
    fs.writeFileSync("tree.json", JSON.stringify(tree.dump()));

    const {proof, value} = obtainProof(TestFirstValidatorId)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
