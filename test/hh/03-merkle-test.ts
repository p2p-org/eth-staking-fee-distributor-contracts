import {ethers, getNamedAccounts} from "hardhat"
import {
    Oracle__factory, Oracle
} from "../../typechain-types"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"

describe("Merkle Tree Tests", function () {
    let deployerSigner: SignerWithAddress
    let oracleContract: Oracle

    let deployer: string
    const root = '0x8ffa3563dd3de06e70d7dae30a456ec5737fa982193862a05e1eaf4fef6beb63'
    const proof = [
        '0x482c22dca1afb1a7d8bf4c86db6a875ab302ad9e7ebc3baca15ca60207c3c5e0',
        '0xa2d2d9599717e5e4d3e14d43cfd1d2cdf6befc8d91af26a12c7bad79e308050f'
    ]

    const value =  5000000

    beforeEach(async () => {
        const namedAccounts = await getNamedAccounts()
        deployer = namedAccounts.deployer
        deployerSigner = await ethers.getSigner(deployer)
        oracleContract = await new Oracle__factory(deployerSigner).deploy()
        await oracleContract.report(root)
    })

    it("verify proof", async function () {
        await oracleContract.verify(proof, "0xc70ee116750Cbb9f589f774e4d463Be4Eb959267", value)
    })
})
