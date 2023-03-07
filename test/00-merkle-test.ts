import { expect } from "chai"
import {ethers, getNamedAccounts} from "hardhat"
import {
    Verifier__factory, Verifier
} from "../typechain-types"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"

describe("Merkle Tree Tests", function () {
    let deployerSigner: SignerWithAddress
    let verifierContract: Verifier

    let deployer: string
    const root = '0xd145de65acb4c97e1d13420a401b11d1b1b0bf6d296ae959ce9fca34e5b5604d'
    const proof = [
        '0xbea9a58976fb4391ee167680312cbc6547f03a41b4cae2d149dd9b3af48fc9d0'
    ]
    const pubKey = '0x8d82b56734553df587aeeacf0dc883025014842bf47a6c3f2b31c26f6d8db5783fded3b58a0d29f86bfd727bb122d3be'
    const amount = '2500000000000000000'

    beforeEach(async () => {
        const namedAccounts = await getNamedAccounts()
        deployer = namedAccounts.deployer
        deployerSigner = await ethers.getSigner(deployer)
        verifierContract = await new Verifier__factory(deployerSigner).deploy(root)
    })

    it("verify proof", async function () {
        // create client instance
        const createFeeDistributorTx = await verifierContract.verify(proof, pubKey, amount)

        const createFeeDistributorTxReceipt = await createFeeDistributorTx.wait();
    })
})
