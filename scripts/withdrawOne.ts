import { ethers, getNamedAccounts } from "hardhat"

const withdrawAbi = [
    {
        "inputs": [],
        "name": "withdraw",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    }
]

export async function withdrawOne(feeDistributorAddress: string) {
    const { deployer } = await getNamedAccounts()
    const deployerSigner = await ethers.getSigner(deployer)

    const feeDistributor = new ethers.Contract(
        feeDistributorAddress,
        withdrawAbi,
        deployerSigner
    )

    await feeDistributor.withdraw()
}
