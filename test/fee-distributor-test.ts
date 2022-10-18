import { expect } from "chai"
import {ethers, getNamedAccounts} from "hardhat"
import {
    FeeDistributor__factory,
    FeeDistributorFactory__factory,
    FeeDistributor,
    FeeDistributorFactory, MockERC20__factory
} from "../typechain-types"
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
    const REFERENCE_INSTANCE_SETTER_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("REFERENCE_INSTANCE_SETTER_ROLE"))
    const INSTANCE_CREATOR_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("INSTANCE_CREATOR_ROLE"))

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

    it("an admin of the reference instance should become an admin of a client instance", async function () {
        // deoply factory
        const deployerSignerFactory = new FeeDistributor__factory(deployerSigner)

        // deoply reference instance
        const feeDistributorReferenceInstance = await deployerSignerFactory.deploy(
            feeDistributorFactory.address,
            serviceAddress,
            servicePercent,
            { gasLimit: 3000000 }
        )

        // grant oneself REFERENCE_INSTANCE_SETTER_ROLE
        await feeDistributorFactory.grantRole(REFERENCE_INSTANCE_SETTER_ROLE, deployerSigner.address)
        // set reference instance
        await feeDistributorFactory.setReferenceInstance(feeDistributorReferenceInstance.address)

        const clientAddress = "0x0000000000000000000000000000000000C0FFEE"
        // grant oneself INSTANCE_CREATOR_ROLE
        await feeDistributorFactory.grantRole(INSTANCE_CREATOR_ROLE, deployerSigner.address)
        // create client instance
        const createFeeDistributorTx = await feeDistributorFactory.createFeeDistributor(clientAddress)
        const createFeeDistributorTxReceipt = await createFeeDistributorTx.wait();
        const event = createFeeDistributorTxReceipt?.events?.find(event => event.event === 'FeeDistributorCreated');
        if (!event) {
            throw Error('No FeeDistributorCreated found')
        }
        // retrieve client instance address from event
        const newFeeDistributorAddrress = event.args?._newFeeDistributorAddrress

        const feeDistributorSignedByDeployer = deployerSignerFactory.attach(newFeeDistributorAddrress)

        const deployerHasRole = await feeDistributorSignedByDeployer.hasRole(DEFAULT_ADMIN_ROLE, deployerSigner.address)
        expect(deployerHasRole).to.be.true
    })

    it("only ASSET_RECOVERER_ROLE can recover tokens", async function () {
        // deoply factory
        const deployerSignerFactory = new FeeDistributor__factory(deployerSigner)

        // deoply reference instance
        const feeDistributorReferenceInstance = await deployerSignerFactory.deploy(
            feeDistributorFactory.address,
            serviceAddress,
            servicePercent,
            { gasLimit: 3000000 }
        )

        // grant oneself REFERENCE_INSTANCE_SETTER_ROLE
        await feeDistributorFactory.grantRole(REFERENCE_INSTANCE_SETTER_ROLE, deployerSigner.address)
        // set reference instance
        await feeDistributorFactory.setReferenceInstance(feeDistributorReferenceInstance.address)

        const clientAddress = "0x0000000000000000000000000000000000C0FFEE"
        // grant oneself INSTANCE_CREATOR_ROLE
        await feeDistributorFactory.grantRole(INSTANCE_CREATOR_ROLE, deployerSigner.address)
        // create client instance
        const createFeeDistributorTx = await feeDistributorFactory.createFeeDistributor(clientAddress)
        const createFeeDistributorTxReceipt = await createFeeDistributorTx.wait();
        const event = createFeeDistributorTxReceipt?.events?.find(event => event.event === 'FeeDistributorCreated');
        if (!event) {
            throw Error('No FeeDistributorCreated found')
        }
        // retrieve client instance address from event
        const newFeeDistributorAddrress = event.args?._newFeeDistributorAddrress;

        const mockERC20Factory = new MockERC20__factory(deployerSigner)
        const erc20Supply = ethers.utils.parseEther('100')
        // deploy mock ERC20
        const erc20 = await mockERC20Factory.deploy(erc20Supply)
        // transfer mock ERC20 tokens to client instance
        await erc20.transfer(newFeeDistributorAddrress, erc20Supply)

        const assetRecovererSigner = await ethers.getSigner(assetRecoverer)
        const assetRecovererSignerFactory = new FeeDistributor__factory(assetRecovererSigner)
        const feeDistributorSignedByAssetRecoverer = assetRecovererSignerFactory.attach(newFeeDistributorAddrress)

        await expect(feeDistributorSignedByAssetRecoverer.transferERC20(erc20.address, nobody, erc20Supply))
            .to.be.revertedWith(
            `AccessControl: account ${assetRecoverer.toLowerCase()} is missing role ${ASSET_RECOVERER_ROLE}`
            )

        const feeDistributorSignedByDeployer = deployerSignerFactory.attach(newFeeDistributorAddrress)

        await feeDistributorSignedByDeployer.grantRole(ASSET_RECOVERER_ROLE, assetRecoverer)

        await feeDistributorSignedByAssetRecoverer.transferERC20(erc20.address, nobody, erc20Supply)
        const recipientErc20Balance = await erc20.balanceOf(nobody)

        expect(recipientErc20Balance).to.be.equal(erc20Supply)
    })
})
