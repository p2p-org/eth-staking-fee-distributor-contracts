import fs from "fs"
import { buildMerkleTreeForValidatorBatch } from "./buildMerkleTreeForValidatorBatch"
import { makeOracleReport } from "./makeOracleReport"
import { withdrawAll } from "./withdrawAll"
import { getIitialClientOnlyClRewards } from "./getIitialClientOnlyClRewards"
import { ethers, getNamedAccounts } from "hardhat"

async function main() {
    const { deployer } = await getNamedAccounts()
    const settings = {
        gasLimit: 200000,
        nonce: await ethers.provider.getTransactionCount(deployer)
    }

    const feeDistributorFactoryAddress = "0xd5B7680f95c5A6CAeCdBBEB1DeE580960C4F891b"

    const validatorDataArray = await getIitialClientOnlyClRewards()

    const batchRewardData = validatorDataArray.map(d => ([
        d.oracleId,
        d.validatorCount,
        d.sum
    ]))

    const tree = buildMerkleTreeForValidatorBatch(batchRewardData)
    await makeOracleReport('0x105D2F6C358d185d1D81a73c1F76a75a2Cc500ed', tree.root, settings)
    // Send tree.json file to the website and to the withdrawer
    fs.writeFileSync("tree.json", JSON.stringify(tree.dump()));

    await withdrawAll(feeDistributorFactoryAddress, settings)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
