import { ethers, getNamedAccounts } from "hardhat"
import {
    P2pMessageSender__factory,
} from "../typechain-types"

async function main() {
    try {
        const { deployer } = await getNamedAccounts()
        const deployerSigner = await ethers.getSigner(deployer)
        const {name: chainName} = await ethers.provider.getNetwork()
        console.log('Deploying to: ' + chainName)

        // deploy
        const contract = await new P2pMessageSender__factory(deployerSigner).deploy(
            {gasLimit: 10000000, maxPriorityFeePerGas: 40000000000, maxFeePerGas: 400000000000}
        )
        await contract.deployed()
        console.log('P2pMessageSender deployed at: ' +  contract.address)

        console.log('Done.')
    } catch (err) {
        console.log(err)
    }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

// P2pMessageSender deployed at: 0x3d646129EA5Bb4ca3098C9dA408142183ad675Aa
