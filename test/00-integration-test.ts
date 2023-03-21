import { expect } from "chai"
import {ethers, getNamedAccounts} from "hardhat"
import {
    FeeDistributor__factory,
    FeeDistributorFactory__factory,
    FeeDistributorFactory,
    MockAlteringReceive__factory,
    Oracle__factory,
    Oracle,
    P2pEth2Depositor__factory,
    P2pEth2Depositor
} from "../typechain-types"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { generateMockDepositData } from "../scripts/generateMockDepositData"
import { generateMockBatchRewardData } from "../scripts/generateMockBatchRewardData"
import { buildMerkleTreeForValidatorBatch } from "../scripts/buildMerkleTreeForValidatorBatch"
import fs from "fs"
import { obtainProof } from "../scripts/obtainProof"

describe("Integration", function () {

    const BatchCount = 13

    const testAmountInGwei = 2340000000

    const depositCount = 100

    const eth2DepositContractDepositCount = 567254

    const defaultClientBasisPoints = 9000;

    const clientBasisPoints = 9000;

    const referrerBasisPoints =  400;

    const serviceBasisPoints =  10000 - clientBasisPoints - referrerBasisPoints;

    let deployerSigner: SignerWithAddress
    let ownerSigner: SignerWithAddress
    let operatorSigner: SignerWithAddress
    let nobodySigner: SignerWithAddress
    let clientDepositorSigner: SignerWithAddress

    let deployerFactory: FeeDistributor__factory
    let ownerFactory: FeeDistributor__factory
    let operatorFactory: FeeDistributor__factory
    let nobodyFactory: FeeDistributor__factory

    let feeDistributorFactorySignedByDeployer: FeeDistributorFactory
    let oracleSignedByDeployer: Oracle
    let p2pEth2DepositorSignedByClientDepositor: P2pEth2Depositor

    let deployer: string
    let owner: string
    let operator: string
    let nobody : string
    let serviceAddress: string
    let clientDepositor: string
    let clientAddress: string

    beforeEach(async () => {
        const namedAccounts = await getNamedAccounts()

        deployer = namedAccounts.deployer
        owner = namedAccounts.owner
        operator = namedAccounts.operator
        nobody = namedAccounts.nobody
        serviceAddress = namedAccounts.serviceAddress
        clientDepositor = namedAccounts.clientDepositor
        clientAddress = namedAccounts.clientAddress

        deployerSigner = await ethers.getSigner(deployer)
        ownerSigner = await ethers.getSigner(owner)
        operatorSigner = await ethers.getSigner(operator)
        nobodySigner = await ethers.getSigner(nobody)
        clientDepositorSigner = await ethers.getSigner(clientDepositor)

        deployerFactory = new FeeDistributor__factory(deployerSigner)
        ownerFactory = new FeeDistributor__factory(ownerSigner)
        operatorFactory = new FeeDistributor__factory(operatorSigner)
        nobodyFactory = new FeeDistributor__factory(nobodySigner)

        // deploy factory contract
        feeDistributorFactorySignedByDeployer = await new FeeDistributorFactory__factory(deployerSigner).deploy(
            defaultClientBasisPoints
        )

        // deploy oracle contract
        oracleSignedByDeployer = await new Oracle__factory(deployerSigner).deploy()

        // deploy P2pEth2Depositor contract
        const p2pEth2DepositorSignedByDeployer = await new P2pEth2Depositor__factory(deployerSigner).deploy(
            true,
            ethers.constants.AddressZero,
            feeDistributorFactorySignedByDeployer.address
        )

        // set P2pEth2Depositor to FeeDistributorFactory
        await feeDistributorFactorySignedByDeployer.setP2pEth2Depositor(p2pEth2DepositorSignedByDeployer.address)

        p2pEth2DepositorSignedByClientDepositor = P2pEth2Depositor__factory.connect(
            p2pEth2DepositorSignedByDeployer.address,
            clientDepositorSigner
        )
    })

    it("distributes fees", async function () {
        try {
            // deploy reference instance
            const feeDistributorReferenceInstance = await deployerFactory.deploy(
                oracleSignedByDeployer.address,
                feeDistributorFactorySignedByDeployer.address,
                serviceAddress
            )

            // set reference instance
            await feeDistributorFactorySignedByDeployer.setReferenceInstance(feeDistributorReferenceInstance.address)


            const batchDepositData = generateMockDepositData(depositCount)

            const depositTx = await p2pEth2DepositorSignedByClientDepositor.deposit(
                batchDepositData.map(d => d.pubkey),
                batchDepositData[0].withdrawal_credentials,
                batchDepositData.map(d => d.signature),
                batchDepositData.map(d => d.deposit_data_root),
                { recipient: clientAddress, basisPoints: clientBasisPoints },
                { recipient: nobody, basisPoints: referrerBasisPoints },

                {
                    value: ethers.utils.parseUnits((depositCount * 32).toString(), 'ether')
                }
            );

            await expect(depositTx).to.emit(p2pEth2DepositorSignedByClientDepositor, 'P2pEth2DepositEvent')

            const depositTxReceipt = await depositTx.wait();

            const event = depositTxReceipt?.events?.find(event => event.event === 'P2pEth2DepositEvent');
            if (!event) {
                throw Error('No depositTxReceipt event found')
            }

            const _from = event.args?._from
            expect(_from).to.be.equal(clientDepositor)

            const _firstValidatorId = event.args?._firstValidatorId
            expect(_firstValidatorId).to.be.equal(eth2DepositContractDepositCount + 1)
            const firstValidatorIdNumber = _firstValidatorId.toNumber()

            const _validatorCount = event.args?._validatorCount
            expect(_validatorCount).to.be.equal(depositCount)
            const validatorCountNumber = _validatorCount.toNumber()

            // retrieve client instance address from event
            const _newFeeDistributorAddress = event.args?._newFeeDistributorAddress
            console.log(_newFeeDistributorAddress)

            // CL rewards from DB
            const batchRewardData = generateMockBatchRewardData(BatchCount, firstValidatorIdNumber, validatorCountNumber, testAmountInGwei);

            // build Merkle Tree
            const tree = buildMerkleTreeForValidatorBatch(batchRewardData)

            // Send it to the Oracle contract
            console.log('Merkle Root:', tree.root);

            await oracleSignedByDeployer.report(tree.root)

            // Send tree.json file to the website and to the withdrawer
            fs.writeFileSync("tree.json", JSON.stringify(tree.dump()));

            // obtain Proof and rewards info for the batch of validators
            const {proof, value} = obtainProof(firstValidatorIdNumber)
            const amountInGwei = value[2]

            // set the newly created FeeDistributor contract as coinbase (block rewards recipient)
            // In the real world this will be done in a validator's settings
            await ethers.provider.send("hardhat_setCoinbase", [
                _newFeeDistributorAddress,
            ])

            // simulate producing a new block so that our FeeDistributor contract can get its rewards
            await ethers.provider.send("evm_mine", [])

            // attach to the FeeDistributor contract with the owner (signer)
            const feeDistributorSignedByNobody = nobodyFactory.attach(_newFeeDistributorAddress)

            const serviceAddressBalanceBefore = await ethers.provider.getBalance(serviceAddress)

            // call withdraw
            await feeDistributorSignedByNobody.withdraw(proof, amountInGwei)
            //
            // const totalBlockReward = ethers.utils.parseEther('2')
            //
            // // get service address balance
            // const serviceAddressBalance = await ethers.provider.getBalance(serviceAddress)
            //
            // // make sure P2P (service) got its share
            // expect(serviceAddressBalance.sub(serviceAddressBalanceBefore)).to.equal(totalBlockReward.mul(serviceBasisPoints).div(10000))
            //
            // // get client address balance
            // const clientAddressBalance = await ethers.provider.getBalance(clientAddress)
            //
            // // make sure client got its share
            // expect(clientAddressBalance).to.equal(totalBlockReward.mul(clientBasisPoints).div(10000))

        } catch (error) {
            console.log(error)
        }
    })

    // it("recoverEther should simply withdraw in a normal case", async function () {
    //     // deoply factory
    //     const deployerSignerFactory = new FeeDistributor__factory(deployerSigner)
    //
    //     // deoply reference instance
    //     const feeDistributorReferenceInstance = await deployerSignerFactory.deploy(
    //         feeDistributorFactorySignedByDeployer.address,
    //         serviceAddress,
    //         { gasLimit: 3000000 }
    //     )
    //
    //     // set reference instance
    //     await feeDistributorFactorySignedByDeployer.setReferenceInstance(feeDistributorReferenceInstance.address)
    //
    //     // set an operator to create a client instance
    //     await feeDistributorFactorySignedByDeployer.changeOperator(operator)
    //
    //     const operatorSignerFactory = new FeeDistributorFactory__factory(operatorSigner)
    //     const operatorFeeDistributorFactory = operatorSignerFactory.attach(feeDistributorFactorySignedByDeployer.address)
    //
    //     const clientAddress = "0x0000000000000000000000000000000000C0FFEE"
    //     // create client instance
    //     const createFeeDistributorTx = await operatorFeeDistributorFactory.createFeeDistributor(
    //         {recipient: clientAddress, basisPoints: clientBasisPoints},
    //         {recipient: nobody, basisPoints: referrerBasisPoints},
    //     )
    //     const createFeeDistributorTxReceipt = await createFeeDistributorTx.wait();
    //     const event = createFeeDistributorTxReceipt?.events?.find(event => event.event === 'FeeDistributorCreated');
    //     if (!event) {
    //         throw Error('No FeeDistributorCreated found')
    //     }
    //     // retrieve client instance address from event
    //     const newlyCreatedFeeDistributorAddress = event.args?._newFeeDistributorAddress
    //
    //     // set the newly created FeeDistributor contract as coinbase (block rewards recipient)
    //     // In the real world this will be done in a validator's settings
    //     await ethers.provider.send("hardhat_setCoinbase", [
    //         newlyCreatedFeeDistributorAddress,
    //     ])
    //
    //     // simulate producing a new block so that our FeeDistributor contract can get its rewards
    //     await ethers.provider.send("evm_mine", [])
    //
    //     // attach to the FeeDistributor contract with the owner (signer)
    //     const feeDistributorSignedByDeployer = deployerSignerFactory.attach(newlyCreatedFeeDistributorAddress)
    //
    //     const serviceAddressBalanceBefore = await ethers.provider.getBalance(serviceAddress)
    //
    //     const clientAddressBalanceBefore = await ethers.provider.getBalance(clientAddress)
    //
    //     // call recoverEther instead of withdraw
    //     const recoverEtherTx = await feeDistributorSignedByDeployer.recoverEther(nobody)
    //     const recoverEtherTxReceipt = await recoverEtherTx.wait()
    //
    //     const totalBlockReward = ethers.utils.parseEther('2')
    //
    //     // get service address balance
    //     const serviceAddressBalance = await ethers.provider.getBalance(serviceAddress)
    //
    //     // make sure P2P (service) got its share
    //     expect(serviceAddressBalance.sub(serviceAddressBalanceBefore)).to.equal(totalBlockReward.mul(serviceBasisPoints).div(10000))
    //
    //     // get client address balance
    //     const clientAddressBalance = await ethers.provider.getBalance(clientAddress)
    //
    //     // make sure client got its share
    //     expect(clientAddressBalance.sub(clientAddressBalanceBefore)).to.equal(totalBlockReward.mul(clientBasisPoints).div(10000))
    //
    //     // no recovery should happen if the normal withdraw completed successfully
    //     const EtherRecoveredEvent = recoverEtherTxReceipt?.events?.find(event => event.event === 'EtherRecovered')
    //     const EtherRecoveryFailedEvent = recoverEtherTxReceipt?.events?.find(event => event.event === 'EtherRecoveryFailed')
    //     expect(!!EtherRecoveredEvent).to.be.false
    //     expect(!!EtherRecoveryFailedEvent).to.be.false
    // })

    // it("recoverEther should recover ether unclaimed during withdraw", async function () {
    //     // deoply factory
    //     const deployerSignerFactory = new FeeDistributor__factory(deployerSigner)
    //
    //     // deoply reference instance
    //     const feeDistributorReferenceInstance = await deployerSignerFactory.deploy(
    //         feeDistributorFactorySignedByDeployer.address,
    //         serviceAddress,
    //         { gasLimit: 3000000 }
    //     )
    //
    //     // set reference instance
    //     await feeDistributorFactorySignedByDeployer.setReferenceInstance(feeDistributorReferenceInstance.address)
    //
    //     // set an operator to create a client instance
    //     await feeDistributorFactorySignedByDeployer.changeOperator(operator)
    //
    //     const operatorSignerFactory = new FeeDistributorFactory__factory(operatorSigner)
    //     const operatorFeeDistributorFactory = operatorSignerFactory.attach(feeDistributorFactorySignedByDeployer.address)
    //
    //     const mockAlteringReceiveFactory = new MockAlteringReceive__factory(deployerSigner)
    //     const mockAlteringReceive = await mockAlteringReceiveFactory.deploy()
    //     const clientAddress = mockAlteringReceive.address
    //
    //     // create client instance
    //     const createFeeDistributorTx = await operatorFeeDistributorFactory.createFeeDistributor(
    //         {recipient: clientAddress, basisPoints: clientBasisPoints},
    //         {recipient: nobody, basisPoints: referrerBasisPoints},
    //     )
    //     const createFeeDistributorTxReceipt = await createFeeDistributorTx.wait()
    //     const event = createFeeDistributorTxReceipt?.events?.find(event => event.event === 'FeeDistributorCreated');
    //     if (!event) {
    //         throw Error('No FeeDistributorCreated found')
    //     }
    //     // retrieve client instance address from event
    //     const newlyCreatedFeeDistributorAddress = event.args?._newFeeDistributorAddress
    //
    //     // set the newly created FeeDistributor contract as coinbase (block rewards recipient)
    //     // In the real world this will be done in a validator's settings
    //     await ethers.provider.send("hardhat_setCoinbase", [
    //         newlyCreatedFeeDistributorAddress,
    //     ])
    //
    //     // simulate producing a new block so that our FeeDistributor contract can get its rewards
    //     await ethers.provider.send("evm_mine", [])
    //
    //     // stop collecting rewards
    //     await ethers.provider.send("hardhat_setCoinbase", [
    //         ethers.constants.AddressZero,
    //     ])
    //
    //     // attach to the FeeDistributor contract with the owner (signer)
    //     const feeDistributorSignedByDeployer = deployerSignerFactory.attach(newlyCreatedFeeDistributorAddress)
    //
    //     const serviceAddressBalanceBefore = await ethers.provider.getBalance(serviceAddress)
    //     const clientAddressBalanceBefore = await ethers.provider.getBalance(clientAddress)
    //
    //     await mockAlteringReceive.startRevertingOnReceive()
    //     const withdrawTx = await feeDistributorSignedByDeployer.withdraw()
    //     const withdrawTxReceipt = await withdrawTx.wait()
    //
    //     const totalBlockReward = ethers.utils.parseEther('2')
    //
    //     // get service address balance
    //     const serviceAddressBalance = await ethers.provider.getBalance(serviceAddress)
    //     // get client address balance
    //     const clientAddressBalance = await ethers.provider.getBalance(clientAddress)
    //
    //     // make sure P2P (service) got its share
    //     expect(serviceAddressBalance.sub(serviceAddressBalanceBefore)).to.equal(totalBlockReward.mul(serviceBasisPoints).div(10000))
    //     // client did not get its share due to the revert
    //     expect(clientAddressBalance.sub(clientAddressBalanceBefore)).to.equal(0)
    //
    //     const serviceAddressBalanceBeforeRecoverEther = await ethers.provider.getBalance(serviceAddress)
    //     const clientAddressBalanceBeforeRecoverEther = await ethers.provider.getBalance(clientAddress)
    //     const remainingEtherBefore = await ethers.provider.getBalance(newlyCreatedFeeDistributorAddress)
    //     const recoverDestinationEtherBefore = await ethers.provider.getBalance(nobody)
    //
    //     // recoverEther
    //     const recoverEtherTx = await feeDistributorSignedByDeployer.recoverEther(nobody)
    //     const recoverEtherTxReceipt = await recoverEtherTx.wait()
    //     // recoverEther
    //
    //     const serviceAddressBalanceAfterRecoverEther = await ethers.provider.getBalance(serviceAddress)
    //     const clientAddressBalanceAfterRecoverEther = await ethers.provider.getBalance(clientAddress)
    //
    //     // make sure P2P (service) got its share
    //     expect(serviceAddressBalanceAfterRecoverEther.sub(serviceAddressBalanceBeforeRecoverEther))
    //         .to.equal(remainingEtherBefore.mul(serviceBasisPoints).div(10000))
    //     // client did not get its share due to the revert
    //     expect(clientAddressBalanceAfterRecoverEther.sub(clientAddressBalanceBeforeRecoverEther))
    //         .to.equal(0)
    //
    //     // recovery should happen
    //     const EtherRecoveredEvent = recoverEtherTxReceipt?.events?.find(event => event.event === 'EtherRecovered')
    //     const EtherRecoveryFailedEvent = recoverEtherTxReceipt?.events?.find(event => event.event === 'EtherRecoveryFailed')
    //     expect(!!EtherRecoveredEvent).to.be.true
    //     expect(!!EtherRecoveryFailedEvent).to.be.false
    //
    //     const recoverDestinationEtherAfter = await ethers.provider.getBalance(nobody)
    //     expect(recoverDestinationEtherAfter.sub(recoverDestinationEtherBefore))
    //         .to.equal(remainingEtherBefore.mul(10000 - serviceBasisPoints).div(10000))
    //
    //     const remainingEtherAfter = await ethers.provider.getBalance(newlyCreatedFeeDistributorAddress)
    //     expect(remainingEtherAfter).to.equal(0)
    // })
})
