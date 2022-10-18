import { expect } from "chai"
import {ethers, getNamedAccounts} from "hardhat"
import {
    FeeDistributor__factory,
    FeeDistributorFactory__factory,
    FeeDistributor,
    FeeDistributorFactory, MockERC20__factory, MockERC721__factory, MockERC1155__factory
} from "../typechain-types"
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

    it("only owner can recover tokens", async function () {
        // deoply factory
        const feeDistributorFactory = await deployerFactoryFactory.deploy({gasLimit: 3000000})

        // ERC20
        const mockERC20Factory = new MockERC20__factory(deployerSigner)
        const erc20Supply = ethers.utils.parseEther('100')
        // deploy mock ERC20
        const erc20 = await mockERC20Factory.deploy(erc20Supply)
        // transfer mock ERC20 tokens to client instance
        await erc20.transfer(feeDistributorFactory.address, erc20Supply)

        // ERC721
        const mockERC721Factory = new MockERC721__factory(deployerSigner)
        // deploy mock ERC721
        const erc721 = await mockERC721Factory.deploy()
        // transfer mock ERC721 tokens to client instance
        const erc721TokenId = 0
        await erc721.transferFrom(deployerSigner.address, feeDistributorFactory.address, erc721TokenId)

        // ERC1155
        const mockERC1155Factory = new MockERC1155__factory(deployerSigner)
        const erc1155TokenId = 0
        const erc1155Amount = 1
        // deploy mock ERC1155
        const erc1155 = await mockERC1155Factory.deploy(erc1155TokenId, erc1155Amount)
        // transfer mock ERC1155 tokens to client instance
        // there is no unsafe transfer in ERC1155
        await expect(erc1155.safeTransferFrom(deployerSigner.address, feeDistributorFactory.address, erc1155TokenId, erc1155Amount, "0x"))
            .to.be.revertedWith(
                `ERC1155: transfer to non ERC1155Receiver implementer`
            )

        const factorySignedByOwner = ownerFactoryFactory.attach(feeDistributorFactory.address)

        await expect(factorySignedByOwner.transferERC20(erc20.address, nobody, erc20Supply))
            .to.be.revertedWith(
                `Ownable: caller is not the owner`
            )

        await expect(factorySignedByOwner.transferERC721(erc721.address, nobody, erc721TokenId, "0x"))
            .to.be.revertedWith(
                `Ownable: caller is not the owner`
            )

        await feeDistributorFactory.transferOwnership(owner)

        await factorySignedByOwner.transferERC20(erc20.address, nobody, erc20Supply)
        const recipientErc20Balance = await erc20.balanceOf(nobody)

        await factorySignedByOwner.transferERC721(erc721.address, nobody, erc721TokenId, "0x")
        const recipientErc721Balance = await erc721.balanceOf(nobody)

        expect(recipientErc20Balance).to.be.equal(erc20Supply)
        expect(recipientErc721Balance).to.be.equal(1)
    })
})
