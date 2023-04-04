import { FeeDistributor__factory } from "../typechain-types"
import { ethers } from "hardhat"

export async function getFirstValidatorIdAndValidatorCount(feeDistributorAddress: string) {
    const feeDistributor = FeeDistributor__factory.connect(
        feeDistributorAddress,
        ethers.provider
    )

    const firstValidatorId = (await feeDistributor.firstValidatorId()).toNumber()
    const validatorCount = (await feeDistributor.validatorCount()).toNumber()

    return {firstValidatorId, validatorCount}
}
