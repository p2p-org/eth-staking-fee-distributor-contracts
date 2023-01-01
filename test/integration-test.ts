import { expect } from "chai"
import {ethers, getNamedAccounts} from "hardhat"
import {
    FeeDistributor__factory,
    FeeDistributorFactory__factory,
    FeeDistributorFactory, MockAlteringReceive__factory
} from "../typechain-types"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"

describe("Integration", function () {

    // client should get 70% (subject to chioce at deploy time)
    const clientBasisPoints = 7000;

    // referrer should get 10% (subject to chioce at deploy time)
    const referrerBasisPoints =  1000;

    // P2P should get 20% (subject to chioce at deploy time)
    const serviceBasisPoints =  10000 - clientBasisPoints - referrerBasisPoints;

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

    beforeEach(async () => {
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

    it("distributes fees", async function () {
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

        // set an operator to create a client instance
        await feeDistributorFactory.changeOperator(operator)

        const operatorSignerFactory = new FeeDistributorFactory__factory(operatorSigner)
        const operatorFeeDistributorFactory = operatorSignerFactory.attach(feeDistributorFactory.address)

        const clientAddress = "0x0000000000000000000000000000000000C0FFEE"
        // create client instance
        const createFeeDistributorTx = await operatorFeeDistributorFactory.createFeeDistributor(
            {recipient: clientAddress, basisPoints: clientBasisPoints},
            {recipient: nobody, basisPoints: referrerBasisPoints},
        )
        const createFeeDistributorTxReceipt = await createFeeDistributorTx.wait();
        const event = createFeeDistributorTxReceipt?.events?.find(event => event.event === 'FeeDistributorCreated');
        if (!event) {
            throw Error('No FeeDistributorCreated found')
        }
        // retrieve client instance address from event
        const newlyCreatedFeeDistributorAddress = event.args?._newFeeDistributorAddress

        // set the newly created FeeDistributor contract as coinbase (block rewards recipient)
        // In the real world this will be done in a validator's settings
        await ethers.provider.send("hardhat_setCoinbase", [
            newlyCreatedFeeDistributorAddress,
        ])

        // simulate producing a new block so that our FeeDistributor contract can get its rewards
        await ethers.provider.send("evm_mine", [])

        // attach to the FeeDistributor contract with the owner (signer)
        const feeDistributorSignedByDeployer = deployerSignerFactory.attach(newlyCreatedFeeDistributorAddress)

        const serviceAddressBalanceBefore = await ethers.provider.getBalance(serviceAddress)

        // call withdraw
        await feeDistributorSignedByDeployer.withdraw()

        const totalBlockReward = ethers.utils.parseEther('2')

        // get service address balance
        const serviceAddressBalance = await ethers.provider.getBalance(serviceAddress)

        // make sure P2P (service) got its share
        expect(serviceAddressBalance.sub(serviceAddressBalanceBefore)).to.equal(totalBlockReward.mul(serviceBasisPoints).div(10000))

        // get client address balance
        const clientAddressBalance = await ethers.provider.getBalance(clientAddress)

        // make sure client got its share
        expect(clientAddressBalance).to.equal(totalBlockReward.mul(clientBasisPoints).div(10000))
    })

    it("recoverEther should simply withdraw in a normal case", async function () {
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

        // set an operator to create a client instance
        await feeDistributorFactory.changeOperator(operator)

        const operatorSignerFactory = new FeeDistributorFactory__factory(operatorSigner)
        const operatorFeeDistributorFactory = operatorSignerFactory.attach(feeDistributorFactory.address)

        const clientAddress = "0x0000000000000000000000000000000000C0FFEE"
        // create client instance
        const createFeeDistributorTx = await operatorFeeDistributorFactory.createFeeDistributor(
            {recipient: clientAddress, basisPoints: clientBasisPoints},
            {recipient: nobody, basisPoints: referrerBasisPoints},
        )
        const createFeeDistributorTxReceipt = await createFeeDistributorTx.wait();
        const event = createFeeDistributorTxReceipt?.events?.find(event => event.event === 'FeeDistributorCreated');
        if (!event) {
            throw Error('No FeeDistributorCreated found')
        }
        // retrieve client instance address from event
        const newlyCreatedFeeDistributorAddress = event.args?._newFeeDistributorAddress

        // set the newly created FeeDistributor contract as coinbase (block rewards recipient)
        // In the real world this will be done in a validator's settings
        await ethers.provider.send("hardhat_setCoinbase", [
            newlyCreatedFeeDistributorAddress,
        ])

        // simulate producing a new block so that our FeeDistributor contract can get its rewards
        await ethers.provider.send("evm_mine", [])

        // attach to the FeeDistributor contract with the owner (signer)
        const feeDistributorSignedByDeployer = deployerSignerFactory.attach(newlyCreatedFeeDistributorAddress)

        const serviceAddressBalanceBefore = await ethers.provider.getBalance(serviceAddress)

        const clientAddressBalanceBefore = await ethers.provider.getBalance(clientAddress)

        // call recoverEther instead of withdraw
        const recoverEtherTx = await feeDistributorSignedByDeployer.recoverEther(nobody)
        const recoverEtherTxReceipt = await recoverEtherTx.wait()

        const totalBlockReward = ethers.utils.parseEther('2')

        // get service address balance
        const serviceAddressBalance = await ethers.provider.getBalance(serviceAddress)

        // make sure P2P (service) got its share
        expect(serviceAddressBalance.sub(serviceAddressBalanceBefore)).to.equal(totalBlockReward.mul(serviceBasisPoints).div(10000))

        // get client address balance
        const clientAddressBalance = await ethers.provider.getBalance(clientAddress)

        // make sure client got its share
        expect(clientAddressBalance.sub(clientAddressBalanceBefore)).to.equal(totalBlockReward.mul(clientBasisPoints).div(10000))

        // no recovery should happen if the normal withdraw completed successfully
        const EtherRecoveredEvent = recoverEtherTxReceipt?.events?.find(event => event.event === 'EtherRecovered')
        const EtherRecoveryFailedEvent = recoverEtherTxReceipt?.events?.find(event => event.event === 'EtherRecoveryFailed')
        expect(!!EtherRecoveredEvent).to.be.false
        expect(!!EtherRecoveryFailedEvent).to.be.false
    })

    it("recoverEther should recover ether unclaimed during withdraw", async function () {
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

        // set an operator to create a client instance
        await feeDistributorFactory.changeOperator(operator)

        const operatorSignerFactory = new FeeDistributorFactory__factory(operatorSigner)
        const operatorFeeDistributorFactory = operatorSignerFactory.attach(feeDistributorFactory.address)

        const mockAlteringReceiveFactory = new MockAlteringReceive__factory(deployerSigner)
        const mockAlteringReceive = await mockAlteringReceiveFactory.deploy()
        const clientAddress = mockAlteringReceive.address

        // create client instance
        const createFeeDistributorTx = await operatorFeeDistributorFactory.createFeeDistributor(
            {recipient: clientAddress, basisPoints: clientBasisPoints},
            {recipient: nobody, basisPoints: referrerBasisPoints},
        )
        const createFeeDistributorTxReceipt = await createFeeDistributorTx.wait()
        const event = createFeeDistributorTxReceipt?.events?.find(event => event.event === 'FeeDistributorCreated');
        if (!event) {
            throw Error('No FeeDistributorCreated found')
        }
        // retrieve client instance address from event
        const newlyCreatedFeeDistributorAddress = event.args?._newFeeDistributorAddress

        // set the newly created FeeDistributor contract as coinbase (block rewards recipient)
        // In the real world this will be done in a validator's settings
        await ethers.provider.send("hardhat_setCoinbase", [
            newlyCreatedFeeDistributorAddress,
        ])

        // simulate producing a new block so that our FeeDistributor contract can get its rewards
        await ethers.provider.send("evm_mine", [])

        // stop collecting rewards
        await ethers.provider.send("hardhat_setCoinbase", [
            ethers.constants.AddressZero,
        ])

        // attach to the FeeDistributor contract with the owner (signer)
        const feeDistributorSignedByDeployer = deployerSignerFactory.attach(newlyCreatedFeeDistributorAddress)

        const serviceAddressBalanceBefore = await ethers.provider.getBalance(serviceAddress)
        const clientAddressBalanceBefore = await ethers.provider.getBalance(clientAddress)

        await mockAlteringReceive.startRevertingOnReceive()
        const withdrawTx = await feeDistributorSignedByDeployer.withdraw()
        const withdrawTxReceipt = await withdrawTx.wait()

        const totalBlockReward = ethers.utils.parseEther('2')

        // get service address balance
        const serviceAddressBalance = await ethers.provider.getBalance(serviceAddress)
        // get client address balance
        const clientAddressBalance = await ethers.provider.getBalance(clientAddress)

        // make sure P2P (service) got its share
        expect(serviceAddressBalance.sub(serviceAddressBalanceBefore)).to.equal(totalBlockReward.mul(serviceBasisPoints).div(10000))
        // client did not get its share due to the revert
        expect(clientAddressBalance.sub(clientAddressBalanceBefore)).to.equal(0)

        const serviceAddressBalanceBeforeRecoverEther = await ethers.provider.getBalance(serviceAddress)
        const clientAddressBalanceBeforeRecoverEther = await ethers.provider.getBalance(clientAddress)
        const remainingEtherBefore = await ethers.provider.getBalance(newlyCreatedFeeDistributorAddress)
        const recoverDestinationEtherBefore = await ethers.provider.getBalance(nobody)

        // recoverEther
        const recoverEtherTx = await feeDistributorSignedByDeployer.recoverEther(nobody)
        const recoverEtherTxReceipt = await recoverEtherTx.wait()
        // recoverEther

        const serviceAddressBalanceAfterRecoverEther = await ethers.provider.getBalance(serviceAddress)
        const clientAddressBalanceAfterRecoverEther = await ethers.provider.getBalance(clientAddress)

        // make sure P2P (service) got its share
        expect(serviceAddressBalanceAfterRecoverEther.sub(serviceAddressBalanceBeforeRecoverEther))
            .to.equal(remainingEtherBefore.mul(serviceBasisPoints).div(10000))
        // client did not get its share due to the revert
        expect(clientAddressBalanceAfterRecoverEther.sub(clientAddressBalanceBeforeRecoverEther))
            .to.equal(0)

        // recovery should happen
        const EtherRecoveredEvent = recoverEtherTxReceipt?.events?.find(event => event.event === 'EtherRecovered')
        const EtherRecoveryFailedEvent = recoverEtherTxReceipt?.events?.find(event => event.event === 'EtherRecoveryFailed')
        expect(!!EtherRecoveredEvent).to.be.true
        expect(!!EtherRecoveryFailedEvent).to.be.false

        const recoverDestinationEtherAfter = await ethers.provider.getBalance(nobody)
        expect(recoverDestinationEtherAfter.sub(recoverDestinationEtherBefore))
            .to.equal(remainingEtherBefore.mul(10000 - serviceBasisPoints).div(10000))

        const remainingEtherAfter = await ethers.provider.getBalance(newlyCreatedFeeDistributorAddress)
        expect(remainingEtherAfter).to.equal(0)
    })
})
