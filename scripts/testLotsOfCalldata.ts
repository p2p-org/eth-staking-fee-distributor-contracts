import { ethers, getNamedAccounts } from "hardhat"
import { P2pEth2Depositor__factory } from "../typechain-types"

const depositData = [{
    pubkey: '0xb30eb0909dcf6379028516d0f6698f9e676de593c681532ab57ee59e99f9e18b1f1ef344fa7ca3429f62865de32c43c5',
    withdrawal_credentials: '0x0100000000000000000000002ff4585707cf36e4bb954d9daf70350d046f7563',
    signature: '0xb23e3dac258819de2c1bf9ffc3ad0d2c518d8f0bed7a99580d2963d5730de2ef3ff2624f1ea765a75a4219286f3449d816afd17fdb7bfa8e8f867562d9e005101e7616a2bb36107fe7a3a431249186feba702e161ab32a37e72f34a20baf593a',
    deposit_data_root: '0xfc8cdd5d8489fa0c2a3d7bfa5fe59d39294dfca30d12394bfbc271ebdba8ae5c',
}]

const clientBasisPoints = 9000;
const referrerBasisPoints = 400;
const clientAddress = '0x388C818CA8B9251b393131C08a736A67ccB19297'
const referrerAddress = '0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5'
const BatchCount = 407

async function main() {
    try {
        const { deployer } = await getNamedAccounts()
        const signer = await ethers.getSigner(deployer)

        // deploy factory contract
        const factoryFactory = new P2pEth2Depositor__factory(signer)
        let nonce = await ethers.provider.getTransactionCount(deployer)
        const testt = await factoryFactory.attach('0xFFfAaBa7CDcfbF8f2f53a92B720189033f4E743e')

        const tx = await testt.deposit(
            [...Array(BatchCount).keys()].map(index => depositData[0].pubkey),
            depositData[0].withdrawal_credentials,
            [...Array(BatchCount).keys()].map(index => depositData[0].signature),
            [...Array(BatchCount).keys()].map(index => depositData[0].deposit_data_root),
            { recipient: clientAddress, basisPoints: clientBasisPoints },
            { recipient: referrerAddress, basisPoints: referrerBasisPoints },
            {gasLimit: 2000000, value: 0}
        )
        const txReceipt = await tx.wait(1)
        console.log(txReceipt.cumulativeGasUsed.toString())
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
