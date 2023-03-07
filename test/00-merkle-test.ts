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
    const root = '0x7600a39895acb6edf989bf48ce46d4e43a6ad90317f770d029ad70e86c32254a'
    const proof = [
        '0x1c44da2540994302ac242a62eefc3dc48c806a3b6763a5d234032d0ff60edae4',
        '0x2ee845506a5f0b0263da75d9a393c693358461ba93673f272775071a67e5687a',
        '0xe0c311b9cc79e6827988fcf7d1dda0d78ee338888dd28535f2f2b968cf0bd563',
        '0xac64faaa3a606532a5cb4b41fd6e551fabd6af599de656badf2d5b4e52cbab0a'
    ]
    const pubKey = '0x7a3ca3eb219c12175b02f0b8131c927ee67e43eb81adab3e2d77d727be4ff5533cdf0ee1300e49f34b63a96786b86a9b'
    const amount = '4000000000'

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
