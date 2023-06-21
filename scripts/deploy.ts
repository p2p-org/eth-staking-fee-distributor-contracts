import { ethers, getNamedAccounts } from "hardhat"
import {
    ContractWcFeeDistributor__factory, ElOnlyFeeDistributor__factory,
    FeeDistributorFactory__factory,
    Oracle__factory, OracleFeeDistributor__factory, P2pOrgUnlimitedEthDepositor__factory
} from "../typechain-types"

async function main() {
    try {
        const serviceAddress = '0x6Bb8b45a1C6eA816B70d76f83f7dC4f0f87365Ff'
        const defaultClientBasisPoints = 9000

        const { deployer } = await getNamedAccounts()
        const deployerSigner = await ethers.getSigner(deployer)
        let nonce = await ethers.provider.getTransactionCount(deployer)
        const {name: chainName, chainId} = await ethers.provider.getNetwork()
        console.log('Deploying to: ' + chainName)

        // deploy factory contract
        const feeDistributorFactorySignedByDeployer = await new FeeDistributorFactory__factory(deployerSigner).deploy(
            defaultClientBasisPoints, {gasLimit: 10000000, maxPriorityFeePerGas: 1000, maxFeePerGas: 400000000000}
        )
        await feeDistributorFactorySignedByDeployer.deployed()
        console.log('FeeDistributorFactory deployed at: ' +  feeDistributorFactorySignedByDeployer.address)
        nonce++

        // deploy oracle contract
        const oracleSignedByDeployer = await new Oracle__factory(deployerSigner).deploy(
            {gasLimit: 10000000, maxPriorityFeePerGas: 1000, maxFeePerGas: 400000000000}
        )
        await oracleSignedByDeployer.deployed()
        console.log('Oracle deployed at: ' +  oracleSignedByDeployer.address)
        nonce++

        // deploy ContractWcFeeDistributor reference instance
        const ContractWcFeeDistributor = await new ContractWcFeeDistributor__factory(deployerSigner).deploy(
            feeDistributorFactorySignedByDeployer.address,
            serviceAddress,
            {gasLimit: 10000000, maxPriorityFeePerGas: 1000, maxFeePerGas: 400000000000}
        )
        await ContractWcFeeDistributor.deployed()
        console.log('ContractWcFeeDistributor instance deployed at: ' +  ContractWcFeeDistributor.address)
        nonce++

        // deploy ElOnlyFeeDistributor reference instance
        const ElOnlyFeeDistributor = await new ElOnlyFeeDistributor__factory(deployerSigner).deploy(
            feeDistributorFactorySignedByDeployer.address,
            serviceAddress,
            {gasLimit: 10000000, maxPriorityFeePerGas: 1000, maxFeePerGas: 400000000000}
        )
        await ElOnlyFeeDistributor.deployed()
        console.log('ElOnlyFeeDistributor instance deployed at: ' +  ElOnlyFeeDistributor.address)
        nonce++

        // deploy OracleFeeDistributor reference instance
        const OracleFeeDistributor = await new OracleFeeDistributor__factory(deployerSigner).deploy(
            oracleSignedByDeployer.address,
            feeDistributorFactorySignedByDeployer.address,
            serviceAddress,
            {gasLimit: 10000000, maxPriorityFeePerGas: 1000, maxFeePerGas: 400000000000}
        )
        await OracleFeeDistributor.deployed()
        console.log('OracleFeeDistributor instance deployed at: ' +  OracleFeeDistributor.address)
        nonce++

        // deploy P2pEth2Depositor contract
        const p2pEth2DepositorSignedByDeployer = await new P2pOrgUnlimitedEthDepositor__factory(deployerSigner).deploy(
            chainId === 1,
            feeDistributorFactorySignedByDeployer.address,
            {gasLimit: 10000000, maxPriorityFeePerGas: 1000, maxFeePerGas: 400000000000}
        )
        await p2pEth2DepositorSignedByDeployer.deployed()
        console.log('P2pEth2Depositor deployed at: ' +  p2pEth2DepositorSignedByDeployer.address)
        nonce++

        // set P2pEth2Depositor to FeeDistributorFactory
        const txSetP2pEth2Depositor = await feeDistributorFactorySignedByDeployer.setP2pEth2Depositor(
            p2pEth2DepositorSignedByDeployer.address,
            {gasLimit: 10000000, maxPriorityFeePerGas: 1000, maxFeePerGas: 400000000000}
        )
        await txSetP2pEth2Depositor.wait()
        nonce++

        console.log('Done.')
    } catch (err) {
        console.log(err)
    }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});


// Deploying to: goerli
// FeeDistributorFactory deployed at: 0x8C87EFBA90414687A66C8B2E7D21039E81d55456
// Oracle deployed at: 0x6aA04FA882E4Cd26F0354B07Ee1884Fe156f78B2
// ContractWcFeeDistributor instance deployed at: 0x46320E8a9F101D43e7502dbFc06aaCE389448986
// ElOnlyFeeDistributor instance deployed at: 0x94EDf7e950fA01bAa44a8690cAC64264cdB7cA7c
// OracleFeeDistributor instance deployed at: 0xAD91441aB557b5eC5d9f29DB64522Eb918B4f32b
// P2pEth2Depositor deployed at: 0x38129624175aC89337B5068B8364EfC5F539a567
//

