import { FeeDistributor__factory } from "../typechain-types"
import { ethers, getNamedAccounts } from "hardhat"

export async function withdrawOne(
    feeDistributorAddress: string,
    proof: string[],
    amountInGwei: number,
    settings: {
        gasLimit: number,
        nonce: number
    }
) {
    const { deployer } = await getNamedAccounts()
    const deployerSigner = await ethers.getSigner(deployer)

    const feeDistributor = FeeDistributor__factory.connect(
        feeDistributorAddress,
        deployerSigner
    )

    const balance = await ethers.provider.getBalance(feeDistributor.address);
    if (balance.gt(0)) {
        console.log(feeDistributor.address, 'will withdraw')

        const tx = await feeDistributor.withdraw(proof, amountInGwei, settings)
        await tx.wait(1)
        settings.nonce += 1

        console.log(feeDistributor.address, 'withdrew')
    } else {
        console.log(feeDistributor.address, '0 balance')
    }
}
