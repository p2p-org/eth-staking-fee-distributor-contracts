import { BigQuery } from "@google-cloud/bigquery"
import { getFeeDistributorsFromLogs } from "./getFeeDistributorsFromLogs"
import { getFirstValidatorIdAndValidatorCount } from "./getFirstValidatorIdAndValidatorCount"

export async function generateBatchRewardData(feeDistributorFactoryAddress: string) {
    const feeDistributorAddresses = await getFeeDistributorsFromLogs(feeDistributorFactoryAddress)
    const getFirstValidatorIdAndValidatorCountPromises = feeDistributorAddresses.map(getFirstValidatorIdAndValidatorCount)
    const idsAndCounts = await Promise.all(getFirstValidatorIdAndValidatorCountPromises)
    const valIdsGrouped = idsAndCounts.map(range)
    const valIds = flatten(valIdsGrouped)
    const rows = await getRowsFromBigQuery(valIds)

    const groupedSums = groupAndSum(rows, idsAndCounts);
    return groupedSums;
}

function groupAndSum(
    rows: {val_id: number, val_amount: number}[],
    idsAndCounts: {firstValidatorId: number, validatorCount: number}[]
) {
    return idsAndCounts.map(({ firstValidatorId, validatorCount }) => {
        const rangeIds = range({ firstValidatorId, validatorCount });
        const sum = rows
            .filter(row => rangeIds.includes(row.val_id))
            .reduce((accumulator, row) => accumulator + row.val_amount, 0);
        return [firstValidatorId, validatorCount, sum];
    });
}

async function getRowsFromBigQuery(valIds: number[]) {
    const bigquery = new BigQuery()

    const query = `
        SELECT val_id, sum(att_earned_reward - att_penalty) as val_amount 
        FROM \`p2p-data-warehouse.raw_ethereum.validators_summary\`
        WHERE val_id IN (${valIds})
        GROUP BY val_id
    `

    const [job] = await bigquery.createQueryJob({
        query: query,
        location: "US"
    })
    const [rows] = await job.getQueryResults()
    return rows
}

function range({firstValidatorId, validatorCount}: {firstValidatorId: number, validatorCount: number}) {
    return [...Array(validatorCount).keys()].map(i => i + firstValidatorId);
}

function flatten(array: number[][]) {
    return array.reduce((accumulator, currentValue) => accumulator.concat(currentValue), []);
}
