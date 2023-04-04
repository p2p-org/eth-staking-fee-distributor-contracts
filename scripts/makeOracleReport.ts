import { Oracle__factory } from "../typechain-types"
import { ethers, getNamedAccounts } from "hardhat"

export async function makeOracleReport(oracleAddress: string, root: string) {
    const { deployer } = await getNamedAccounts()
    const deployerSigner = await ethers.getSigner(deployer)

    const oracle = Oracle__factory.connect(
        oracleAddress,
        deployerSigner
    )

    await oracle.report(root)
}
