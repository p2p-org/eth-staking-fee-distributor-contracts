import { ethers, getNamedAccounts } from "hardhat"
import { FeeDistributor__factory, FeeDistributorFactory__factory } from "../typechain-types"

async function main() {
    try {
        // P2P should get 30% (subject to chioce at deploy time)
        const serviceBasisPoints = 3000;
        const serviceAddress = '0xceCFc058DB458c00d0e89D39B2F5e6EF0A473114'

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

        // an example client address. There can be many more of such.
        const clientAddress = "0x27E9727FD9b8CdDdd0854F56712AD9DF647FaB74"

        // create client instance
        const createFeeDistributorTx = await feeDistributorFactory.createFeeDistributor(
            clientAddress,
            serviceBasisPoints,
            {gasLimit: 1000000, nonce}
        )
        const createFeeDistributorTxReceipt = await createFeeDistributorTx.wait();
        const event = createFeeDistributorTxReceipt?.events?.find(event => event.event === 'FeeDistributorCreated');
        if (!event) {
            throw Error('No FeeDistributorCreated found')
        }

        // retrieve client instance address from event
        const newlyCreatedFeeDistributorAddress = event.args?._newFeeDistributorAddress
        console.log('SET THIS IN VALIDATOR:')
        console.log(newlyCreatedFeeDistributorAddress)
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
