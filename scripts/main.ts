import fs from "fs"
import { makeOracleReport } from "./makeOracleReport"
import { withdrawAll } from "./withdrawAll"
import { buildMerkleTreeForFeeDistributorAddress } from "./buildMerkleTreeForFeeDistributorAddress"
import { getFeeDistributorsFromLogs } from "./getFeeDistributorsFromLogs"
import { getClRewards } from "./getClRewards"

async function main() {
    const feeDistributorFactoryAddress = "0x37FcbE7D16328036fd36A512b8D97cFd16779944"
    const feeDistributors = await getFeeDistributorsFromLogs(feeDistributorFactoryAddress)
    const rewardDataPromises = feeDistributors.map(async fd => {
        const amount = await getClRewards(fd)
        return [fd, amount.toString()]
    })
    const rewardData = await Promise.all(rewardDataPromises)
    const tree = buildMerkleTreeForFeeDistributorAddress(rewardData)
    await makeOracleReport('0xe3c1E6958da770fBb492f8b6B85ea00ABb81E8f9', tree.root)
    // // Send tree.json file to the website and to the withdrawer
    fs.writeFileSync("tree.json", JSON.stringify(tree.dump()));

    await withdrawAll(feeDistributorFactoryAddress)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
