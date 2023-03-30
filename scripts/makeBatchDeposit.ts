import { ethers, getNamedAccounts } from "hardhat"
import {
    P2pEth2Depositor__factory
} from "../typechain-types"

const deposit_data = [{
    "pubkey": "9080aebef302c8f30c90d6b9e6dfe8249179c5f61e7b99df323f535927ef5ee3e83a4fa87bbe87dcf5c77baaac3a23ca",
    "withdrawal_credentials": "010000000000000000000000000a0660fc6c21b6c8638c56f7a8bbe22dcc9000",
    "amount": 32000000000,
    "signature": "b55ccc58ae59450bee99ba39b43ab820509f30944b91d6fb225eb6329537ad2f39a0b5708e692d13b26270e7980ad7f105de2c7630f757154840423858366cc51c2b5da57e7b6142816deecd2f3e35dcfb50a79c73558294c428af97c0178f90",
    "deposit_message_root": "736a0665a1448aa18a711d8f493a92411c4265cb7da6d2f7a6653e6bb551beae",
    "deposit_data_root": "046d9ad74df0cb689cf830ea6a4350920440a5f113a1c5c18ca3c0e351766a05",
    "fork_version": "00001020",
    "eth2_network_name": "goerli",
    "deposit_cli_version": "2.3.0"
}, {
    "pubkey": "8e232cf16b9b3919e86754cd42a8c589e2f829bf4d9ded96ebb050e8bcec22857392df2c564a4aacfa78960524e11edc",
    "withdrawal_credentials": "010000000000000000000000000a0660fc6c21b6c8638c56f7a8bbe22dcc9000",
    "amount": 32000000000,
    "signature": "ab0ced85975d8157d076db2f69c9860604c6f7cd35121f621a5a4b04bc127771ad97fa7f1f77fc44ee759f5380c3ec2e0d565ca063bfc2305fb245f9318f0cc1e7bcab4b28cd3d6b1f98257995c5218daf60d29586dd8c7ca49ceb0abd62b31a",
    "deposit_message_root": "6342518b248255ce3855c73f0d719398d5b3e85090655580a5bb7009c8c13302",
    "deposit_data_root": "011d0a2c7481660539db468fa1133b8c7d1a4806fbc64d5c03d034afe159a4aa",
    "fork_version": "00001020",
    "eth2_network_name": "goerli",
    "deposit_cli_version": "2.3.0"
}]

async function main() {
    try {
        const referrerAddress = "0x77777776dD9e859b22c029ab230E94779F83A541"
        const clientAddress = "0x00000000D458064273ff4b1f49B190869Af37d47"

        const { deployer: clientDepositor } = await getNamedAccounts()
        const clientDepositorSigner = await ethers.getSigner(clientDepositor)
        let nonce = await ethers.provider.getTransactionCount(clientDepositor)
        const { name: chainName } = await ethers.provider.getNetwork()
        console.log("Deploying to: " + chainName)

        const p2pEth2DepositorSignedByClientDepositor = P2pEth2Depositor__factory.connect(
            "0xE9667CAe191Fb683557750231AA2190E1d90e04D",
            clientDepositorSigner
        )

        const depositTx = await p2pEth2DepositorSignedByClientDepositor.deposit(
            deposit_data.map(d => "0x" + d.pubkey),
            "0x" + deposit_data[0].withdrawal_credentials,
            deposit_data.map(d => "0x" + d.signature),
            deposit_data.map(d => "0x" + d.deposit_data_root),
            { recipient: clientAddress, basisPoints: 8500 },
            { recipient: referrerAddress, basisPoints: 1000 },

            {
                value: ethers.utils.parseUnits((deposit_data.length * 32).toString(), "ether"),

                gasLimit: 3000000,
                maxPriorityFeePerGas: 40000000000,
                maxFeePerGas: 400000000000
            }
        )

        const depositTxReceipt = await depositTx.wait()

        console.log("Done.")
    } catch (err) {
        console.log(err)
    }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})

