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

        const feeDistributorFactorySignedByDeployer = await new FeeDistributorFactory__factory(deployerSigner).attach('0xFb67d31772336bDEAE46D8B402C8A330abEa0326')
        const oracleSignedByDeployer = await new Oracle__factory(deployerSigner).attach('0x257640704D813cCF3679f752a7bE6D27Fa9c01b0')
        const ContractWcFeeDistributor = await new ContractWcFeeDistributor__factory(deployerSigner).attach('0x54eE9634Cf0cD008Cf37A4119103249D953CE089')
        const ElOnlyFeeDistributor = await new ElOnlyFeeDistributor__factory(deployerSigner).attach('0x34b6255FCCb74D921285Ea9cf7DEd498bceca278')
        const OracleFeeDistributor = await new OracleFeeDistributor__factory(deployerSigner).attach('0x69f41965567D204E07b7D9B1aE659680312b9308')
        const p2pEth2DepositorSignedByDeployer = await new P2pOrgUnlimitedEthDepositor__factory(deployerSigner).attach('0x9d7008090DCf7cC0004b9A0A0aceebA83d93d8Bb')

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

        // p2pEth2DepositorSignedByDeployer.makeBeaconDeposit(
        //     elOnlyFeeDistributorAddress,
        //     [depositData.pubkey],
        //     [depositData.signature],
        //     [depositData.deposit_data_root],
        //         {
        //             maxFeePerGas: 50000000000,
        //             maxPriorityFeePerGas: 1000000000
        //         }
        // )

        feeDistributorFactorySignedByDeployer.createFeeDistributor(
            ElOnlyFeeDistributor.address,
            { recipient: deployer, basisPoints: 9500 },
            { recipient: ethers.constants.AddressZero, basisPoints: 0 },
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

