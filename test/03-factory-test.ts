import { expect } from "chai"
import {ethers, getNamedAccounts} from "hardhat"
import {
    FeeDistributor__factory,
    FeeDistributorFactory__factory,
    FeeDistributorFactory, IERC20__factory, IERC721__factory, IERC1155__factory, Oracle, Oracle__factory
} from "../typechain-types"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"

describe("FeeDistributorFactory", function () {
    const defaultClientBasisPoints =  9000;
    const clientBasisPoints = 7000
    const referrerBasisPoints = 1000

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

    let oracleSignedByDeployer: Oracle

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

        // deploy oracle contract
        oracleSignedByDeployer = await new Oracle__factory(deployerSigner).deploy()
    })

    it("setReferenceInstance can only be called by owner and with valid FeeDistributor", async function () {
        const deployerFactory = await deployerFactoryFactory.deploy(defaultClientBasisPoints, {gasLimit: 30000000})

        const factorySignedByOwner = ownerFactoryFactory.attach(deployerFactory.address)

        await expect(factorySignedByOwner.setReferenceInstance(nobody)).to.be.revertedWith(
            `OwnableBase__CallerNotOwner`
        )

        await deployerFactory.transferOwnership(owner)
        await factorySignedByOwner.acceptOwnership()

        await expect(factorySignedByOwner.setReferenceInstance(nobody)).to.be.revertedWith(
            `FeeDistributorFactory__NotFeeDistributor`
        )

        const factory = new FeeDistributor__factory(ownerSigner)
        const feeDistributor = await factory.deploy(
            oracleSignedByDeployer.address,
            deployerFactory.address,
            serviceAddress,
            {gasLimit: 30000000}
        )

        await expect(factorySignedByOwner.setReferenceInstance(feeDistributor.address)).to.emit(
            factorySignedByOwner,
            "ReferenceInstanceSet"
        )
    })

    it("createFeeDistributor can only be called by operator or owner and after setReferenceInstance", async function () {
        const deployerFactory = await deployerFactoryFactory.deploy(defaultClientBasisPoints, {gasLimit: 30000000})

        const factorySignedByOwner = ownerFactoryFactory.attach(deployerFactory.address)

        await expect(factorySignedByOwner.setReferenceInstance(nobody)).to.be.revertedWith(
            `OwnableBase__CallerNotOwner`
        )

        await deployerFactory.transferOwnership(owner)
        await factorySignedByOwner.acceptOwnership()

        await expect(factorySignedByOwner.setReferenceInstance(nobody)).to.be.revertedWith(
            `FeeDistributorFactory__NotFeeDistributor`
        )

        const factory = new FeeDistributor__factory(ownerSigner)
        const feeDistributor = await factory.deploy(
            oracleSignedByDeployer.address,
            deployerFactory.address,
            serviceAddress,
            {gasLimit: 30000000}
        )

        await expect(factorySignedByOwner.setReferenceInstance(feeDistributor.address)).to.emit(
            factorySignedByOwner,
            "ReferenceInstanceSet"
        )

        const factorySignedByOperator = operatorFactoryFactory.attach(deployerFactory.address)

        await expect(factorySignedByOperator.createFeeDistributor(
            {recipient: ethers.constants.AddressZero, basisPoints: clientBasisPoints},
            {recipient: ethers.constants.AddressZero, basisPoints: 0},
        {clientOnlyClRewards: 0, firstValidatorId: 100500, validatorCount: 42},
        )).to.be.revertedWith(
            `FeeDistributorFactory__CallerNotAuthorized`
        )

        await expect(factorySignedByOwner.changeOperator(ethers.constants.AddressZero)).to.be.revertedWith(
            `Access__ZeroNewOperator`
        )

        await factorySignedByOwner.changeOperator(operator)

        await expect(factorySignedByOwner.changeOperator(operator)).to.be.revertedWith(
            `Access__SameOperator`
        )

        await expect(factorySignedByOperator.createFeeDistributor(
            {recipient: ethers.constants.AddressZero, basisPoints: clientBasisPoints},
            {recipient: ethers.constants.AddressZero, basisPoints: 0},
            {clientOnlyClRewards: 0, firstValidatorId: 100500, validatorCount: 42},
        )).to.be.revertedWith(
            `FeeDistributor__ZeroAddressClient`
        )

        await expect(factorySignedByOperator.createFeeDistributor(
            {recipient: serviceAddress, basisPoints: clientBasisPoints},
            {recipient: ethers.constants.AddressZero, basisPoints: 0},
            {clientOnlyClRewards: 0, firstValidatorId: 100500, validatorCount: 42},
        )).to.be.revertedWith(
            `FeeDistributor__ClientAddressEqualsService`
        )

        await expect(factorySignedByOperator.createFeeDistributor(
            {recipient: deployerFactory.address, basisPoints: clientBasisPoints},
            {recipient: ethers.constants.AddressZero, basisPoints: 0},
            {clientOnlyClRewards: 0, firstValidatorId: 100500, validatorCount: 42},
        )).to.be.revertedWith(
            `FeeDistributor__ClientCannotReceiveEther`
        )

        await expect(factorySignedByOperator.createFeeDistributor(
            {recipient: nobody, basisPoints: clientBasisPoints},
            {recipient: ethers.constants.AddressZero, basisPoints: 0},
            {clientOnlyClRewards: 0, firstValidatorId: 100500, validatorCount: 42},
        )).to.emit(
            factorySignedByOperator,
            "FeeDistributorCreated"
        )

        await expect(factorySignedByOwner.createFeeDistributor(
            {recipient: nobody, basisPoints: clientBasisPoints},
            {recipient: ethers.constants.AddressZero, basisPoints: 0},
            {clientOnlyClRewards: 0, firstValidatorId: 100500, validatorCount: 42},
        )).to.emit(
            factorySignedByOperator,
            "FeeDistributorCreated"
        )
    })

    it("deployer should get ownership", async function () {
        const feeDistributorFactory = await deployerFactoryFactory.deploy(defaultClientBasisPoints, {gasLimit: 30000000})

        const feeDistributorFactoryOwner = await feeDistributorFactory.owner()
        expect(feeDistributorFactoryOwner).to.be.equal(deployerSigner.address)
    })

    it("operator not assigned after deployment", async function () {
        const feeDistributorFactory = await deployerFactoryFactory.deploy(defaultClientBasisPoints, { gasLimit: 30000000 })

        const feeDistributorFactoryOperator = await feeDistributorFactory.operator()
        expect(feeDistributorFactoryOperator).to.be.equal(ethers.constants.AddressZero)
    })

    it("owner can dismiss operator", async function () {
        const deployerFactory = await deployerFactoryFactory.deploy(defaultClientBasisPoints, {gasLimit: 30000000})

        await deployerFactory.changeOperator(operator)
        const operatorAfterSetting = await deployerFactory.operator()
        expect(operatorAfterSetting).to.be.equal(operator)

        const factorySignedByOwner = ownerFactoryFactory.attach(deployerFactory.address)

        await expect(factorySignedByOwner.dismissOperator()).to.be.revertedWith(
            `OwnableBase__CallerNotOwner`
        )

        await deployerFactory.transferOwnership(owner)
        await factorySignedByOwner.acceptOwnership()

        await factorySignedByOwner.dismissOperator()
        const operatorAfterDismissing = await deployerFactory.operator()
        expect(operatorAfterDismissing).to.be.equal(ethers.constants.AddressZero)
    })

    it("only owner can recover tokens and ether", async function () {
        // deoply factory
        const feeDistributorFactory = await deployerFactoryFactory.deploy(defaultClientBasisPoints, {gasLimit: 30000000})

        // ERC20
        // connect to WETH (ERC20)
        const erc20Amount = ethers.utils.parseEther('2')
        const WETHAddress = '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2'
        const erc20 = IERC20__factory.connect(WETHAddress, deployerSigner)
        // wrap ETH
        await deployerSigner.sendTransaction({to: WETHAddress, value: erc20Amount})
        // transfer WETH tokens to factory
        await erc20.transfer(feeDistributorFactory.address, erc20Amount)

        // ERC721
        const erc721Owner = '0x25Fa18641B5344542130FD88BEc35F8e8b70571E'
        await ethers.provider.send("hardhat_impersonateAccount", [
            erc721Owner,
        ])
        const erc721OwnerSigner = await ethers.getSigner(erc721Owner)
        const erc721Address = '0xE42caD6fC883877A76A26A16ed92444ab177E306'
        // connect to ERC721
        const erc721 = IERC721__factory.connect(erc721Address, erc721OwnerSigner)
        // transfer mock ERC721 tokens to factory
        const erc721TokenId = 20184
        await erc721.transferFrom(erc721OwnerSigner.address, feeDistributorFactory.address, erc721TokenId, {gasLimit: 30000000})

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
        await expect(erc1155.safeTransferFrom(erc1155OwnerSigner.address, feeDistributorFactory.address, erc1155TokenId, erc1155Amount, "0x"))
            .to.be.revertedWith(
                `ERC1155: transfer to non ERC1155Receiver implementer`
            )

        // Ether
        const etherAmount = ethers.utils.parseEther('2')
        // cannot transfer ether to factory
        await expect(deployerSigner.sendTransaction({to: feeDistributorFactory.address, value: etherAmount}))
            .to.be.revertedWith(
                `Transaction reverted: function selector was not recognized and there's no fallback nor receive function`
            )

        // push ether to the factory forcefully by mining (staking, whatever)
        await ethers.provider.send("hardhat_setCoinbase", [
            feeDistributorFactory.address,
        ])
        // simulate producing a new block so that the factory can get its rewards
        await ethers.provider.send("evm_mine", [])

        const factorySignedByOwner = ownerFactoryFactory.attach(feeDistributorFactory.address)

        await expect(factorySignedByOwner.transferERC20(erc20.address, nobody, erc20Amount))
            .to.be.revertedWith(
                `OwnableBase__CallerNotOwner`
            )

        await expect(factorySignedByOwner.transferERC721(erc721.address, nobody, erc721TokenId, "0x", {gasLimit: 30000000}))
            .to.be.revertedWith(
                `OwnableBase__CallerNotOwner`
            )

        await expect(factorySignedByOwner.transferEther(nobody, etherAmount))
            .to.be.revertedWith(
                `OwnableBase__CallerNotOwner`
            )

        await feeDistributorFactory.transferOwnership(owner)
        await factorySignedByOwner.acceptOwnership()

        await factorySignedByOwner.transferERC20(erc20.address, nobody, erc20Amount)
        const recipientErc20Balance = await erc20.balanceOf(nobody)
        expect(recipientErc20Balance).to.be.equal(erc20Amount)

        await factorySignedByOwner.transferERC721(erc721.address, nobody, erc721TokenId, "0x", {gasLimit: 30000000})
        const recipientErc721Balance = await erc721.balanceOf(nobody)
        expect(recipientErc721Balance).to.be.equal(1)

        const nobodyBalanceBefore = await ethers.provider.getBalance(nobody)
        await factorySignedByOwner.transferEther(nobody, etherAmount)
        const nobodyBalanceAfter = await ethers.provider.getBalance(nobody)
        expect(nobodyBalanceAfter.sub(nobodyBalanceBefore)).to.be.equal(etherAmount)
    })
})
