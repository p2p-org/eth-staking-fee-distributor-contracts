import { expect } from "chai"
import {ethers, getNamedAccounts} from "hardhat"
import {
    FeeDistributor__factory,
    FeeDistributorFactory__factory,
    FeeDistributor,
    FeeDistributorFactory
} from '../typechain-types'
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"

describe("FeeDistributorFactory", function () {
    const servicePercent = 30

    let deployer: string
    let owner: string
    let operator: string
    let nobody : string
    let serviceAddress: string

    let deployerSigner: SignerWithAddress
    let ownerSigner: SignerWithAddress
    let operatorSigner: SignerWithAddress
    let nobodySigner: SignerWithAddress

    let deployerFactoryFactory: FeeDistributorFactory__factory
    let ownerFactoryFactory: FeeDistributorFactory__factory
    let operatorFactoryFactory: FeeDistributorFactory__factory
    let nobodyFactoryFactory: FeeDistributorFactory__factory

    before(async () => {
        const namedAccounts = await getNamedAccounts()

        deployer = namedAccounts.deployer
        owner = namedAccounts.owner
        operator = namedAccounts.operator
        nobody = namedAccounts.nobody
        serviceAddress = namedAccounts.serviceAddress

        deployerSigner = await ethers.getSigner(deployer)
        ownerSigner = await ethers.getSigner(owner)
        operatorSigner = await ethers.getSigner(operator)
        nobodySigner = await ethers.getSigner(nobody)

        deployerFactoryFactory = new FeeDistributorFactory__factory(deployerSigner)
        ownerFactoryFactory = new FeeDistributorFactory__factory(ownerSigner)
        operatorFactoryFactory = new FeeDistributorFactory__factory(operatorSigner)
        nobodyFactoryFactory = new FeeDistributorFactory__factory(nobodySigner)
    })

    it("setReferenceInstance can only be called by owner and with valid FeeDistributor", async function () {
        const deployerFactory = await deployerFactoryFactory.deploy({gasLimit: 3000000})

        const factorySignedByOwner = ownerFactoryFactory.attach(deployerFactory.address)

        await expect(factorySignedByOwner.setReferenceInstance(nobody)).to.be.revertedWith(
            `Ownable: caller is not the owner`
        )

        await deployerFactory.transferOwnership(owner)

        await expect(factorySignedByOwner.setReferenceInstance(nobody)).to.be.revertedWith(
            `FeeDistributorFactory__NotFeeDistributor`
        )

        const factory = new FeeDistributor__factory(ownerSigner)
        const feeDistributor = await factory.deploy(
            deployerFactory.address,
            serviceAddress,
            servicePercent,
            {gasLimit: 3000000}
        )

        await expect(factorySignedByOwner.setReferenceInstance(feeDistributor.address)).to.emit(
            factorySignedByOwner,
            "ReferenceInstanceSet"
        )
    })

    it("createFeeDistributor can only be called by operator and after setReferenceInstance", async function () {
        const deployerFactory = await deployerFactoryFactory.deploy({gasLimit: 3000000})

        const factorySignedByOwner = ownerFactoryFactory.attach(deployerFactory.address)

        await expect(factorySignedByOwner.setReferenceInstance(nobody)).to.be.revertedWith(
            `Ownable: caller is not the owner`
        )

        await deployerFactory.transferOwnership(owner)

        await expect(factorySignedByOwner.setReferenceInstance(nobody)).to.be.revertedWith(
            `FeeDistributorFactory__NotFeeDistributor`
        )

        const factory = new FeeDistributor__factory(ownerSigner)
        const feeDistributor = await factory.deploy(
            deployerFactory.address,
            serviceAddress,
            servicePercent,
            {gasLimit: 3000000}
        )

        await expect(factorySignedByOwner.setReferenceInstance(feeDistributor.address)).to.emit(
            factorySignedByOwner,
            "ReferenceInstanceSet"
        )

        const factorySignedByOperator = operatorFactoryFactory.attach(deployerFactory.address)

        await expect(factorySignedByOperator.createFeeDistributor(ethers.constants.AddressZero)).to.be.revertedWith(
            `Access__CallerNotOperator`
        )

        await factorySignedByOwner.transferOperator(operator)

        await expect(factorySignedByOperator.createFeeDistributor(ethers.constants.AddressZero)).to.be.revertedWith(
            `FeeDistributor__ZeroAddressClient`
        )

        await expect(factorySignedByOperator.createFeeDistributor(nobody)).to.emit(
            factorySignedByOperator,
            "FeeDistributorCreated"
        )
    })

    it("deployer should get ownership", async function () {
        const feeDistributorFactory = await deployerFactoryFactory.deploy({gasLimit: 3000000})

        const feeDistributorFactoryOwner = await feeDistributorFactory.owner()
        expect(feeDistributorFactoryOwner).to.be.equal(deployerSigner.address)
    })

    it("operator not assigned after deployment", async function () {
        const feeDistributorFactory = await deployerFactoryFactory.deploy({ gasLimit: 3000000 })

        const feeDistributorFactoryOperator = await feeDistributorFactory.operator()
        expect(feeDistributorFactoryOperator).to.be.equal(ethers.constants.AddressZero)
    })

    it("cannot renounce ownership", async function () {
        const feeDistributorFactory = await deployerFactoryFactory.deploy({gasLimit: 3000000})

        await expect(feeDistributorFactory.renounceOwnership()).to.be.revertedWith(
            `Access__CannotRenounceOwnership`
        )
    })
})
