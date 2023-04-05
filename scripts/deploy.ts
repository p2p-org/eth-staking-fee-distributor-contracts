import { ethers, getNamedAccounts } from "hardhat"
import {
    FeeDistributor__factory,
    FeeDistributorFactory__factory,
    Oracle__factory,
    P2pEth2Depositor__factory
} from "../typechain-types"

async function main() {
    try {
        const serviceAddress = '0x6Bb8b45a1C6eA816B70d76f83f7dC4f0f87365Ff'
        const defaultClientBasisPoints = 9000

        const { deployer } = await getNamedAccounts()
        const deployerSigner = await ethers.getSigner(deployer)
        let nonce = await ethers.provider.getTransactionCount(deployer)
        const {name: chainName} = await ethers.provider.getNetwork()
        console.log('Deploying to: ' + chainName)

        // deploy factory contract
        const feeDistributorFactorySignedByDeployer = await new FeeDistributorFactory__factory(deployerSigner).deploy(
            defaultClientBasisPoints, {gasLimit: 10000000, maxPriorityFeePerGas: 40000000000, maxFeePerGas: 400000000000}
        )
        await feeDistributorFactorySignedByDeployer.deployed()
        console.log('FeeDistributorFactory deployed at: ' +  feeDistributorFactorySignedByDeployer.address)
        nonce++

        // deploy oracle contract
        const oracleSignedByDeployer = await new Oracle__factory(deployerSigner).deploy(
            {gasLimit: 10000000, maxPriorityFeePerGas: 40000000000, maxFeePerGas: 400000000000}
        )
        await oracleSignedByDeployer.deployed()
        console.log('Oracle deployed at: ' +  oracleSignedByDeployer.address)
        nonce++

        // deploy P2pEth2Depositor contract
        const p2pEth2DepositorSignedByDeployer = await new P2pEth2Depositor__factory(deployerSigner).deploy(
            chainName === 'mainnet',
            ethers.constants.AddressZero,
            feeDistributorFactorySignedByDeployer.address,
            {gasLimit: 10000000, maxPriorityFeePerGas: 40000000000, maxFeePerGas: 400000000000}
        )
        await p2pEth2DepositorSignedByDeployer.deployed()
        console.log('P2pEth2Depositor deployed at: ' +  p2pEth2DepositorSignedByDeployer.address)
        nonce++

        // set P2pEth2Depositor to FeeDistributorFactory
        const txSetP2pEth2Depositor = await feeDistributorFactorySignedByDeployer.setP2pEth2Depositor(
            p2pEth2DepositorSignedByDeployer.address,
            {gasLimit: 10000000, maxPriorityFeePerGas: 40000000000, maxFeePerGas: 400000000000}
        )
        await txSetP2pEth2Depositor.wait()
        nonce++

        // deploy reference instance
        const feeDistributorReferenceInstance = await new FeeDistributor__factory(deployerSigner).deploy(
            oracleSignedByDeployer.address,
            feeDistributorFactorySignedByDeployer.address,
            serviceAddress,
            {gasLimit: 10000000, maxPriorityFeePerGas: 40000000000, maxFeePerGas: 400000000000}
        )
        await feeDistributorReferenceInstance.deployed()
        console.log('FeeDistributor instance deployed at: ' +  feeDistributorReferenceInstance.address)
        nonce++

        // set reference instance
        const txSetReferenceInstance = await feeDistributorFactorySignedByDeployer.setReferenceInstance(
            feeDistributorReferenceInstance.address,
            {gasLimit: 10000000, maxPriorityFeePerGas: 40000000000, maxFeePerGas: 400000000000}
        )
        await txSetReferenceInstance.wait()

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


// FeeDistributorFactory deployed at: 0xD00BFa0A263Bb29C383E1dB3493c3172dE0B367A
// Oracle deployed at: 0x5aBFeC1E3781f0a16241a82AA767041B7bd63F42
// P2pEth2Depositor deployed at: 0xE9667CAe191Fb683557750231AA2190E1d90e04D
// FeeDistributor instance deployed at: 0xf2d018A724F00E0c526da7bDce1e83Ffb6F8f1B1

