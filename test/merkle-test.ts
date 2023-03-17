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
    const root = '0xeee5b16c4cba402470791cdf4aeacdb8f62362300eb4973346e5d718ad78e905'
    const proof = [
        '0x1f82da0028e5197c5aed7b6190dc9fa1e289114c3e1614abfb74621a127cc6ff',
        '0x1a61149148c5fb8b39a4d1676c6e93d508c0f3687b03751d9e1e7014cd7d85c9',
        '0xc5dc049ed304500be9d7a1f6788d9d5585680f71cfa4e0597083475dba183391',
        '0xae84a4b877486f3dfa80314b3fd1ad77d7f445717c969f0afb438a5a9ce5bfd4',
        '0x251b8019aa00ad8de1969b910cabc83d0a1fc71df769492ea024c8b81db2bdce',
        '0xd548c6294b79e6293932d1b00f703de34b0e259a0525cf78214042346cf878f5',
        '0x97e157563a5691de4b74fad66479f5bb0696845bccf4663d1f9a2285a69b542a',
        '0x87bf938e72ee1cdf5a74e8c62400b66d5cc67da4182769a5f5f8319e7a09c2a2',
        '0x005b610c356389503df105b76afa39d3e72f227dad4966eee55f8ee256eba362',
        '0xa071d95a6e06fb0229f97e7a49d0278f965815837aaf579611784b5a0442544d',
        '0xeab7a402142dbd9c062d1fab0ef80c12b0aeba4f20d1c77ffeea0585878e112c',
        '0xb1afee8ac016fb899db6519377007ff673404faa8ebfbb4b170527c39f33055d',
        '0xb7df07075f83b743935f767895f6219f484d56514a76358a71aa99c6db6e7e39',
        '0xff434a1ba3ea4e8ea01bf98eb401cce72c78d645b73737c59d17be215c243b4d',
        '0x1415fd1e45ffd1eab98826538f7ecc9cbd7b5c269d0c027e4561aec8c7240067',
        '0x44a814a99542792f9588def504658e9e6b6453505566ba72cc8a424e44f1f702',
        '0x0b253fcf2a99d082fe128eab5b9b2d9378ab21a7b8d147863d7c0ce909801280',
        '0xd30649f6bb71774e8876f27b7b5a6eb775bdf91dd9960397aedcc499bdc76510',
        '0xeccb9155b1660e6bc3d5fa3e12bbd462b77ee3d68ad1330ee287aa28e23441be',
        '0x0449ef89dd228881783fba4cd10ce9fcbbe7a4baec94a3924caab66fa4c502fd'
    ]
    const pubKey = '0xa7a591c01356c89f6856eeb3b6226125d3b6364449d4d13dc10ff21454cbbc9e7bdf07312df2fa685e179bcfd1679050'
    const amount = '731213000000000'

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

        console.log(createFeeDistributorTxReceipt.cumulativeGasUsed.toString())
    })
})
