import { expect } from "chai"
import {ethers, getNamedAccounts} from "hardhat"
import {
    FeeDistributor__factory,
    FeeDistributorFactory__factory,
    FeeDistributor,
    FeeDistributorFactory, IERC20__factory, IERC721__factory, IERC1155__factory
} from "../typechain-types"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"

describe("FeeDistributor", function () {

    // P2P should get 30% (subject to chioce at deploy time)
    const serviceBasisPoints =  3000;

    const clientAddress = "0x0000000000000000000000000000000000C0FFEE"

    let deployerSigner: SignerWithAddress
    let ownerSigner: SignerWithAddress
    let operatorSigner: SignerWithAddress
    let nobodySigner: SignerWithAddress

    let deployerFactory: FeeDistributor__factory
    let ownerFactory: FeeDistributor__factory
    let operatorFactory: FeeDistributor__factory
    let nobodyFactory: FeeDistributor__factory

    let feeDistributorFactory: FeeDistributorFactory

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

        deployerFactory = new FeeDistributor__factory(deployerSigner)
        ownerFactory = new FeeDistributor__factory(ownerSigner)
        operatorFactory = new FeeDistributor__factory(operatorSigner)
        nobodyFactory = new FeeDistributor__factory(nobodySigner)

        // deploy factory contract
        const factoryFactory = new FeeDistributorFactory__factory(deployerSigner)
        feeDistributorFactory = await factoryFactory.deploy({gasLimit: 3000000})
    })

    it("should not be created with incorrect factory", async function () {
        const factory = new FeeDistributor__factory(deployerSigner)

        await expect(factory.deploy(
            nobody,
            serviceAddress,
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
            {gasLimit: 1000000}
        )).to.be.revertedWith(
            `FeeDistributor__ZeroAddressService`
        )
    })

    it("should not be created with serviceBasisPoints outside [0, 10000]", async function () {
        const factory = new FeeDistributor__factory(deployerSigner)

        const feeDistributor = await factory.deploy(
            feeDistributorFactory.address,
            serviceAddress,
            {gasLimit: 3000000}
        );

        await feeDistributorFactory.setReferenceInstance(feeDistributor.address)

        await expect(feeDistributorFactory.createFeeDistributor(
            clientAddress,
            10001,
            {gasLimit: 3000000}
        )).to.be.revertedWith(
            `FeeDistributor__InvalidServiceBasisPoints`
        )

        await expect(feeDistributorFactory.createFeeDistributor(
            clientAddress,
            10001,
            {gasLimit: 3000000}
        )).to.throw
    })

    it("initialize should only be called by factory", async function () {
        const factory = new FeeDistributor__factory(deployerSigner)

        const feeDistributor = await factory.deploy(
            feeDistributorFactory.address,
            serviceAddress,
            {gasLimit: 3000000}
        )

        await expect(feeDistributor.initialize(
            nobody,
            serviceBasisPoints,
            {gasLimit: 1000000}
        )).to.be.revertedWith(
            `FeeDistributor__NotFactoryCalled`
        )
    })

    it("deployer should get ownership", async function () {
        const factory = new FeeDistributor__factory(deployerSigner)

        const feeDistributor = await factory.deploy(
            feeDistributorFactory.address,
            serviceAddress,
            {gasLimit: 3000000}
        )

        const feeDistributorOwner = await feeDistributor.owner()
        expect(feeDistributorOwner).to.be.equal(deployerSigner.address)
    })

    it("the owner of the reference instance should become the owner of a client instance", async function () {
        // deoply factory
        const deployerSignerFactory = new FeeDistributor__factory(deployerSigner)

        // deoply reference instance
        const feeDistributorReferenceInstance = await deployerSignerFactory.deploy(
            feeDistributorFactory.address,
            serviceAddress,
            { gasLimit: 3000000 }
        )

        // set reference instance
        await feeDistributorFactory.setReferenceInstance(feeDistributorReferenceInstance.address)


        // create client instance
        const createFeeDistributorTx = await feeDistributorFactory.createFeeDistributor(clientAddress, serviceBasisPoints)
        const createFeeDistributorTxReceipt = await createFeeDistributorTx.wait();
        const event = createFeeDistributorTxReceipt?.events?.find(event => event.event === 'FeeDistributorCreated');
        if (!event) {
            throw Error('No FeeDistributorCreated found')
        }
        // retrieve client instance address from event
        const newFeeDistributorAddress = event.args?._newFeeDistributorAddress

        const feeDistributorSignedByDeployer = deployerSignerFactory.attach(newFeeDistributorAddress)

        const clientInstanceOwner = await feeDistributorSignedByDeployer.owner()
        expect(clientInstanceOwner).to.be.equal(deployerSigner.address)
    })

    it("only owner can recover tokens", async function () {
        // deoply factory
        const deployerSignerFactory = new FeeDistributor__factory(deployerSigner)

        // deoply reference instance
        const feeDistributorReferenceInstance = await deployerSignerFactory.deploy(
            feeDistributorFactory.address,
            serviceAddress,
            { gasLimit: 3000000 }
        )

        // set reference instance
        await feeDistributorFactory.setReferenceInstance(feeDistributorReferenceInstance.address)

        // create client instance
        const createFeeDistributorTx = await feeDistributorFactory.createFeeDistributor(clientAddress, serviceBasisPoints)
        const createFeeDistributorTxReceipt = await createFeeDistributorTx.wait();
        const event = createFeeDistributorTxReceipt?.events?.find(event => event.event === 'FeeDistributorCreated');
        if (!event) {
            throw Error('No FeeDistributorCreated found')
        }
        // retrieve client instance address from event
        const newFeeDistributorAddress = event.args?._newFeeDistributorAddress;

        // ERC20
        // connect to WETH (ERC20)
        const erc20Amount = ethers.utils.parseEther('2')
        const WETHAddress = '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2'
        const erc20 = IERC20__factory.connect(WETHAddress, deployerSigner)
        // wrap ETH
        await deployerSigner.sendTransaction({to: WETHAddress, value: erc20Amount})
        // transfer WETH tokens to factory
        await erc20.transfer(newFeeDistributorAddress, erc20Amount)

        // ERC721
        const erc721Owner = '0xEBbfaE088c8643ee4Dd4186d703bE6aC8b1AE7D6'
        await ethers.provider.send("hardhat_impersonateAccount", [
            erc721Owner,
        ])
        const erc721OwnerSigner = await ethers.getSigner(erc721Owner)
        const erc721Address = '0xb7f7f6c52f2e2fdb1963eab30438024864c313f6'
        // connect to ERC721
        const erc721 = IERC721__factory.connect(erc721Address, erc721OwnerSigner)
        // transfer mock ERC721 tokens to factory
        const erc721TokenId = 1117
        await erc721.transferFrom(erc721OwnerSigner.address, newFeeDistributorAddress, erc721TokenId)

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
            .to.be.revertedWith(
                `ERC1155: transfer to non ERC1155Receiver implementer`
            )

        const feeDistributorSignedByOwner = ownerFactory.attach(newFeeDistributorAddress)

        await expect(feeDistributorSignedByOwner.transferERC20(erc20.address, serviceAddress, erc20Amount))
            .to.be.revertedWith(
                `OwnableBase__CallerNotOwner`
            )

        await expect(feeDistributorSignedByOwner.transferERC721(erc721.address, serviceAddress, erc721TokenId, "0x"))
            .to.be.revertedWith(
                `OwnableBase__CallerNotOwner`
            )

        await feeDistributorFactory.transferOwnership(owner)

        await feeDistributorSignedByOwner.transferERC20(erc20.address, serviceAddress, erc20Amount)
        const recipientErc20Balance = await erc20.balanceOf(serviceAddress)
        expect(recipientErc20Balance).to.be.equal(erc20Amount)

        await feeDistributorSignedByOwner.transferERC721(erc721.address, serviceAddress, erc721TokenId, "0x")
        const recipientErc721Balance = await erc721.balanceOf(serviceAddress)
        expect(recipientErc721Balance).to.be.equal(1)
    })
})
