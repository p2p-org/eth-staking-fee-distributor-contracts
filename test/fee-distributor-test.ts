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
    let deployerSigner: SignerWithAddress

    // factory contract for deploying individual FeeDistributor contract instances for each user on demand
    let feeDistributorFactory: FeeDistributorFactory

    // P2P secure address (cold storage, multisig, etc.)
    const serviceAddress = "0x1234567890123456789012345678901234567890"

    // P2P should get 30% (subject to chioce at deploy time)
    const servicePercent =  30;

    // client should get 70% (subject to chioce at deploy time)
    const clientPercent = 100 - servicePercent;

    let deployer: string
    let referenceInstanceSetter: string
    let inctanceCreator: string
    let assetRecoverer: string
    let nobody : string

    before(async () => {
        const namedAccounts = await getNamedAccounts()
        deployer = namedAccounts.deployer
        referenceInstanceSetter = namedAccounts.referenceInstanceSetter
        inctanceCreator = namedAccounts.inctanceCreator
        assetRecoverer = namedAccounts.assetRecoverer
        nobody = namedAccounts.nobody

        deployerSigner = await ethers.getSigner(deployer)

        // deploy factory contract
        const factoryFactory = new FeeDistributorFactory__factory(deployerSigner)
        feeDistributorFactory = await factoryFactory.deploy({gasLimit: 3000000})
    })

    it("should not be created with incorrect factory", async function () {
        const factory = new FeeDistributor__factory(deployerSigner)

        await expect(factory.deploy(
            nobody,
            serviceAddress,
            servicePercent,
            {gasLimit: 1000000}
        )).to.be.revertedWith(
            `FeeDistributor__NotFactory("${nobody}")`
        )
    })
})
