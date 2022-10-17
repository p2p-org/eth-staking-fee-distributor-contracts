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

    const DEFAULT_ADMIN_ROLE = ethers.constants.HashZero
    const ASSET_RECOVERER_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("ASSET_RECOVERER_ROLE"))

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
            {gasLimit: 3000000}
        )).to.be.revertedWith(
            `FeeDistributor__NotFactory("${nobody}")`
        )
    })

    it("should not be created with zero serviceAddress", async function () {
        const factory = new FeeDistributor__factory(deployerSigner)

        await expect(factory.deploy(
            feeDistributorFactory.address,
            ethers.constants.AddressZero,
            servicePercent,
            {gasLimit: 1000000}
        )).to.be.revertedWith(
            `FeeDistributor__ZeroAddressService`
        )
    })

    it("should not be created with servicePercent outside [0, 100]", async function () {
        const factory = new FeeDistributor__factory(deployerSigner)

        await expect(factory.deploy(
            feeDistributorFactory.address,
            serviceAddress,
            101,
            {gasLimit: 3000000}
        )).to.be.revertedWith(
            `FeeDistributor__InvalidServicePercent`
        )

        await expect(factory.deploy(
            feeDistributorFactory.address,
            serviceAddress,
            -1,
            {gasLimit: 3000000}
        )).to.throw
    })

    it("initialize should only be called by factory", async function () {
        const factory = new FeeDistributor__factory(deployerSigner)

        const feeDistributor = await factory.deploy(
            feeDistributorFactory.address,
            serviceAddress,
            servicePercent,
            {gasLimit: 3000000}
        )

        await expect(feeDistributor.initialize(
            nobody,{gasLimit: 1000000}
        )).to.be.revertedWith(
            `FeeDistributor__NotFactoryCalled`
        )
    })

    it("deployer should get DEFAULT_ADMIN_ROLE", async function () {
        const factory = new FeeDistributor__factory(deployerSigner)

        const feeDistributor = await factory.deploy(
            feeDistributorFactory.address,
            serviceAddress,
            servicePercent,
            {gasLimit: 3000000}
        )

        const firstAdmin = await feeDistributor.getRoleMember(DEFAULT_ADMIN_ROLE, 0)
        expect(firstAdmin).to.be.equal(deployerSigner.address)

        const adminCount = await feeDistributor.getRoleMemberCount(DEFAULT_ADMIN_ROLE)
        expect(adminCount).to.be.equal(1)

        const hasRole = await feeDistributor.hasRole(DEFAULT_ADMIN_ROLE, deployerSigner.address)
        expect(hasRole).to.be.true

        const noRole = await feeDistributor.hasRole(DEFAULT_ADMIN_ROLE, nobody)
        expect(noRole).to.be.false
    })

    it("ASSET_RECOVERER_ROLE not assigned after deployment", async function () {
        const factory = new FeeDistributor__factory(deployerSigner)

        const feeDistributor = await factory.deploy(
            feeDistributorFactory.address,
            serviceAddress,
            servicePercent,
            {gasLimit: 3000000}
        )

        const ASSET_RECOVERER_ROLECount = await feeDistributor.getRoleMemberCount(ASSET_RECOVERER_ROLE)
        expect(ASSET_RECOVERER_ROLECount).to.be.equal(0)
    })

    it("cannot revoke the only admin", async function () {
        const factory = new FeeDistributor__factory(deployerSigner)

        const feeDistributor = await factory.deploy(
            feeDistributorFactory.address,
            serviceAddress,
            servicePercent,
            {gasLimit: 3000000}
        )

        const adminCount = await feeDistributor.getRoleMemberCount(DEFAULT_ADMIN_ROLE)
        expect(adminCount).to.be.equal(1)

        await expect(feeDistributor.renounceRole(DEFAULT_ADMIN_ROLE, deployerSigner.address)).to.be.revertedWith(
            `PublicTokenRecoverer__CannotRevokeTheOnlyAdmin`
        )

        await expect(feeDistributor.revokeRole(DEFAULT_ADMIN_ROLE, deployerSigner.address)).to.be.revertedWith(
            `PublicTokenRecoverer__CannotRevokeTheOnlyAdmin`
        )

        await feeDistributor.grantRole(DEFAULT_ADMIN_ROLE, nobody)

        const adminCountAfterAdding = await feeDistributor.getRoleMemberCount(DEFAULT_ADMIN_ROLE)
        expect(adminCountAfterAdding).to.be.equal(2)

        await feeDistributor.renounceRole(DEFAULT_ADMIN_ROLE, deployerSigner.address)

        const adminCountAfterRemoving = await feeDistributor.getRoleMemberCount(DEFAULT_ADMIN_ROLE)
        expect(adminCountAfterRemoving).to.be.equal(1)

        const deployerHasRole = await feeDistributor.hasRole(DEFAULT_ADMIN_ROLE, deployerSigner.address)
        expect(deployerHasRole).to.be.false

        const newAdminHasRole = await feeDistributor.hasRole(DEFAULT_ADMIN_ROLE, nobody)
        expect(newAdminHasRole).to.be.true
    })
})
