import { ethers } from "ethers"

export function generateMockOracleData(n: number) {
    const values = [...Array(n).keys()].map(index => ([
        ethers.utils.hexlify(ethers.utils.randomBytes(48)),
        (index * 1000000000).toString()
    ]))

    return values
}

