import { expect } from "chai"
import {ethers, getNamedAccounts} from "hardhat"
import {
    Oracle__factory, Oracle
} from "../../typechain-types"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"

describe("Merkle Tree Tests", function () {
    let deployerSigner: SignerWithAddress
    let oracleContract: Oracle

    let deployer: string
    const root = '0x71872a87adbd194dccdecc1c7c7873014f2fa5c3d58ff4a40846135ebf7cf837'
    const proof = [
        '0xd4782dbc9e2053ed89f959afa00d7839948d9c8afe7ad4e414da5a5d0460c065',
        '0x3196ddb5a19b41e02eaca73a47429c8a2be109baf9688065860a7db005983fc4',
        '0x7f645208c2e700c5182ca1df03024e0bc5688e756cd93178b3bd4a0310c8f429',
        '0x977551cb83c2d94e2639c550e0210499fb6b1a42bec376ca1e58873cd707d84f',
        '0xa0e9f7cb2cbf87df52f7f79fc86a2ecbbeecc79fb09aa7519554d1c476176303',
        '0xa3c9155d8c338aae947a038becf282224243dbd0bd38110a5290c143ec8a6d12',
        '0x99894ea7d3278eef651c7a576248e4b8fd2966c6c1c102a4e190a2e71b15d5d8',
        '0xc8fc2b159dcc29b2c66644dfcb44659d4bd6b23ea0de5cb705086cec7a2bb5cd',
        '0xe98592b7286ecd42d70a45685c6edb06c0c7ebb06c6185b4ecded6856ce3bb1b',
        '0xb70e760db59f7fb2cf7ab06b2c7e165645a5afeb39d5d800452f8f4b61cdd408',
        '0xe8136e2e1a2fb36dd7a651153f3757101cc137fdd55730e681bcc00327e4c1c3',
        '0xef95b1a98de428fd0bd197918c06e98d01f38ee4f403377d91417d5409dc40c1',
        '0x371222494cb35e9165b1b5355e70ed9edf09f201a90ed67f71d08a60260927d9',
        '0x91b872662504bccea6ddf7415cd705ce9f44e3a98ea55ab6f4eb9bedddf495ff',
        '0x9745972352a5d20ad26495a5f53f5b4e61e5112a017407d0e9d0651e3879dd52',
        '0x0c20d559cca80272193e0aee152bb919688f48038d727e4be56ce1706f86dce5'
    ]
    const value =  [ 545253, 314, 2340000000 ]

    beforeEach(async () => {
        const namedAccounts = await getNamedAccounts()
        deployer = namedAccounts.deployer
        deployerSigner = await ethers.getSigner(deployer)
        oracleContract = await new Oracle__factory(deployerSigner).deploy()
        await oracleContract.report(root)
    })

    it("verify proof", async function () {
        await oracleContract.verify(proof, value[0], value[1], value[2])
    })
})
