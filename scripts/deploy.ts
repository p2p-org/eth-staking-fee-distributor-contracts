import { ethers, getNamedAccounts } from "hardhat"
import { FeeDistributor__factory, FeeDistributorFactory__factory } from "../typechain-types"

async function main() {
    try {
        // P2P should get 30% (subject to chioce at deploy time)
        const serviceBasisPoints = 3000;
        const serviceAddress = '0x6Bb8b45a1C6eA816B70d76f83f7dC4f0f87365Ff'

        const { deployer } = await getNamedAccounts()
        const signer = await ethers.getSigner(deployer)

        // deploy factory contract
        const factoryFactory = new FeeDistributorFactory__factory(signer)
        let nonce = await ethers.provider.getTransactionCount(deployer)
        const feeDistributorFactory = await factoryFactory.deploy({gasLimit: 3000000, nonce})
        nonce++;

        const factory = new FeeDistributor__factory(signer)
        // deploy a reference instance of FeeDistributor contract - the base for further clones
        const feeDistributor = await factory.deploy(
            feeDistributorFactory.address,
            serviceAddress,
            {gasLimit: 3000000, nonce}
        )
        nonce++;

        // set the reference instance of FeeDistributor to the factory
        await feeDistributorFactory.setReferenceInstance(feeDistributor.address, {gasLimit: 1000000, nonce})
        nonce++;
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
