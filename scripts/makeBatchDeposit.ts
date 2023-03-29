import { ethers, getNamedAccounts } from "hardhat"
import {
    P2pEth2Depositor__factory
} from "../typechain-types"

const deposit_data = [{
    "pubkey": "8d446668dd2f1962a331a08994aec7462a95dbd93c029577a63908b696db65e686389e135be56092879d9ded5bc49a61",
    "withdrawal_credentials": "010000000000000000000000000a0660fc6c21b6c8638c56f7a8bbe22dcc9000",
    "amount": 32000000000,
    "signature": "8cf1ae5cddb95cbc3f1b9c35af206960b6fe5d0a6077f7a7475f1e66febf3f7360c801d51194be43972ec28351ddb14803f94f8f1182058baeb85fd9fd5ff838aa722a68c4319aab8a0d114ce0fadc74c1c6f5211f0cc1574c5c1d31f8099016",
    "deposit_message_root": "06b285a9b9a12e24cf175f8bf3c38bcf161aa552511e8d0a95cb84c5c46b6024",
    "deposit_data_root": "d1b80e9a41e757b85f047a204993ecd590910fedf30b5b564505249450e2b433",
    "fork_version": "00001020",
    "eth2_network_name": "goerli",
    "deposit_cli_version": "2.3.0"
}, {
    "pubkey": "b3c4d53eb6c2bb57226db09bf7f99498ce53f3436523fe050bbf5378c73bd95db72fc5e4f58b8420ec87ce1d9dd1f0c6",
    "withdrawal_credentials": "010000000000000000000000000a0660fc6c21b6c8638c56f7a8bbe22dcc9000",
    "amount": 32000000000,
    "signature": "a74119a06991c91603dd2a96c66e2119fb6a60633fdf55e4e66d0554db486ad935177aa13a8a30d87c59a454ecf0801e05145b6acbdd765558a84d78e3ee871aa29a6622f2f6a3bd1f671db93a33866af7693a823878bc5ac0b93755761ff558",
    "deposit_message_root": "18d1e7db448d7b3115f9e4295bb8bddc34f771b6e8b221801e386c296b03dfdc",
    "deposit_data_root": "09113e0f4afa5a9b7ebd27d9427b19ea4d08810e4857899115e2459f9d21866e",
    "fork_version": "00001020",
    "eth2_network_name": "goerli",
    "deposit_cli_version": "2.3.0"
}, {
    "pubkey": "ad8267d81faf5172c85e8f8a58414666008ce51da97238baaeba01cd876ae44ee3ac9bac6a7303f11fbce02ca72343e3",
    "withdrawal_credentials": "010000000000000000000000000a0660fc6c21b6c8638c56f7a8bbe22dcc9000",
    "amount": 32000000000,
    "signature": "9363a1b7145cf5077f74d3fd7e66e0aa276fb45f72d6b55deb3010fb930a2bf9813e350271f0dd4a49bc93e6357586f111d81fc03eb76f8f0e5997f235cd6a2c2c4828aedb8018eba2d6705e50a6dd38970fc1052a50d0fc3d46bf89ee35dd1c",
    "deposit_message_root": "0a4cb9bf33d9d52922f4621409cc19fff331b49e053e86de22d90a98060a3609",
    "deposit_data_root": "13036e92f495f392dd4707aacce33bf7d6e13d20f7361984a13c1039aa118160",
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
            '0xCdCa5c6Cc0bfF48814b4B0B95E5aC8b2BE1e6169',
            clientDepositorSigner
        )

        const depositTx = await p2pEth2DepositorSignedByClientDepositor.deposit(
            deposit_data.map(d => '0x' + d.pubkey),
            '0x' + deposit_data[0].withdrawal_credentials,
            deposit_data.map(d => '0x' + d.signature),
            deposit_data.map(d => '0x' + d.deposit_data_root),
            { recipient: clientAddress, basisPoints: 8500 },
            { recipient: referrerAddress, basisPoints: 1000 },

            {
                value: ethers.utils.parseUnits((deposit_data.length * 32).toString(), 'ether'),

                gasLimit: 3000000,
                maxPriorityFeePerGas: 40000000000,
                maxFeePerGas: 400000000000
            }
        );

        const depositTxReceipt = await depositTx.wait();

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

