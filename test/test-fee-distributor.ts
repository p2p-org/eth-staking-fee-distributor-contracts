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
    let signer: SignerWithAddress
    let feeDistributorFactory: FeeDistributorFactory
    const serviceAddress = "0x1234567890123456789012345678901234567890"

    before(async () => {
        const { deployer } = await getNamedAccounts()
        signer = await ethers.getSigner(deployer)

        const factoryFactory = new FeeDistributorFactory__factory(signer)
        feeDistributorFactory = await factoryFactory.deploy()

        const factory = new FeeDistributor__factory(signer)
        const feeDistributor = await factory.deploy(
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
            const filter = feeDistributorFactory.filters["FeeDistributorCreated(address)"]()

            const clientAddress = "0x0000000000000000000000000000000000C0FFEE"

            ethers.provider.on(filter, async (log) => {
                try {
                    console.log('FeeDistributorCreated event start')

                    const parsedLog = feeDistributorFactory.interface.parseLog(log);
                    const newlyCreatedFeeDistributorAddress = parsedLog.args.newFeeDistributorAddrress

                    // @ts-ignore
                    const feeDistributor: FeeDistributor = await ethers.getContractAt(
                        "FeeDistributor",
                        newlyCreatedFeeDistributorAddress,
                        signer
                    )

                    await ethers.provider.send("hardhat_setCoinbase", [
                        newlyCreatedFeeDistributorAddress,
                    ])
                    await ethers.provider.send("evm_mine", [])

                    await feeDistributor.withdraw()

                    const serviceAddressBalance = await ethers.provider.getBalance(serviceAddress)
                    console.log(serviceAddressBalance.toString())

                    const clientAddressBalance = await ethers.provider.getBalance(clientAddress)
                    console.log(clientAddressBalance.toString())

                    console.log('FeeDistributorCreated event end')
                } catch (err) {
                    console.log(err)
                }
            })

            const createFeeDistributorTxReceipt = await feeDistributorFactory.createFeeDistributor(clientAddress)
            await createFeeDistributorTxReceipt.wait(2)
        } catch (err) {
            console.log(err)
        }
    })
})
