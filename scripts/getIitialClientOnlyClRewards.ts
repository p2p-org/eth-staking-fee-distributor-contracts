import { flatten, getRowsFromBigQuery, range } from "./generateBatchRewardData"
import { BigQuery } from "@google-cloud/bigquery"

export async function getIitialClientOnlyClRewards() {
    const idsAndCounts = [
        {oracleId: 1, firstValidatorId: 524511, validatorCount: 1},
        {oracleId: 1, firstValidatorId: 458908, validatorCount: 1},
        {oracleId: 2, firstValidatorId: 483996, validatorCount: 1},
        {oracleId: 2, firstValidatorId: 486009, validatorCount: 37},
        {oracleId: 2, firstValidatorId: 486382, validatorCount: 40},

        {oracleId: 3, firstValidatorId: 546962, validatorCount: 1},
        {oracleId: 4, firstValidatorId: 551909, validatorCount: 5},
        {oracleId: 5, firstValidatorId: 526709, validatorCount: 24},
        {oracleId: 6, firstValidatorId: 521543, validatorCount: 1},
        {oracleId: 7, firstValidatorId: 487215, validatorCount: 94},

        {oracleId: 8, firstValidatorId: 491223, validatorCount: 10},
        {oracleId: 8, firstValidatorId: 497067, validatorCount: 4},
        {oracleId: 8, firstValidatorId: 521576, validatorCount: 1},
        {oracleId: 9, firstValidatorId: 491490, validatorCount: 1},
        {oracleId: 10, firstValidatorId: 501859, validatorCount: 31},

        {oracleId: 11, firstValidatorId: 485640, validatorCount: 7},
        {oracleId: 12, firstValidatorId: 564275, validatorCount: 1},
    ]
    const valIdsGrouped = idsAndCounts.map(rangeWithOracleIds)
    const vals = flattenWithOracleIds(valIdsGrouped)
    const rows = await getRowsFromBigQuery(vals.map(v => v.index))

    const groupedSums = groupAndSumWithOracleIds(rows, idsAndCounts);
    const reduced = groupAndSumOracleIdRanges(groupedSums)
    return reduced;
}

function groupAndSumWithOracleIds(
    rows: {val_id: number, val_amount: number}[],
    idsAndCounts: {oracleId: number, firstValidatorId: number, validatorCount: number}[]
) {
    return idsAndCounts.map(({ oracleId, firstValidatorId, validatorCount }) => {
        const rangeIds = rangeWithOracleIds({ oracleId, firstValidatorId, validatorCount });
        const sum = rows
            .filter(row => rangeIds.map(r => r.index).includes(row.val_id))
            .reduce((accumulator, row) => accumulator + row.val_amount, 0);
        return {oracleId, firstValidatorId, validatorCount, sum};
    });
}

function groupAndSumOracleIdRanges(
    sumsByRanges: {oracleId: number, firstValidatorId: number, validatorCount: number, sum: number}[]
) {
    return sumsByRanges.reduce((accumulator: {oracleId: number, validatorCount: number, sum: number}[],
                                { oracleId, validatorCount, sum }) => {
        // Check if an entry with the same oracleId already exists in the accumulator
        const existingEntry = accumulator.find(entry => entry.oracleId === oracleId);

        if (existingEntry) {
            // If it does, simply add to the validatorCount and sum
            existingEntry.validatorCount += validatorCount;
            existingEntry.sum += sum;
        } else {
            // If it doesn't, add a new entry to the accumulator
            accumulator.push({ oracleId, validatorCount, sum });
        }

        return accumulator;
    }, []);
}

export async function getValidatorData() {
    const idsAndCounts = [
        {oracleId: 1, firstValidatorId: 524511, validatorCount: 1, feeDivider: '0x05660a51A688E9F102f0bF46Cb6e64efc3381408'},
        {oracleId: 1, firstValidatorId: 458908, validatorCount: 1, feeDivider: '0x05660a51A688E9F102f0bF46Cb6e64efc3381408'},
        {oracleId: 2, firstValidatorId: 483996, validatorCount: 1, feeDivider: '0xB21E436D4deA46adbB3F5276d357180e694dC8b7'},
        {oracleId: 2, firstValidatorId: 486009, validatorCount: 37, feeDivider: '0xB21E436D4deA46adbB3F5276d357180e694dC8b7'},
        {oracleId: 2, firstValidatorId: 486382, validatorCount: 40, feeDivider: '0xB21E436D4deA46adbB3F5276d357180e694dC8b7'},

        {oracleId: 4, firstValidatorId: 551909, validatorCount: 5, feeDivider: '0x0216CfF879B17B5beDe762B3e4071B49c8696a25'},
        {oracleId: 5, firstValidatorId: 526709, validatorCount: 24, feeDivider: '0x3d1be477186D64B4f4fba7cB773216dA0C2B474F'},
        {oracleId: 6, firstValidatorId: 521543, validatorCount: 1, feeDivider: '0xBB52D5B7F2AE4BBe0967F4626d07aba89F462Ff7'},
        {oracleId: 7, firstValidatorId: 487215, validatorCount: 94, feeDivider: '0x36c0A9B9D3799bddbcED6f584a70060DF368a073'},

        {oracleId: 8, firstValidatorId: 491223, validatorCount: 10, feeDivider: '0xF555a33C07eEAB91EE4bF1Bc950c14Fc8a9EF1aB'},
        {oracleId: 8, firstValidatorId: 497067, validatorCount: 4, feeDivider: '0xF555a33C07eEAB91EE4bF1Bc950c14Fc8a9EF1aB'},
        {oracleId: 8, firstValidatorId: 521576, validatorCount: 1, feeDivider: '0xF555a33C07eEAB91EE4bF1Bc950c14Fc8a9EF1aB'},
        {oracleId: 9, firstValidatorId: 491490, validatorCount: 1, feeDivider: '0xe39640588571F507298F688bf8b1F68D9600F96c'},
        {oracleId: 10, firstValidatorId: 501859, validatorCount: 31, feeDivider: '0xd6781E7F15752d3F5764609a42A803A7345DE25c'},

        {oracleId: 11, firstValidatorId: 485640, validatorCount: 7, feeDivider: '0xD3825cd251eF9AD7b9Bffec5851e438e15D0a358'},
        {oracleId: 12, firstValidatorId: 564275, validatorCount: 1, feeDivider: '0x72288Ee8c6304778D5d78AaB71F50acAC61E7B81'},
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

export function rangeWithOracleIds({firstValidatorId, validatorCount, oracleId}:
                                         {firstValidatorId: number, validatorCount: number, oracleId: number}) {
    return [...Array(validatorCount).keys()].map(i => ({index: i + firstValidatorId, oracleId}));
}

export function flattenWithOracleIds(array: { index: number; oracleId: number }[][]) {
    return array.reduce((accumulator, currentValue) => accumulator.concat(currentValue), []);
}

async function main() {
    console.log("pubkey,feedivider")
    const data = await getValidatorData();
    data.map(d => console.log(d.pubKey + ',' + d.feeDivider))
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
// main().catch((error) => {
//     console.error(error);
//     process.exitCode = 1;
// });
