import { expect } from "chai"
import {ethers, getNamedAccounts} from "hardhat"
import {
    FeeDistributor__factory,
    FeeDistributorFactory__factory,
    FeeDistributorFactory
} from '../typechain-types'
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
})
