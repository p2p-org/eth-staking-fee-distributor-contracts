import { flatten, getRowsFromBigQuery, groupAndSum, range } from "./generateBatchRewardData"
import { BigQuery } from "@google-cloud/bigquery"

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

export async function getValidatorData() {
    const idsAndCounts = [
        {firstValidatorId: 524511, validatorCount: 1, feeDivider: '0xB2be59bed9e625A99f704030AEE6aAa5181D2e09'},
        {firstValidatorId: 458908, validatorCount: 1, feeDivider: '0xDBEF4D23833a3a6e91D620caa0FE72F594D2E153'},
        {firstValidatorId: 483996, validatorCount: 1, feeDivider: '0x2A95C85a85767bE7E91Ff10f1A255F31c460811c'},
        {firstValidatorId: 551909, validatorCount: 5, feeDivider: '0xac1821abb3dd4D890FC8FB960d796469A82D2E05'},
        {firstValidatorId: 526709, validatorCount: 24, feeDivider: '0xBa63343A228B6F8C35f1013B5F2527162BAEeE3E'},

        {firstValidatorId: 565823, validatorCount: 10, feeDivider: '0xfD80D04e8FdCFE9dc1707D4f9D4855E706bc1A11'},
        {firstValidatorId: 557237, validatorCount: 21, feeDivider: '0xE22B75c7d7238C6D66d14953d2b4211a10ef3635'},
        {firstValidatorId: 670938, validatorCount: 10, feeDivider: '0x5933dD898E74491c30Efe0855BD0fB505d577A6A'},
        {firstValidatorId: 521543, validatorCount: 1, feeDivider: '0x053Ab0F12e02b819a3E3E903489a711f62c512F2'},
        {firstValidatorId: 487215, validatorCount: 94, feeDivider: '0x8f9C7e2373D7410Ef2F49480dd27b1b2aA43439B'},

        {firstValidatorId: 521576, validatorCount: 1, feeDivider: '0x0723A225FddB1328a6B0B6D345F04F7bed06a994'},
        {firstValidatorId: 497067, validatorCount: 4, feeDivider: '0x5ae668dB49Bf848AE2c10d4e3f863B5E46e79F68'},
        {firstValidatorId: 491223, validatorCount: 10, feeDivider: '0x91F177e861B1ef3b1321224d93F27Fc479186980'},
        {firstValidatorId: 564275, validatorCount: 1, feeDivider: '0xfBe1a357586e04Fd5B315b03CC599e3CCb4729aE'},
        {firstValidatorId: 491490, validatorCount: 1, feeDivider: '0xa543F5A85AfCcb3C3789026900E9a8C61Da66851'},

        {firstValidatorId: 546657, validatorCount: 22, feeDivider: '0x8B71bC670b80b456c5B183a84b45Ea2D84BeD8C1'},
        {firstValidatorId: 543285, validatorCount: 10, feeDivider: '0xA564beF728805cEab727a63134526b40edc4e81F'},
        {firstValidatorId: 501859, validatorCount: 31, feeDivider: '0xF95306839BEE5b73004F501F57db16F477537618'},
        {firstValidatorId: 485640, validatorCount: 7, feeDivider: '0xf88Fc7298a31FC240c0eC8C9671766142d398Eaf'},
    ]
    const valIdsGrouped = idsAndCounts.map(rangeWithFeeDividers)
    const vals = flattenWithFeeDividers(valIdsGrouped)
    const rows = await getPublKeysFromBigQuery(vals.map(v => v.index))

    const result = vals.map((v, i) => ({
        index: v.index,
        feeDivider: v.feeDivider,
        pubKey: rows.find(r => r.val_id === v.index).val_pubkey
    }))

    return result;
}

export async function getPublKeysFromBigQuery(valIds: number[]) {
    const bigquery = new BigQuery()

    const query = `
        SELECT val_id, val_pubkey FROM \`p2p-data-warehouse.raw_ethereum.validators_index\`
        WHERE val_id IN (${valIds})
    `

    const [job] = await bigquery.createQueryJob({
        query: query,
        location: "US"
    })
    const [rows] = await job.getQueryResults()
    return rows
}

export function rangeWithFeeDividers({firstValidatorId, validatorCount, feeDivider}:
                                     {firstValidatorId: number, validatorCount: number, feeDivider: string}) {
    return [...Array(validatorCount).keys()].map(i => ({index: i + firstValidatorId, feeDivider}));
}

export function flattenWithFeeDividers(array: { index: number; feeDivider: string }[][]) {
    return array.reduce((accumulator, currentValue) => accumulator.concat(currentValue), []);
}

async function main() {
    const data = await getValidatorData();
    data.map(d => console.log(d.pubKey + ',' + d.feeDivider))
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
