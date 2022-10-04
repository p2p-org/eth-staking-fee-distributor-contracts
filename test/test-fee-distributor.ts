import { expect } from "chai"
import {ethers, getNamedAccounts} from "hardhat"
import {
    FeeDistributor__factory,
    FeeDistributorFactory__factory,
    FeeDistributor,
    FeeDistributorFactory
} from '../typechain-types'
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"

describe("FeeDistributor", function () {

    // deployer, owner of contracts
    let signer: SignerWithAddress

    // factory contract for deploying individual FeeDistributor contract instances for each user on demand
    let feeDistributorFactory: FeeDistributorFactory

    // P2P secure address (cold storage, multisig, etc.)
    const serviceAddress = "0x1234567890123456789012345678901234567890"

    // P2P should get 30% (subject to chioce at deploy time)
    const servicePercent =  30;

    // client should get 70% (subject to chioce at deploy time)
    const clientPercent = 70;

    before(async () => {
        const { deployer } = await getNamedAccounts()
        signer = await ethers.getSigner(deployer)

        // deploy factory contract
        const factoryFactory = new FeeDistributorFactory__factory(signer)
        feeDistributorFactory = await factoryFactory.deploy()

        const factory = new FeeDistributor__factory(signer)

        // deploy a reference instance of FeeDistributor contract - the base for further clones
        const feeDistributor = await factory.deploy(
            feeDistributorFactory.address,
            serviceAddress,
            servicePercent,
            clientPercent
        )

        // set the reference instance of FeeDistributor to the factory
        await feeDistributorFactory.initialize(feeDistributor.address)
    })

    it("distributes fees", async function () {
        try {
            // event to listen to
            const filter = feeDistributorFactory.filters["FeeDistributorCreated(address)"]()

            // an example client address. There can be many more of such.
            const clientAddress = "0x0000000000000000000000000000000000C0FFEE"

            // start listening to the FeeDistributorCreated events
            ethers.provider.on(filter, async (log) => {
                try {
                    console.log('FeeDistributorCreated event start')

                    // retrieve the address of the newly created FeeDistributor contract from the event
                    const parsedLog = feeDistributorFactory.interface.parseLog(log);
                    const newlyCreatedFeeDistributorAddress = parsedLog.args.newFeeDistributorAddrress

                    // set the newly created FeeDistributor contract as coinbase (block rewards recipient)
                    // In the real world this will be done in a validator's settings
                    await ethers.provider.send("hardhat_setCoinbase", [
                        newlyCreatedFeeDistributorAddress,
                    ])

                    // simulate producing a new block so that our FeeDistributor contract can get its rewards
                    await ethers.provider.send("evm_mine", [])

                    // attach to the FeeDistributor contract with the owner (signer)
                    // @ts-ignore
                    const feeDistributor: FeeDistributor = await ethers.getContractAt(
                        "FeeDistributor",
                        newlyCreatedFeeDistributorAddress,
                        signer
                    )

                    // call withdraw
                    await feeDistributor.withdraw()

                    const totalBlockReward = ethers.utils.parseEther('2')

                    // get service address balance
                    const serviceAddressBalance = await ethers.provider.getBalance(serviceAddress)
                    console.log(serviceAddressBalance.toString())

                    // make sure P2P (service) got its percent
                    expect(serviceAddressBalance).to.equal(totalBlockReward.mul(servicePercent).div(100))

                    // get client address balance
                    const clientAddressBalance = await ethers.provider.getBalance(clientAddress)
                    console.log(clientAddressBalance.toString())

                    // make sure client got its percent
                    expect(clientAddressBalance).to.equal(totalBlockReward.mul(clientPercent).div(100))

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
    })
})
