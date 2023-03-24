export function generateMockBatchRewardData(
    batchCount: number, // number of batches
    testFirstValidatorId: number,
    testValidatorCount: number,
    testAmount: number
): number[][] {
    const values = [...Array(batchCount - 10).keys()].map(index => ([
        index * 1000000, // FirstValidatorId
        index * 1000000000 % testValidatorCount, // ValidatorCount
        index * 1000000000 // Amount
    ]))

    values.push([
        testFirstValidatorId,
        testValidatorCount,
        testAmount
    ])

    const restValues = [...Array(9).keys()].map(index => ([
        (index + values.length) * 1000000, // FirstValidatorId
        (index + values.length) * 1000000000 % testValidatorCount, // ValidatorCount
        (index + values.length) * 1000000000 // Amount
    ]))

    values.push(...restValues)

    return values
}

