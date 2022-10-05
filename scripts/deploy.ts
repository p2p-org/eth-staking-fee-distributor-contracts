import { ethers, getNamedAccounts } from "hardhat"
import { FeeDistributor, FeeDistributor__factory, FeeDistributorFactory__factory } from "../typechain-types"
import { expect } from "chai"

async function main() {
    try {
        // P2P secure address (cold storage, multisig, etc.)
        const serviceAddress = "0xDcC5dD922fb1D0fd0c450a0636a8cE827521f0eD"

        // P2P should get 30% (subject to chioce at deploy time)
        const servicePercent = 30;

        // client should get 70% (subject to chioce at deploy time)
        const clientPercent = 70;

        const { deployer } = await getNamedAccounts()
        const signer = await ethers.getSigner(deployer)

        // deploy factory contract
        const factoryFactory = new FeeDistributorFactory__factory(signer)
        const feeDistributorFactory = await factoryFactory.deploy()
        await feeDistributorFactory.deployed()

        const factory = new FeeDistributor__factory(signer)

        // deploy a reference instance of FeeDistributor contract - the base for further clones
        const feeDistributor = await factory.deploy(
            feeDistributorFactory.address,
            serviceAddress,
            servicePercent,
            clientPercent
        )
        await feeDistributor.deployed()

        // set the reference instance of FeeDistributor to the factory
        await feeDistributorFactory.initialize(feeDistributor.address)

        // event to listen to
        const filter = feeDistributorFactory.filters["FeeDistributorCreated(address)"]()

        // an example client address. There can be many more of such.
        const clientAddress = "0x27E9727FD9b8CdDdd0854F56712AD9DF647FaB74"

        // start listening to the FeeDistributorCreated events
        ethers.provider.on(filter, async (log) => {
            try {
                console.log('FeeDistributorCreated event start')

                // retrieve the address of the newly created FeeDistributor contract from the event
                const parsedLog = feeDistributorFactory.interface.parseLog(log);
                const newlyCreatedFeeDistributorAddress = parsedLog.args.newFeeDistributorAddrress

                // set the newly created FeeDistributor contract as coinbase (block rewards recipient)
                // In the real world this will be done in a validator's settings
                console.log('SET THIS IN VALIDATOR:')
                console.log(newlyCreatedFeeDistributorAddress)

                console.log('FeeDistributorCreated event end')
            } catch (err) {
                console.log(err)
            }
        })

        // create an instance of FeeDistributor for the client
        const createFeeDistributorTxReceipt = await feeDistributorFactory.createFeeDistributor(clientAddress)

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
