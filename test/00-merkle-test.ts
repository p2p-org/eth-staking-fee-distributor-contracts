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
    const root = '0xd4dee0beab2d53f2cc83e567171bd2820e49898130a22622b10ead383e90bd77'
    const proof = [
        '0xb92c48e9d7abe27fd8dfd6b5dfdbfb1c9a463f80c712b66f3a5180a090cccafc'
    ]
    const address = '0x1111111111111111111111111111111111111111'
    const amount = '5000000000000000000'

    beforeEach(async () => {
        const namedAccounts = await getNamedAccounts()
        deployer = namedAccounts.deployer
        deployerSigner = await ethers.getSigner(deployer)
        verifierContract = await new Verifier__factory(deployerSigner).deploy(root)
    })

    it("verify proof", async function () {
        // create client instance
        const createFeeDistributorTx = await verifierContract.verify(proof, address, amount)

        const createFeeDistributorTxReceipt = await createFeeDistributorTx.wait();
    })
})
