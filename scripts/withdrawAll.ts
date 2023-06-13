import { getFeeDistributorsFromLogs } from "./getFeeDistributorsFromLogs"
import { withdrawOne } from "./withdrawOne"
import { obtainProof } from "./obtainProof"

export async function withdrawAll(feeDistributorFactoryAddress: string) {
    const feeDistributorsAddresses = await getFeeDistributorsFromLogs(feeDistributorFactoryAddress)

    const withdrawPromises = feeDistributorsAddresses.map(async (feeDistributorsAddress) => {
        const {proof, value} = obtainProof(feeDistributorFactoryAddress)
        await withdrawOne(feeDistributorsAddress, proof, value[2])
    })

    await Promise.all(withdrawPromises)
}
