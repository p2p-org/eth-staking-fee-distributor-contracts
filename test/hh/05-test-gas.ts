import { expect } from "chai"
import {ethers, getNamedAccounts} from "hardhat"
import {
    P2pOrgUnlimitedEthDepositor__factory
} from "../../typechain-types"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"

const clientBasisPoints = 9000;
const referrerBasisPoints = 400;
const clientAddress = '0x388C818CA8B9251b393131C08a736A67ccB19297'
const referrerAddress = '0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5'
const BatchCount = 400

describe("TestP2pOrgUnlimitedEthDepositor", function () {

    let deployer: string
    let deployerSigner: SignerWithAddress
    let factory: P2pOrgUnlimitedEthDepositor__factory

    before(async () => {
        const namedAccounts = await getNamedAccounts()
        deployer = namedAccounts.deployer
        deployerSigner = await ethers.getSigner(deployer)
        factory = new P2pOrgUnlimitedEthDepositor__factory(deployerSigner)
    })

    const depositData = [{
        pubkey: '0xa8ecef195708fe44c63ce9a3a141b6bd314951877f5c42d0e77cab38bff25ba1539d20eeb8cdbb5fa702b085adaa941e',
        withdrawal_credentials: '0x00a6c79b5077fa73f8a0448fcdf8aeefd19d690ee97189f97010446f79aeaf82',
        signature: '0x9411e7873d5a95c0784b01124846f587e98cb500af48c3a98f6e5d067f0a0fde5a9e148545883369da23c0dfae07d161130f66228932248574dbc2e4689caa037ab86f98f1fa4802a43894b3db48c55352ef3844df3fb445940f3333fa431ce8',
        deposit_data_root: '0xa01f384cb625353a835c3d721ef7b33363be3b23ca6e62a1a2d9248a2d4b68bc',
    }]

    it("test gas", async function () {
        const testt = await factory.attach('0xFFfAaBa7CDcfbF8f2f53a92B720189033f4E743e')
        const tx = await testt.deposit(
            [...Array(BatchCount).keys()].map(index => depositData[0].pubkey),
            depositData[0].withdrawal_credentials,
            [...Array(BatchCount).keys()].map(index => depositData[0].signature),
            [...Array(BatchCount).keys()].map(index => depositData[0].deposit_data_root),
            { recipient: clientAddress, basisPoints: clientBasisPoints },
            { recipient: referrerAddress, basisPoints: referrerBasisPoints },
            {gasLimit: 2000000, value: ethers.utils.parseUnits('32', 18)}
        )
        const txReceipt = await tx.wait(1)
        expect(txReceipt.cumulativeGasUsed.toNumber()).to.be.lessThan(2000000)
    })
})
