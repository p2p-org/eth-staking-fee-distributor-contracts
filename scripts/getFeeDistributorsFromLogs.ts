import { IFeeDistributorFactory__factory } from "../typechain-types"
import { ethers } from "hardhat"

export async function getFeeDistributorsFromLogs(feeDistributorFactoryAddress: string) {
    const factory = IFeeDistributorFactory__factory.connect(
        feeDistributorFactoryAddress,
        ethers.provider
    )

    const filter = factory.filters.FeeDistributorCreated(null, null)

    let result = await factory.queryFilter(filter, 0, "latest");

    const feeDistributors = result.map(event => event.args._newFeeDistributorAddress)

    return feeDistributors
}
