import { ethers, getNamedAccounts } from "hardhat"
import { FeeDistributor, FeeDistributor__factory, FeeDistributorFactory__factory } from "../typechain-types"

async function main() {
    try {
        // P2P secure address (cold storage, multisig, etc.)
        const serviceAddress = "0xDcC5dD922fb1D0fd0c450a0636a8cE827521f0eD"

        // P2P should get 30% (subject to chioce at deploy time)
        const servicePercent = 30;

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
            servicePercent,
            {gasLimit: 3000000, nonce}
        )
        nonce++;

        const REFERENCE_INSTANCE_SETTER_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("REFERENCE_INSTANCE_SETTER_ROLE"))
        await feeDistributorFactory.grantRole(REFERENCE_INSTANCE_SETTER_ROLE, signer.address, {gasLimit: 1000000, nonce})
        nonce++;

        const INSTANCE_CREATOR_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("INSTANCE_CREATOR_ROLE"))
        await feeDistributorFactory.grantRole(INSTANCE_CREATOR_ROLE, signer.address, {gasLimit: 1000000, nonce})
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
