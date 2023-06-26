import fs from "fs"
import { buildMerkleTreeForValidatorBatch } from "./buildMerkleTreeForValidatorBatch"
import { generateBatchRewardData } from "./generateBatchRewardData"
import { makeOracleReport } from "./makeOracleReport"
import { withdrawAll } from "./withdrawAll"
import { getIitialClientOnlyClRewards } from "./getIitialClientOnlyClRewards"

async function main() {
    const feeDistributorFactoryAddress = "0xd5B7680f95c5A6CAeCdBBEB1DeE580960C4F891b"

    const validatorDataArray = await getIitialClientOnlyClRewards()

    const batchRewardData = validatorDataArray.map(d => ([
        d.oracleId,
        d.validatorCount,
        d.sum
    ]))

    const tree = buildMerkleTreeForValidatorBatch(batchRewardData)
    await makeOracleReport('0x105D2F6C358d185d1D81a73c1F76a75a2Cc500ed', tree.root)
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
