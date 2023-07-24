import { expect } from "chai"
import {ethers, getNamedAccounts} from "hardhat"
import {
    FeeDistributorFactory__factory,
    FeeDistributorFactory,
    Oracle__factory,
    Oracle,
    P2pOrgUnlimitedEthDepositor__factory,
    P2pOrgUnlimitedEthDepositor,
    OracleFeeDistributor__factory
} from "../../typechain-types"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { generateMockDepositData } from "../../scripts/generateMockDepositData"
import { generateMockBatchRewardData } from "../../scripts/generateMockBatchRewardData"
import { buildMerkleTreeForFeeDistributorAddress } from "../../scripts/buildMerkleTreeForFeeDistributorAddress"
import fs from "fs"
import { obtainProof } from "../../scripts/obtainProof"

describe("test emergencyEtherRecoveryWithoutOracleData", function () {

    const BatchCount = 13
    const testAmountInGwei = 800 // very low
    const depositCount = 100
    const defaultClientBasisPoints = 9000;
    const clientBasisPoints = 9000;

    let deployerSigner: SignerWithAddress
    let ownerSigner: SignerWithAddress
    let operatorSigner: SignerWithAddress
    let clientDepositorSigner: SignerWithAddress

    let deployerFactory: OracleFeeDistributor__factory
    let ownerFactory: OracleFeeDistributor__factory
    let operatorFactory: OracleFeeDistributor__factory

    let feeDistributorFactorySignedByDeployer: FeeDistributorFactory
    let oracleSignedByDeployer: Oracle
    let P2pOrgUnlimitedEthDepositorSignedByClientDepositor: P2pOrgUnlimitedEthDepositor
    let P2pOrgUnlimitedEthDepositorSignedByDeployer: P2pOrgUnlimitedEthDepositor

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
        clientAddress = '0xB3E84B6C6409826DC45432B655D8C9489A14A0D7'

        deployerSigner = await ethers.getSigner(deployer)
        ownerSigner = await ethers.getSigner(owner)
        operatorSigner = await ethers.getSigner(operator)
        clientDepositorSigner = await ethers.getSigner(clientDepositor)

        deployerFactory = new OracleFeeDistributor__factory(deployerSigner)
        ownerFactory = new OracleFeeDistributor__factory(ownerSigner)
        operatorFactory = new OracleFeeDistributor__factory(operatorSigner)

        // deploy factory contract
        feeDistributorFactorySignedByDeployer = await new FeeDistributorFactory__factory(deployerSigner).deploy(
            defaultClientBasisPoints
        )

        // deploy oracle contract
        oracleSignedByDeployer = await new Oracle__factory(deployerSigner).deploy()

        // deploy P2pOrgUnlimitedEthDepositor contract
        P2pOrgUnlimitedEthDepositorSignedByDeployer = await new P2pOrgUnlimitedEthDepositor__factory(deployerSigner).deploy(
            feeDistributorFactorySignedByDeployer.address
        )

        // set P2pOrgUnlimitedEthDepositor to FeeDistributorFactory
        await feeDistributorFactorySignedByDeployer.setP2pEth2Depositor(P2pOrgUnlimitedEthDepositorSignedByDeployer.address)

        P2pOrgUnlimitedEthDepositorSignedByClientDepositor = P2pOrgUnlimitedEthDepositor__factory.connect(
            P2pOrgUnlimitedEthDepositorSignedByDeployer.address,
            clientDepositorSigner
        )
    })

    it("emergencyEtherRecoveryWithoutOracleData should withdraw 50% to client 50% to service and referrer combined", async function () {
        // deploy reference instance
        const feeDistributorReferenceInstance = await deployerFactory.deploy(
            oracleSignedByDeployer.address,
            feeDistributorFactorySignedByDeployer.address,
            serviceAddress
        )

        const batchDepositData = generateMockDepositData(depositCount)

        const addEthTx = await P2pOrgUnlimitedEthDepositorSignedByClientDepositor.addEth(
            feeDistributorReferenceInstance.address,
            {recipient: clientAddress, basisPoints: clientBasisPoints},
            {recipient: ethers.constants.AddressZero, basisPoints: 0},
            {
                value: ethers.utils.parseUnits((depositCount * 32).toString(), 'ether')
            }
        )
        const addEthTxReceipt = await addEthTx.wait();

        const clientEthAddedEvent = addEthTxReceipt?.events?.find(
            event => event.event === 'P2pOrgUnlimitedEthDepositor__ClientEthAdded'
        );
        if (!clientEthAddedEvent) {
            throw Error('No addEthTxReceipt event found')
        }
        const _feeDistributorInstance = clientEthAddedEvent.args?._feeDistributorInstance

        const makeBeaconDepositTx = await P2pOrgUnlimitedEthDepositorSignedByDeployer.makeBeaconDeposit(
            _feeDistributorInstance,
            batchDepositData.map(d => d.pubkey),
            batchDepositData.map(d => d.signature),
            batchDepositData.map(d => d.deposit_data_root)
        );

        await expect(makeBeaconDepositTx).to.emit(
            P2pOrgUnlimitedEthDepositorSignedByDeployer,
            'P2pOrgUnlimitedEthDepositor__Eth2Deposit'
        )

        const makeBeaconDepositTxReceipt = await makeBeaconDepositTx.wait();

        const event = makeBeaconDepositTxReceipt?.events?.find(event => event.event === 'P2pOrgUnlimitedEthDepositor__Eth2Deposit');
        if (!event) {
            throw Error('No P2pOrgUnlimitedEthDepositor__Eth2Deposit event found')
        }

        const _validatorCount = event.args?._validatorCount
        expect(_validatorCount).to.be.equal(depositCount)

        // CL rewards from DB
        const batchRewardData = generateMockBatchRewardData(BatchCount, _feeDistributorInstance, testAmountInGwei);

        // build Merkle Tree
        const tree = buildMerkleTreeForFeeDistributorAddress(batchRewardData)

        // Send it to the Oracle contract
        await oracleSignedByDeployer.report(tree.root)

        // Send tree.json file to the website and to the withdrawer
        fs.writeFileSync("tree.json", JSON.stringify(tree.dump()));

        // obtain Proof and rewards info for the batch of validators
        const {proof, value} = obtainProof(_feeDistributorInstance)
        const amountInGwei = value[1]

        // set the newly created FeeDistributor contract as coinbase (block rewards recipient)
        // In the real world this will be done in a validator's settings
        await ethers.provider.send("hardhat_setCoinbase", [
            _feeDistributorInstance,
        ])

        // simulate producing a new block so that our FeeDistributor contract can get its rewards
        await ethers.provider.send("evm_mine", [])

        await ethers.provider.send("hardhat_setCoinbase", [
            ethers.constants.AddressZero,
        ])

        // attach to the FeeDistributor contract with the owner (signer)
        const feeDistributorSignedByClient = new OracleFeeDistributor__factory(await ethers.getImpersonatedSigner(
            clientAddress
        )).attach(_feeDistributorInstance)

        const serviceAddressBalanceBefore = await ethers.provider.getBalance(serviceAddress)
        const clientAddressBalanceBefore = await ethers.provider.getBalance(clientAddress)

        // call emergencyEtherRecoveryWithoutOracleData
        await feeDistributorSignedByClient.emergencyEtherRecoveryWithoutOracleData()

        const elRewards = ethers.utils.parseEther('2')

        // get service address balance
        const serviceAddressBalance = await ethers.provider.getBalance(serviceAddress)

        // get client address balance
        const clientAddressBalance = await ethers.provider.getBalance(clientAddress)

        const feeDistributorBalance = await ethers.provider.getBalance(_feeDistributorInstance)

        // make sure the feeDistributor contract does not have ether left
        expect(feeDistributorBalance).to.equal(0)

        // make sure P2P (service) got its share
        expect(serviceAddressBalance.sub(serviceAddressBalanceBefore)).to.equal(
            elRewards.div(2)
        )

        // make sure client got its share
        expect(clientAddressBalance.sub(clientAddressBalanceBefore)).to.equal(
            elRewards.div(2)
        )

        await ethers.provider.send("hardhat_setCoinbase", [
            _feeDistributorInstance,
        ])
        await ethers.provider.send("evm_mine", [])
        await ethers.provider.send("hardhat_setCoinbase", [
            ethers.constants.AddressZero,
        ])

        // call withdraw
        await expect(feeDistributorSignedByClient.withdraw(proof, amountInGwei)).to.be.revertedWith(
            `FeeDistributor__WaitForEnoughRewardsToWithdraw`
        )
    })
})
