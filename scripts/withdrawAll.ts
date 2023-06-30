import { getFeeDistributorsFromLogs } from "./getFeeDistributorsFromLogs"
import { withdrawOneOracle } from "./withdrawOneOracle"
import { ethers } from "hardhat"
import { withdrawOne } from "./withdrawOne"

const withdrawSelectorAbi = [
    {
        "inputs": [],
        "name": "withdrawSelector",
        "outputs": [
            {
                "internalType": "bytes4",
                "name": "",
                "type": "bytes4"
            }
        ],
        "stateMutability": "pure",
        "type": "function"
    }
]

export async function withdrawAll(feeDistributorFactoryAddress: string) {
    const feeDistributorsAddresses = await getFeeDistributorsFromLogs(feeDistributorFactoryAddress)

    const oracleFeeDistributorsAddresses = feeDistributorsAddresses.filter(async fd => {
        const feeDistributor = new ethers.Contract(
            fd,
            withdrawSelectorAbi,
            ethers.provider
        )
        const withdrawSelector = await feeDistributor.withdrawSelector()

        return withdrawSelector === '0xdd83edc3' // OracleFeeDistributor selector
    })

    const withdrawOraclePromises = oracleFeeDistributorsAddresses.map(withdrawOneOracle)

    const otherFeeDistributorsAddresses = (function() {
        const exclusionSet = new Set(oracleFeeDistributorsAddresses);
        return feeDistributorsAddresses.filter(e => !exclusionSet.has(e));
    })()

    const withdrawOtherPromises = otherFeeDistributorsAddresses.map(withdrawOne)

    await Promise.all([withdrawOraclePromises, withdrawOtherPromises])
}
