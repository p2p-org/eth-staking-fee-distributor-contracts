export function generateMockBatchRewardData(
    batchCount: number, // number of batches
    feeDistributorAddress: string,
    testAmount: number
): string[][] {
    const values = [...Array(batchCount - 10).keys()].map(index => ([
        feeDistributorAddress,
        (index * 1000000000).toString() // Amount
    ]))

    values.push([
        feeDistributorAddress,
        testAmount.toString()
    ])

    const restValues = [...Array(9).keys()].map(index => ([
        "0x0Fd0489d5CcF0AcC0ccbE8a1F1e638E74CaB5BD7", // random address
        ((index + values.length) * 1000000000).toString() // Amount
    ]))

    values.push(...restValues)

    return values
}

