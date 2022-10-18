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

    it("createFeeDistributor can only be called with INSTANCE_CREATOR_ROLE and after setReferenceInstance", async function () {
        const feeDistributorFactory = await deployerFactoryFactory.deploy({gasLimit: 3000000})

        const inctanceCreatorSigner = await ethers.getSigner(inctanceCreator)
        const inctanceCreatorSignerFactoryFactory = new FeeDistributorFactory__factory(inctanceCreatorSigner)
        const factorySignedByInctanceCreator = inctanceCreatorSignerFactoryFactory.attach(feeDistributorFactory.address)

        await expect(factorySignedByInctanceCreator.createFeeDistributor(nobody)).to.be.revertedWith(
            `AccessControl: account ${inctanceCreator.toLowerCase()} is missing role ${INSTANCE_CREATOR_ROLE}`
        )

        await feeDistributorFactory.grantRole(INSTANCE_CREATOR_ROLE, inctanceCreator)

        await expect(factorySignedByInctanceCreator.createFeeDistributor(nobody)).to.be.revertedWith(
            `FeeDistributorFactory__ReferenceFeeDistributorNotSet`
        )

        const referenceInctanceSetterSigner = await ethers.getSigner(referenceInstanceSetter)
        const referenceInctanceFactoryFactory = new FeeDistributorFactory__factory(referenceInctanceSetterSigner)
        const factorySignedByReferenceInctanceSetter = referenceInctanceFactoryFactory.attach(feeDistributorFactory.address)

        await feeDistributorFactory.grantRole(REFERENCE_INSTANCE_SETTER_ROLE, referenceInstanceSetter)

        await expect(factorySignedByReferenceInctanceSetter.setReferenceInstance(nobody)).to.be.revertedWith(
            `FeeDistributorFactory__NotFeeDistributor(\"${nobody}\")`
        )

        const factory = new FeeDistributor__factory(deployerSigner)
        const feeDistributor = await factory.deploy(
            feeDistributorFactory.address,
            serviceAddress,
            servicePercent,
            {gasLimit: 3000000}
        )

        await expect(factorySignedByReferenceInctanceSetter.setReferenceInstance(feeDistributor.address)).to.emit(
            factorySignedByReferenceInctanceSetter,
            "ReferenceInstanceSet"
        )

        await expect(factorySignedByInctanceCreator.createFeeDistributor(ethers.constants.AddressZero)).to.be.revertedWith(
            `FeeDistributor__ZeroAddressClient`
        )

        await expect(factorySignedByInctanceCreator.createFeeDistributor(nobody)).to.emit(
            factorySignedByInctanceCreator,
            "FeeDistributorCreated"
        )
    })

    it("deployer should get DEFAULT_ADMIN_ROLE", async function () {
        const feeDistributorFactory = await deployerFactoryFactory.deploy({gasLimit: 3000000})

        const firstAdmin = await feeDistributorFactory.getRoleMember(DEFAULT_ADMIN_ROLE, 0)
        expect(firstAdmin).to.be.equal(deployerSigner.address)

        const adminCount = await feeDistributorFactory.getRoleMemberCount(DEFAULT_ADMIN_ROLE)
        expect(adminCount).to.be.equal(1)

        const hasRole = await feeDistributorFactory.hasRole(DEFAULT_ADMIN_ROLE, deployerSigner.address)
        expect(hasRole).to.be.true

        const noRole = await feeDistributorFactory.hasRole(DEFAULT_ADMIN_ROLE, nobody)
        expect(noRole).to.be.false
    })

    it("no roles are assigned after deployment (except admin)", async function () {
        const feeDistributorFactory = await deployerFactoryFactory.deploy({ gasLimit: 3000000 })

        const REFERENCE_INSTANCE_SETTER_ROLECount = await feeDistributorFactory.getRoleMemberCount(REFERENCE_INSTANCE_SETTER_ROLE)
        expect(REFERENCE_INSTANCE_SETTER_ROLECount).to.be.equal(0)

        const INSTANCE_CREATOR_ROLECount = await feeDistributorFactory.getRoleMemberCount(INSTANCE_CREATOR_ROLE)
        expect(INSTANCE_CREATOR_ROLECount).to.be.equal(0)

        const ASSET_RECOVERER_ROLECount = await feeDistributorFactory.getRoleMemberCount(ASSET_RECOVERER_ROLE)
        expect(ASSET_RECOVERER_ROLECount).to.be.equal(0)
    })

    it("cannot revoke the only admin", async function () {
        const feeDistributorFactory = await deployerFactoryFactory.deploy({gasLimit: 3000000})

        const adminCount = await feeDistributorFactory.getRoleMemberCount(DEFAULT_ADMIN_ROLE)
        expect(adminCount).to.be.equal(1)

        await expect(feeDistributorFactory.renounceRole(DEFAULT_ADMIN_ROLE, deployerSigner.address)).to.be.revertedWith(
            `PublicTokenRecoverer__CannotRevokeTheOnlyAdmin`
        )

        await expect(feeDistributorFactory.revokeRole(DEFAULT_ADMIN_ROLE, deployerSigner.address)).to.be.revertedWith(
            `PublicTokenRecoverer__CannotRevokeTheOnlyAdmin`
        )

        await feeDistributorFactory.grantRole(DEFAULT_ADMIN_ROLE, nobody)

        const adminCountAfterAdding = await feeDistributorFactory.getRoleMemberCount(DEFAULT_ADMIN_ROLE)
        expect(adminCountAfterAdding).to.be.equal(2)

        await feeDistributorFactory.renounceRole(DEFAULT_ADMIN_ROLE, deployerSigner.address)

        const adminCountAfterRemoving = await feeDistributorFactory.getRoleMemberCount(DEFAULT_ADMIN_ROLE)
        expect(adminCountAfterRemoving).to.be.equal(1)

        const deployerHasRole = await feeDistributorFactory.hasRole(DEFAULT_ADMIN_ROLE, deployerSigner.address)
        expect(deployerHasRole).to.be.false

        const newAdminHasRole = await feeDistributorFactory.hasRole(DEFAULT_ADMIN_ROLE, nobody)
        expect(newAdminHasRole).to.be.true
    })
})
