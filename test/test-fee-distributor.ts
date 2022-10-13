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
    const clientPercent = 100 - servicePercent;

    before(async () => {
        const { deployer } = await getNamedAccounts()
        signer = await ethers.getSigner(deployer)

        // deploy factory contract
        const factoryFactory = new FeeDistributorFactory__factory(signer)
        feeDistributorFactory = await factoryFactory.deploy({gasLimit: 9000000})

        const factory = new FeeDistributor__factory(signer)

        // deploy a reference instance of FeeDistributor contract - the base for further clones
        const feeDistributor = await factory.deploy(
            feeDistributorFactory.address,
            serviceAddress,
            servicePercent,
            {gasLimit: 9000000}
        )

        const REFERENCE_INSTANCE_SETTER_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("REFERENCE_INSTANCE_SETTER_ROLE"))
        await feeDistributorFactory.grantRole(REFERENCE_INSTANCE_SETTER_ROLE, signer.address)

        // set the reference instance of FeeDistributor to the factory
        await feeDistributorFactory.setReferenceInstance(feeDistributor.address)
    })

    it("distributes fees", async function () {
        // event to listen to
        const filter = feeDistributorFactory.filters["FeeDistributorCreated(address,address)"]()

        // an example client address. There can be many more of such.
        const clientAddress = "0x0000000000000000000000000000000000C0FFEE"

        // start listening to the FeeDistributorCreated events
        ethers.provider.on(filter, async (log) => {
            try {
                // retrieve the address of the newly created FeeDistributor contract from the event
                const parsedLog = feeDistributorFactory.interface.parseLog(log);
                const newlyCreatedFeeDistributorAddress = parsedLog.args._newFeeDistributorAddrress

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

                // make sure P2P (service) got its percent
                expect(serviceAddressBalance).to.equal(totalBlockReward.mul(servicePercent).div(100))

                // get client address balance
                const clientAddressBalance = await ethers.provider.getBalance(clientAddress)

                // make sure client got its percent
                expect(clientAddressBalance).to.equal(totalBlockReward.mul(clientPercent).div(100))
            } catch (err) {
                console.error(err)
            }
        })

        const INSTANCE_CREATOR_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("INSTANCE_CREATOR_ROLE"))
        await feeDistributorFactory.grantRole(INSTANCE_CREATOR_ROLE, signer.address)

        // create an instance of FeeDistributor for the client
        const createFeeDistributorTxReceipt = await feeDistributorFactory.createFeeDistributor(clientAddress)

        // wait for 2 blocks to avoid a prematute exit from the test
        await createFeeDistributorTxReceipt.wait(2)
    })

    // it("renounceOwnership should revert", async function () {
    //     await expect(feeDistributorFactory.renounceOwnership()).to.be.revertedWith(
    //         "DISABLED"
    //     )
    // })
})
