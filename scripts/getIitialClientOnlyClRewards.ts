import { flatten, getRowsFromBigQuery, groupAndSum, range } from "./generateBatchRewardData"

export async function getIitialClientOnlyClRewards() {
    const idsAndCounts = [
        {firstValidatorId: 524511, validatorCount: 1},
        {firstValidatorId: 458908, validatorCount: 1},
        {firstValidatorId: 483996, validatorCount: 1},
        {firstValidatorId: 551909, validatorCount: 5},
        {firstValidatorId: 526709, validatorCount: 24},

        {firstValidatorId: 565823, validatorCount: 10},
        {firstValidatorId: 557237, validatorCount: 21},
        {firstValidatorId: 670938, validatorCount: 10},
        {firstValidatorId: 521543, validatorCount: 1},
        {firstValidatorId: 487215, validatorCount: 94},

        {firstValidatorId: 521576, validatorCount: 1},
        {firstValidatorId: 497067, validatorCount: 4},
        {firstValidatorId: 491223, validatorCount: 10},
        {firstValidatorId: 564275, validatorCount: 1},
        {firstValidatorId: 491490, validatorCount: 1},

        {firstValidatorId: 546657, validatorCount: 22},
        {firstValidatorId: 543285, validatorCount: 10},
        {firstValidatorId: 501859, validatorCount: 31},
        {firstValidatorId: 485640, validatorCount: 7},
    ]
    const valIdsGrouped = idsAndCounts.map(range)
    const valIds = flatten(valIdsGrouped)
    const rows = await getRowsFromBigQuery(valIds)

    const groupedSums = groupAndSum(rows, idsAndCounts);
    return groupedSums;
}

async function main() {
    const groupedSums = await getIitialClientOnlyClRewards();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
