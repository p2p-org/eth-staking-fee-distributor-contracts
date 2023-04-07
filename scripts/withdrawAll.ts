import { getFeeDistributorsFromLogs } from "./getFeeDistributorsFromLogs"
import { withdrawOne } from "./withdrawOne"
import { obtainProof } from "./obtainProof"
import { getFirstValidatorIdAndValidatorCount } from "./getFirstValidatorIdAndValidatorCount"

export async function withdrawAll(feeDistributorFactoryAddress: string) {
    const feeDistributorsAddresses = await getFeeDistributorsFromLogs(feeDistributorFactoryAddress)

    const withdrawPromises = feeDistributorsAddresses.map(async (feeDistributorsAddress) => {
        const {firstValidatorId} = await getFirstValidatorIdAndValidatorCount(feeDistributorsAddress)
        const {proof, value} = obtainProof(firstValidatorId)
        await withdrawOne(feeDistributorsAddress, proof, value[2])
    })

    await Promise.all(withdrawPromises)
}
