import { expect } from "chai"
import {ethers, getNamedAccounts} from "hardhat"
import {
    FeeDistributorFactory__factory,
    FeeDistributorFactory,
    IERC20__factory,
    IERC721__factory,
    IERC1155__factory,
    Oracle__factory,
    Oracle,
    OracleFeeDistributor__factory
} from "../../typechain-types"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"

describe("FeeDistributor", function () {

    const defaultClientBasisPoints =  9000;
    const clientBasisPoints =  7000;

    const clientAddress = "0x0000000000000000000000000000000000C0FFEE"

    let deployerSigner: SignerWithAddress
    let ownerSigner: SignerWithAddress
    let operatorSigner: SignerWithAddress
    let nobodySigner: SignerWithAddress

    let deployerFactory: OracleFeeDistributor__factory
    let ownerFactory: OracleFeeDistributor__factory
    let operatorFactory: OracleFeeDistributor__factory
    let nobodyFactory: OracleFeeDistributor__factory

    let feeDistributorFactory: FeeDistributorFactory
    let ownerFactoryFactory: FeeDistributorFactory__factory
    let oracleSignedByDeployer: Oracle

    let deployer: string
    let owner: string
    let operator: string
    let nobody : string
    let serviceAddress: string

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

        deployerFactory = new OracleFeeDistributor__factory(deployerSigner)
        ownerFactory = new OracleFeeDistributor__factory(ownerSigner)
        operatorFactory = new OracleFeeDistributor__factory(operatorSigner)
        nobodyFactory = new OracleFeeDistributor__factory(nobodySigner)

        // deploy factory contract
        const factoryFactory = new FeeDistributorFactory__factory(deployerSigner)
        feeDistributorFactory = await factoryFactory.deploy(defaultClientBasisPoints)

        ownerFactoryFactory = new FeeDistributorFactory__factory(ownerSigner)

        // deploy oracle contract
        oracleSignedByDeployer = await new Oracle__factory(deployerSigner).deploy()
    })

    it("should not be created with incorrect factory", async function () {
        const factory = new OracleFeeDistributor__factory(deployerSigner)

        await expect(factory.deploy(
            oracleSignedByDeployer.address,
            nobody,
            serviceAddress,
            {gasLimit: 30000000}
        )).to.be.revertedWith(
            `FeeDistributor__NotFactory("${nobody}")`
        )
    })

    it("should not be created with zero serviceAddress", async function () {
        const factory = new OracleFeeDistributor__factory(deployerSigner)

        await expect(factory.deploy(
            oracleSignedByDeployer.address,
            feeDistributorFactory.address,
            ethers.constants.AddressZero,
            {gasLimit: 1000000}
        )).to.be.revertedWith(
            `FeeDistributor__ZeroAddressService`
        )
    })

    it("should not be created with non-payable serviceAddress", async function () {
        const factory = new OracleFeeDistributor__factory(deployerSigner)

        await expect(factory.deploy(
            oracleSignedByDeployer.address,
            feeDistributorFactory.address,
            feeDistributorFactory.address,
            {gasLimit: 1000000}
        )).to.be.revertedWith(
            `FeeDistributor__ServiceCannotReceiveEther`
        )
    })

    it("should not be created with clientBasisPoints outside [0, 10000]", async function () {
        const factory = new OracleFeeDistributor__factory(deployerSigner)

        const feeDistributor = await factory.deploy(
            oracleSignedByDeployer.address,
            feeDistributorFactory.address,
            serviceAddress,
            {gasLimit: 30000000}
        );

        await expect(feeDistributorFactory.createFeeDistributor(
            feeDistributor.address,
            {recipient: clientAddress, basisPoints: 10001},
            {recipient: ethers.constants.AddressZero, basisPoints: 0},
            {gasLimit: 30000000}
        )).to.be.reverted

        await expect(feeDistributorFactory.createFeeDistributor(
            feeDistributor.address,
            {recipient: clientAddress, basisPoints: 10001},
            {recipient: ethers.constants.AddressZero, basisPoints: 0},
            {gasLimit: 30000000}
        )).to.throw
    })

    it("initialize should only be called by factory", async function () {
        const factory = new OracleFeeDistributor__factory(deployerSigner)

        const feeDistributor = await factory.deploy(
            oracleSignedByDeployer.address,
            feeDistributorFactory.address,
            serviceAddress,
            {gasLimit: 30000000}
        )

        await expect(feeDistributor.initialize(
            {recipient: nobody, basisPoints: clientBasisPoints},
            {recipient: ethers.constants.AddressZero, basisPoints: 0},
            {gasLimit: 30000000}
        )).to.be.reverted
    })

    it("deployer should get ownership", async function () {
        const factory = new OracleFeeDistributor__factory(deployerSigner)

        const feeDistributor = await factory.deploy(
            oracleSignedByDeployer.address,
            feeDistributorFactory.address,
            serviceAddress,
            {gasLimit: 30000000}
        )

        const feeDistributorOwner = await feeDistributor.owner()
        expect(feeDistributorOwner).to.be.equal(deployerSigner.address)
    })

    it("the owner of the reference instance should become the owner of a client instance", async function () {
        // deoply factory
        const deployerSignerFactory = new OracleFeeDistributor__factory(deployerSigner)

        // deoply reference instance
        const feeDistributorReferenceInstance = await deployerSignerFactory.deploy(
            oracleSignedByDeployer.address,
            feeDistributorFactory.address,
            serviceAddress,
            { gasLimit: 30000000 }
        )


        // create client instance
        const createFeeDistributorTx = await feeDistributorFactory.createFeeDistributor(
            feeDistributorReferenceInstance.address,
            {recipient: clientAddress, basisPoints: clientBasisPoints},
            {recipient: ethers.constants.AddressZero, basisPoints: 0},
            {gasLimit: 30000000}
        )
        const createFeeDistributorTxReceipt = await createFeeDistributorTx.wait();
        const event = createFeeDistributorTxReceipt?.events?.find(event => event.event === 'FeeDistributorFactory__FeeDistributorCreated');
        if (!event) {
            throw Error('No FeeDistributorFactory__FeeDistributorCreated found')
        }
        // retrieve client instance address from event
        const newFeeDistributorAddress = event.args?._newFeeDistributorAddress

        const feeDistributorSignedByDeployer = deployerSignerFactory.attach(newFeeDistributorAddress)

        const clientInstanceOwner = await feeDistributorSignedByDeployer.owner()
        expect(clientInstanceOwner).to.be.equal(deployerSigner.address)
    })

    it("only owner can recover tokens", async function () {
        // deoply factory
        const deployerSignerFactory = new OracleFeeDistributor__factory(deployerSigner)

        // deoply reference instance
        const feeDistributorReferenceInstance = await deployerSignerFactory.deploy(
            oracleSignedByDeployer.address,
            feeDistributorFactory.address,
            serviceAddress,
            { gasLimit: 30000000 }
        )

        // create client instance
        const createFeeDistributorTx = await feeDistributorFactory.createFeeDistributor(
            feeDistributorReferenceInstance.address,
            { recipient: clientAddress, basisPoints: clientBasisPoints },
            { recipient: ethers.constants.AddressZero, basisPoints: 0 },
            { gasLimit: 30000000 }
        )
        const createFeeDistributorTxReceipt = await createFeeDistributorTx.wait();
        const event = createFeeDistributorTxReceipt?.events?.find(event => event.event === 'FeeDistributorFactory__FeeDistributorCreated');
        if (!event) {
            throw Error('No FeeDistributorFactory__FeeDistributorCreated found')
        }
        // retrieve client instance address from event
        const newFeeDistributorAddress = event.args?._newFeeDistributorAddress;

        // ERC20
        // connect to WETH (ERC20)
        const erc20Amount = ethers.utils.parseEther('2')
        const WETHAddress = '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2'
        const erc20 = IERC20__factory.connect(WETHAddress, deployerSigner)
        // wrap ETH
        await deployerSigner.sendTransaction({ to: WETHAddress, value: erc20Amount })
        // transfer WETH tokens to factory
        await erc20.transfer(newFeeDistributorAddress, erc20Amount)

        // ERC721
        const erc721Owner = '0x25Fa18641B5344542130FD88BEc35F8e8b70571E'
        await ethers.provider.send("hardhat_impersonateAccount", [
            erc721Owner,
        ])
        const erc721OwnerSigner = await ethers.getSigner(erc721Owner)
        const erc721Address = '0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85'
        // connect to ERC721
        const erc721 = IERC721__factory.connect(erc721Address, erc721OwnerSigner)
        // transfer mock ERC721 tokens to factory
        const erc721TokenId = '44622439185867257881261797439596106106450414585054453795424630153829715268861'
        await erc721.transferFrom(erc721OwnerSigner.address, newFeeDistributorAddress, erc721TokenId, {gasLimit: 30000000})

        // ERC1155
        const erc1155Owner = '0x208833804d09cf965023f2bdb03d78e3056b4767'
        await ethers.provider.send("hardhat_impersonateAccount", [
            erc1155Owner,
        ])
        const erc1155OwnerSigner = await ethers.getSigner(erc1155Owner)
        const erc1155Address = '0xa2cd18be17bed47b4f5275a4f08f249b7d44edd5'
        // connect to ERC1155
        const erc1155 = IERC1155__factory.connect(erc1155Address, erc1155OwnerSigner)
        const erc1155TokenId = '1'
        const erc1155Amount = 1
        // transfer ERC1155 tokens to factory
        // there is no unsafe transfer in ERC1155
        await expect(erc1155.safeTransferFrom(erc1155OwnerSigner.address, newFeeDistributorAddress, erc1155TokenId, erc1155Amount, "0x"))
            .to.be.reverted

        const feeDistributorSignedByOwner = ownerFactory.attach(newFeeDistributorAddress)

        await expect(feeDistributorSignedByOwner.transferERC20(erc20.address, serviceAddress, erc20Amount))
            .to.be.reverted

        await expect(feeDistributorSignedByOwner.transferERC721(erc721.address, serviceAddress, erc721TokenId, {gasLimit: 30000000}))
            .to.be.reverted

        await feeDistributorFactory.transferOwnership(owner)
        const factorySignedByOwner = ownerFactoryFactory.attach(feeDistributorFactory.address)
        await factorySignedByOwner.acceptOwnership()

        await feeDistributorSignedByOwner.transferERC20(erc20.address, serviceAddress, erc20Amount)
        const recipientErc20Balance = await erc20.balanceOf(serviceAddress)
        expect(recipientErc20Balance).to.be.equal(erc20Amount)

        await feeDistributorSignedByOwner.transferERC721(erc721.address, serviceAddress, erc721TokenId, {gasLimit: 30000000})
        const recipientErc721Balance = await erc721.balanceOf(serviceAddress)
        expect(recipientErc721Balance).to.be.equal(1)
    })
})
