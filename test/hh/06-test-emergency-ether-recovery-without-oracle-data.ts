import { expect } from "chai"
import {ethers, getNamedAccounts} from "hardhat"
import {
    FeeDistributorFactory__factory,
    FeeDistributorFactory,
    Oracle__factory,
    Oracle,
    P2pOrgUnlimitedEthDepositor__factory,
    P2pOrgUnlimitedEthDepositor
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
    const eth2DepositContractDepositCount = 572530
    const defaultClientBasisPoints = 9000;
    const clientBasisPoints = 9000;
    const referrerBasisPoints = 400;

    const serviceBasisPoints =  10000 - clientBasisPoints - referrerBasisPoints;

    let deployerSigner: SignerWithAddress
    let ownerSigner: SignerWithAddress
    let operatorSigner: SignerWithAddress
    let clientAddressSigner: SignerWithAddress
    let clientDepositorSigner: SignerWithAddress

    let deployerFactory: OracleFeeDistributor__factory
    let ownerFactory: OracleFeeDistributor__factory
    let operatorFactory: OracleFeeDistributor__factory
    let clientFactory: OracleFeeDistributor__factory

    let feeDistributorFactorySignedByDeployer: FeeDistributorFactory
    let oracleSignedByDeployer: Oracle
    let P2pOrgUnlimitedEthDepositorSignedByClientDepositor: P2pOrgUnlimitedEthDepositor

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
        clientAddressSigner = await ethers.getSigner(clientAddress)
        clientDepositorSigner = await ethers.getSigner(clientDepositor)

        deployerFactory = new OracleFeeDistributor__factory(deployerSigner)
        ownerFactory = new OracleFeeDistributor__factory(ownerSigner)
        operatorFactory = new OracleFeeDistributor__factory(operatorSigner)
        clientFactory = new OracleFeeDistributor__factory(clientAddressSigner)

        // deploy factory contract
        feeDistributorFactorySignedByDeployer = await new FeeDistributorFactory__factory(deployerSigner).deploy(
            defaultClientBasisPoints
        )

        // deploy oracle contract
        oracleSignedByDeployer = await new Oracle__factory(deployerSigner).deploy()

        // deploy P2pOrgUnlimitedEthDepositor contract
        const P2pOrgUnlimitedEthDepositorSignedByDeployer = await new P2pOrgUnlimitedEthDepositor__factory(deployerSigner).deploy(
            true,
            ethers.constants.AddressZero,
            feeDistributorFactorySignedByDeployer.address
        )

        // set P2pOrgUnlimitedEthDepositor to FeeDistributorFactory
        await feeDistributorFactorySignedByDeployer.setP2pEthDepositor(P2pOrgUnlimitedEthDepositorSignedByDeployer.address)

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

        // set reference instance
        await feeDistributorFactorySignedByDeployer.setReferenceInstance(feeDistributorReferenceInstance.address)


        const batchDepositData = generateMockDepositData(depositCount)

        const depositTx = await P2pOrgUnlimitedEthDepositorSignedByClientDepositor.deposit(
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

        await expect(depositTx).to.emit(P2pOrgUnlimitedEthDepositorSignedByClientDepositor, 'P2pEth2DepositEvent')

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

        // CL rewards from DB
        const batchRewardData = generateMockBatchRewardData(BatchCount, firstValidatorIdNumber, validatorCountNumber, testAmountInGwei);

        // build Merkle Tree
        const tree = buildMerkleTreeForFeeDistributorAddress(batchRewardData)

        // Send it to the Oracle contract
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

        await ethers.provider.send("hardhat_setCoinbase", [
            ethers.constants.AddressZero,
        ])

        // attach to the FeeDistributor contract with the owner (signer)
        const feeDistributorSignedByClient = clientFactory.attach(_newFeeDistributorAddress)

        const serviceAddressBalanceBefore = await ethers.provider.getBalance(serviceAddress)
        const clientAddressBalanceBefore = await ethers.provider.getBalance(clientAddress)

        // call emergencyEtherRecoveryWithoutOracleData
        await feeDistributorSignedByClient.emergencyEtherRecoveryWithoutOracleData()

        const elRewards = ethers.utils.parseEther('2')
        const clRewards = ethers.BigNumber.from(testAmountInGwei).mul(1e9)
        const totalRewards = elRewards.add(clRewards)

        // get service address balance
        const serviceAddressBalance = await ethers.provider.getBalance(serviceAddress)

        // get client address balance
        const clientAddressBalance = await ethers.provider.getBalance(clientAddress)

        const feeDistributorBalance = await ethers.provider.getBalance(_newFeeDistributorAddress)

        // make sure the feeDistributor contract does not have ether left
        expect(feeDistributorBalance).to.equal(0)

        // make sure P2P (service) got its share
        expect(serviceAddressBalance.sub(serviceAddressBalanceBefore)).to.equal(
            elRewards.div(2)
                .mul(serviceBasisPoints)
                .div(serviceBasisPoints + referrerBasisPoints)
        )

        // make sure client got its share
        expect(clientAddressBalance.sub(clientAddressBalanceBefore)).to.equal(
            elRewards.div(2)
        )

        await ethers.provider.send("hardhat_setCoinbase", [
            _newFeeDistributorAddress,
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
