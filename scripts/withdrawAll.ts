import { getFeeDistributorsFromLogs } from "./getFeeDistributorsFromLogs"
import { withdrawOne } from "./withdrawOne"
import { obtainProof } from "./obtainProof"
import { getFirstValidatorIdAndValidatorCount } from "./getFirstValidatorIdAndValidatorCount"

export async function withdrawAll(
    feeDistributorFactoryAddress: string,
    settings: {
        gasLimit: number,
        nonce: number
    }) {
    const feeDistributorsAddresses = await getFeeDistributorsFromLogs(feeDistributorFactoryAddress)

    // sequential for now due to nonces
    for (const feeDistributorsAddress of feeDistributorsAddresses) {
        try {
            const { firstValidatorId } = await getFirstValidatorIdAndValidatorCount(feeDistributorsAddress)
            const { proof, value } = obtainProof(firstValidatorId)
            await withdrawOne(feeDistributorsAddress, proof, value[2], settings)
        } catch (err) {
            console.log(feeDistributorsAddress, err)
        }
    }
}
