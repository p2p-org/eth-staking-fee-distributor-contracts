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
// FeeDistributorFactory deployed at: 0x500c53e354679189a0Ca8A0Eb9c0B7ca3cbB644D
// Oracle deployed at: 0x9341D2d74dF2187C77347061355BF5507A413938
// ContractWcFeeDistributor instance deployed at: 0xA1e3cD1ae497088c30Cd332097B2F6fAd2997A47
// ElOnlyFeeDistributor instance deployed at: 0x44Cd8e2c24d3E11F0838a8Ea942C2D0da5BeD6C0
// OracleFeeDistributor instance deployed at: 0x598351d47a7523c57B64ca9D1819A10c4DC07829
// P2pEth2Depositor deployed at: 0x0B90cE94e127147F94fE5De2756d4fB2eC18dea6

