import { ethers, getNamedAccounts } from "hardhat"
import {
    FeeDistributorFactory__factory,
} from "../typechain-types"
import { getIitialClientOnlyClRewards } from "./getIitialClientOnlyClRewards"

const clientConfigs = [
    { recipient: '0x72564246Ca7392A48068E5C79882a25fB4F35c49', basisPoints: 9000 },
    { recipient: '0x72564246Ca7392A48068E5C79882a25fB4F35c49', basisPoints: 9000 },
    { recipient: '0x5661449C72ED80f28b5bE3a962Bf7E88adFA68bd', basisPoints: 9000 },
    { recipient: '0xa0209dB78eBF4F3ce1018bc549C9E905AfE2E8Ae', basisPoints: 9000 },
    { recipient: '0x6FC42C340b482e9219c0aCc19CC78C6f4BbBCfdf', basisPoints: 9000 },

    { recipient: '0x098B1216a72842d0024B637a231aC3A3fD6f7E9E', basisPoints: 9000 },
    { recipient: '0x098B1216a72842d0024B637a231aC3A3fD6f7E9E', basisPoints: 9000 },
    { recipient: '0x098B1216a72842d0024B637a231aC3A3fD6f7E9E', basisPoints: 9000 },
    { recipient: '0x2ec39A0a1258d06480B95E83f9857231F682B8bd', basisPoints: 9000 },
    { recipient: '0x3fd8462E467708e5d1Dd4aD6BEcf4058d4ccBD8d', basisPoints: 9000 },

    { recipient: '0xEf9BB650758a8999f4f9DFE4F5948BEFf23cC3AA', basisPoints: 9000 },
    { recipient: '0xEf9BB650758a8999f4f9DFE4F5948BEFf23cC3AA', basisPoints: 9000 },
    { recipient: '0xEf9BB650758a8999f4f9DFE4F5948BEFf23cC3AA', basisPoints: 9000 },
    { recipient: '0xA157B222133562F7bb5c0aB20f42e5500703BC93', basisPoints: 9000 },
    { recipient: '0xB9339fB72252be09388372B5CD739Ba43Dee9864', basisPoints: 9000 },

    { recipient: '0x1188107C4eD60221851FBDa99D8A24BCcc58A677', basisPoints: 9000 },
    { recipient: '0x1188107C4eD60221851FBDa99D8A24BCcc58A677', basisPoints: 9000 },
    { recipient: '0xE4d3A1f0B7ff84798A1fF4f42fFe09467776F8D2', basisPoints: 8500 },
    { recipient: '0xC8c36fA036244658920bc78D316efa4C9d98f306', basisPoints: 9000 },
]

async function main() {
    try {
        const { deployer } = await getNamedAccounts()
        const deployerSigner = await ethers.getSigner(deployer)
        const {name: chainName} = await ethers.provider.getNetwork()
        console.log('Deploying to: ' + chainName)

        // attach factory contract
        const feeDistributorFactorySignedByDeployer = await new FeeDistributorFactory__factory(deployerSigner).attach(
            '0xd5B7680f95c5A6CAeCdBBEB1DeE580960C4F891b'
        )

        const validatorDataArray = await getIitialClientOnlyClRewards()

        for (let i = 0; i < 19; i++) {
            const clientConfig = clientConfigs[i]
            const validatorData = {
                firstValidatorId: validatorDataArray[i][0],
                validatorCount: validatorDataArray[i][1],
                clientOnlyClRewards: ethers.BigNumber.from(validatorDataArray[i][2]).mul(1e9)
            }

            console.log(JSON.stringify(clientConfig))
            console.log(JSON.stringify(validatorData))

            const tx = await feeDistributorFactorySignedByDeployer.createFeeDistributor(
                clientConfig,
                { recipient: ethers.constants.AddressZero, basisPoints: 0 },
                validatorData,
                {gasLimit: 200000, maxPriorityFeePerGas: 100000000, maxFeePerGas: 50000000000}
            )
            await tx.wait()

            console.log('Deployed ' + (i + 1))

            console.log('\n')
        }

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

