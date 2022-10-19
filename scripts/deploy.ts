import { ethers, getNamedAccounts } from "hardhat"
import { FeeDistributor, FeeDistributor__factory, FeeDistributorFactory__factory } from "../typechain-types"

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
            serviceBasisPoints,
            {gasLimit: 3000000, nonce}
        )
        nonce++;

        // set the reference instance of FeeDistributor to the factory
        await feeDistributorFactory.setReferenceInstance(feeDistributor.address, {gasLimit: 1000000, nonce})
        nonce++;

        // event to listen to
        const filter = feeDistributorFactory.filters["FeeDistributorCreated(address,address)"]()

        // an example client address. There can be many more of such.
        const clientAddress = "0x27E9727FD9b8CdDdd0854F56712AD9DF647FaB74"

        // start listening to the FeeDistributorCreated events
        ethers.provider.on(filter, async (log) => {
            try {
                console.log('FeeDistributorCreated event start')

                // retrieve the address of the newly created FeeDistributor contract from the event
                const parsedLog = feeDistributorFactory.interface.parseLog(log);
                const newlyCreatedFeeDistributorAddress = parsedLog.args._newFeeDistributorAddrress

                // set the newly created FeeDistributor contract as coinbase (block rewards recipient)
                // In the real world this will be done in a validator's settings
                console.log('SET THIS IN VALIDATOR:')
                console.log(newlyCreatedFeeDistributorAddress)

                console.log('FeeDistributorCreated event end')
            } catch (err) {
                console.log(err)
            }
        })

        // become an operator to create a client instance
        await feeDistributorFactory.changeOperator(signer.address)

        // create an instance of FeeDistributor for the client
        const createFeeDistributorTxReceipt = await feeDistributorFactory.createFeeDistributor(clientAddress, {gasLimit: 1000000, nonce})
        nonce++;

        // wait for 2 blocks to avoid a prematute exit from the test
        await createFeeDistributorTxReceipt.wait(2)
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
