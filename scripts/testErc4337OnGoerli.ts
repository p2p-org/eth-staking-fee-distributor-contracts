import { ethers, getNamedAccounts } from "hardhat"
import {
    ContractWcFeeDistributor__factory, ElOnlyFeeDistributor__factory,
    FeeDistributorFactory__factory,
    Oracle__factory, OracleFeeDistributor__factory, P2pOrgUnlimitedEthDepositor__factory
} from "../typechain-types"

const depositData = {
    "pubkey":"96e3676c2f7816cd91e29c563d5e9deb2197285fdf6eb5840034d35775b78cc492cdd8aa944d4d0bad0bab02fb128069",
    "withdrawal_credentials":"010000000000000000000000000000005504f0f5cf39b1ed609b892d23028e57",
    "amount":32000000000,
    "signature":"9666f85fffebe4b642d59729e0152ac9b704d115dd267bf123c31f3dcc78f68576a60d3e8a1a820b61a98a1341f1be1f0c9b04debd3eaf6a113aba24de72a4b2dca8e5cfe48a61707357cbb6a643aaf537d2657ac4fc101d9c36373e9d2ef673",
    "deposit_message_root":"5e0477fd54f5b9f0597911b354216ae0a2f511d783028c5c77c6d07ae7e9b1ca",
    "deposit_data_root":"aae7e345c5f3b8d1cee954f18ba304827df1d79b60fea8f846f1a2b2dda5fca9",
    "fork_version":"00001020","eth2_network_name":"goerli","deposit_cli_version":"2.3.0"}

const elOnlyFeeDistributorAddress = '0xcDf6F2d3F17d4d0036794d4F14aE3A54eb94AF32'

async function main() {
    try {
        const { deployer } = await getNamedAccounts()
        const deployerSigner = await ethers.getSigner(deployer)
        let nonce = await ethers.provider.getTransactionCount(deployer)
        const {name: chainName, chainId} = await ethers.provider.getNetwork()
        console.log('Started on: ' + chainName)

        const feeDistributorFactorySignedByDeployer = await new FeeDistributorFactory__factory(deployerSigner).attach('0x500c53e354679189a0Ca8A0Eb9c0B7ca3cbB644D')
        const oracleSignedByDeployer = await new Oracle__factory(deployerSigner).attach('0x9341D2d74dF2187C77347061355BF5507A413938')
        const ContractWcFeeDistributor = await new ContractWcFeeDistributor__factory(deployerSigner).attach('0xA1e3cD1ae497088c30Cd332097B2F6fAd2997A47')
        const ElOnlyFeeDistributor = await new ElOnlyFeeDistributor__factory(deployerSigner).attach('0x44Cd8e2c24d3E11F0838a8Ea942C2D0da5BeD6C0')
        const OracleFeeDistributor = await new OracleFeeDistributor__factory(deployerSigner).attach('0x598351d47a7523c57B64ca9D1819A10c4DC07829')
        const p2pEth2DepositorSignedByDeployer = await new P2pOrgUnlimitedEthDepositor__factory(deployerSigner).attach('0x0B90cE94e127147F94fE5De2756d4fB2eC18dea6')

        // await p2pEth2DepositorSignedByDeployer.addEth(
        //     ElOnlyFeeDistributor.address,
        //     { recipient: deployer, basisPoints: 9500 },
        //     { recipient: ethers.constants.AddressZero, basisPoints: 0 },
        //     {
        //         value: ethers.utils.parseUnits((32).toString(), 'ether'),
        //         maxFeePerGas: 50000000000,
        //         maxPriorityFeePerGas: 1000000000
        //     }
        // )

        p2pEth2DepositorSignedByDeployer.makeBeaconDeposit(
            elOnlyFeeDistributorAddress,
            [depositData.pubkey],
            [depositData.signature],
            [depositData.deposit_data_root],
                {
                    maxFeePerGas: 50000000000,
                    maxPriorityFeePerGas: 1000000000
                }
        )

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

