import { expect } from "chai"
import {ethers, getNamedAccounts} from "hardhat"
import {
    FeeDistributor__factory,
    FeeDistributorFactory__factory,
    FeeDistributor,
    FeeDistributorFactory
} from '../typechain-types'
import { SignerWithAddress } from "hardhat-deploy-ethers/signers"

describe("FeeDistributor", function () {
    let signer: SignerWithAddress

    let feeDistributorFactory: FeeDistributorFactory
    let factoryFactory: FeeDistributorFactory__factory

    let feeDistributor: FeeDistributor
    let factory: FeeDistributor__factory

    const serviceAddress = "0x1234567890123456789012345678901234567890"

    before(async () => {
        const { deployer } = await getNamedAccounts()
        signer = await ethers.getSigner(deployer)

        factoryFactory = new FeeDistributorFactory__factory(signer)
        feeDistributorFactory = await factoryFactory.deploy()

        factory = new FeeDistributor__factory(signer)
        feeDistributor = await factory.deploy(
            feeDistributorFactory.address,
            deployer,
            serviceAddress,
            30,
            70
        )

        await feeDistributorFactory.initialize(feeDistributor.address)
    })

    it("distributes fees", async function () {
        try {
            const filter = {
                address: feeDistributorFactory.address,
                topics: [
                    ethers.utils.id("FeeDistributorCreated(address)")
                ]
            }
            ethers.provider.on(filter, async (log, event) => {
                console.log('FeeDistributorCreated event start')
                console.log(log)
                console.log(event)

                const newlyCreatedFeeDistributorAddress = "0xBEEF"
                const feeOrMev = ethers.utils.parseEther("42")

                const transactionResponse = await signer.sendTransaction(
                    {
                        to: newlyCreatedFeeDistributorAddress,
                        value: feeOrMev,
                        gasLimit: 21000
                    }
                )
                await transactionResponse.wait(1)

                console.log('FeeDistributorCreated event end')
            })

            const clientAddress = "0xC0FFEE"
            const createFeeDistributorTxReceipt = await feeDistributorFactory.createFeeDistributor(clientAddress)
            await createFeeDistributorTxReceipt.wait(1)
        } catch (err) {
            console.log(err)
        }
    })
})
