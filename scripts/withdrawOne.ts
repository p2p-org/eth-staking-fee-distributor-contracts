import { FeeDistributor__factory } from "../typechain-types"
import { ethers, getNamedAccounts } from "hardhat"

export async function withdrawOne(feeDistributorAddress: string, proof: string[], amountInGwei: number) {
    const { deployer } = await getNamedAccounts()
    const deployerSigner = await ethers.getSigner(deployer)

    const feeDistributor = FeeDistributor__factory.connect(
        feeDistributorAddress,
        deployerSigner
    )

    await feeDistributor.withdraw(proof, amountInGwei)
}
