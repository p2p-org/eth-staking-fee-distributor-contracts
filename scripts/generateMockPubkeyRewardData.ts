import { ethers } from "ethers"
import { PubkeyReward } from "./models/PubkeyReward"

export function generateMockPubkeyRewardData(n: number): PubkeyReward[] {
    const values = [...Array(n).keys()].map(index => ({
        pubKey: ethers.utils.hexlify(ethers.utils.randomBytes(48)),
        reward: index * 1000000000
    }))

    return values
}

