import { IFeeDistributorFactory__factory } from "../typechain-types"
import { ethers } from "hardhat"

async function main() {
    const abi = [
        {
            "anonymous": false,
            "inputs": [
                {
                    "indexed": true,
                    "internalType": "address",
                    "name": "_newFeeDistributorAddress",
                    "type": "address"
                },
                {
                    "indexed": true,
                    "internalType": "address",
                    "name": "_clientAddress",
                    "type": "address"
                }
            ],
            "name": "FeeDistributorCreated",
            "type": "event"
        }
    ];

    const factory = IFeeDistributorFactory__factory.connect(
        "0xd875e7e690dcb00997b0247022f87dedb40176e4", // "0xD00BFa0A263Bb29C383E1dB3493c3172dE0B367A",
        ethers.provider
    )

    const filter = factory.filters.FeeDistributorCreated(null, null)

    let result = await factory.queryFilter(filter, 0, "latest");

    const feeDistributors = result.map(event => event.args._newFeeDistributorAddress)

    console.log(feeDistributors)
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
