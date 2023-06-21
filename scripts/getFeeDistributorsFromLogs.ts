import { IFeeDistributorFactory__factory } from "../typechain-types"
import { ethers } from "hardhat"

export async function getFeeDistributorsFromLogs(feeDistributorFactoryAddress: string) {
    const factory = IFeeDistributorFactory__factory.connect(
        feeDistributorFactoryAddress,
        ethers.provider
    )

    const filter = factory.filters.FeeDistributorFactory__FeeDistributorCreated(null, null)

    let result = await factory.queryFilter(filter, 0, "latest");

    return result.map(event => event.args._newFeeDistributorAddress)
}
