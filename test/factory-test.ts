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

    // deployer, owner of contracts
    let deployerSigner: SignerWithAddress

    const DEFAULT_ADMIN_ROLE = ethers.constants.HashZero
    const REFERENCE_INSTANCE_SETTER_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("REFERENCE_INSTANCE_SETTER_ROLE"))
    const INSTANCE_CREATOR_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("INSTANCE_CREATOR_ROLE"))
    const ASSET_RECOVERER_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("ASSET_RECOVERER_ROLE"))

    const servicePercent = 30

    // factory contract for deploying individual FeeDistributor contract instances for each user on demand
    let factoryFactory: FeeDistributorFactory__factory

    let deployer: string
    let referenceInstanceSetter: string
    let inctanceCreator: string
    let assetRecoverer: string
    let nobody : string
    let serviceAddress: string

    before(async () => {
        const namedAccounts = await getNamedAccounts()
        deployer = namedAccounts.deployer
        referenceInstanceSetter = namedAccounts.referenceInstanceSetter
        inctanceCreator = namedAccounts.inctanceCreator
        assetRecoverer = namedAccounts.assetRecoverer
        nobody = namedAccounts.nobody
        serviceAddress = namedAccounts.serviceAddress

        deployerSigner = await ethers.getSigner(deployer)
        factoryFactory = new FeeDistributorFactory__factory(deployerSigner)
    })

    it("setReferenceInstance can only be called with REFERENCE_INSTANCE_SETTER_ROLE and with valid FeeDistributor", async function () {
        const feeDistributorFactory = await factoryFactory.deploy({gasLimit: 3000000})

        const referenceInctanceSetterSigner = await ethers.getSigner(referenceInstanceSetter)
        const referenceInctanceFactoryFactory = new FeeDistributorFactory__factory(referenceInctanceSetterSigner)
        const factorySignedByReferenceInctanceSetter = referenceInctanceFactoryFactory.attach(feeDistributorFactory.address)

        await expect(factorySignedByReferenceInctanceSetter.setReferenceInstance(nobody)).to.be.revertedWith(
            `AccessControl: account ${referenceInstanceSetter.toLowerCase()} is missing role ${REFERENCE_INSTANCE_SETTER_ROLE}`
        )

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
    })

    it("createFeeDistributor can only be called with INSTANCE_CREATOR_ROLE and after setReferenceInstance", async function () {
        const feeDistributorFactory = await factoryFactory.deploy({gasLimit: 3000000})

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
        const feeDistributorFactory = await factoryFactory.deploy({gasLimit: 3000000})

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
        const feeDistributorFactory = await factoryFactory.deploy({ gasLimit: 3000000 })

        const REFERENCE_INSTANCE_SETTER_ROLECount = await feeDistributorFactory.getRoleMemberCount(REFERENCE_INSTANCE_SETTER_ROLE)
        expect(REFERENCE_INSTANCE_SETTER_ROLECount).to.be.equal(0)

        const INSTANCE_CREATOR_ROLECount = await feeDistributorFactory.getRoleMemberCount(INSTANCE_CREATOR_ROLE)
        expect(INSTANCE_CREATOR_ROLECount).to.be.equal(0)

        const ASSET_RECOVERER_ROLECount = await feeDistributorFactory.getRoleMemberCount(ASSET_RECOVERER_ROLE)
        expect(ASSET_RECOVERER_ROLECount).to.be.equal(0)
    })

    it("cannot revoke the only admin", async function () {
        const feeDistributorFactory = await factoryFactory.deploy({gasLimit: 3000000})

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
