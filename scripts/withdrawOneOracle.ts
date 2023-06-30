import { OracleFeeDistributor__factory } from "../typechain-types"
import { ethers, getNamedAccounts } from "hardhat"
import { obtainProof } from "./obtainProof"

export async function withdrawOneOracle(feeDistributorAddress: string) {
    const {proof, value} = obtainProof(feeDistributorAddress)
    const amountInGwei: number = value[1]

    const { deployer } = await getNamedAccounts()
    const deployerSigner = await ethers.getSigner(deployer)

    const feeDistributor = OracleFeeDistributor__factory.connect(
        feeDistributorAddress,
        deployerSigner
    )

    await feeDistributor.withdraw(proof, amountInGwei)
}
