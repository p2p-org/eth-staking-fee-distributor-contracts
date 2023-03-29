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


// FeeDistributorFactory: 0x46D20d13e380eE6544874A8745Ba10e1d71A1788
// Oracle: 0x54abB3702Ca345941Fe8D56C8dAffD095219BDe9
// P2pEth2Depositor: 0xCdCa5c6Cc0bfF48814b4B0B95E5aC8b2BE1e6169
// FeeDistributor: 0x7109447592B2F8eE7872F3045B9dBbB0253CB0D2

