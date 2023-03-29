import { BigQuery } from "@google-cloud/bigquery"

async function main() {
    console.log('Start fetch from BQ')

    const bigquery = new BigQuery();

    const query = `
        SELECT val_id, sum(att_earned_reward - att_penalty) as val_amount 
        FROM \`p2p-data-warehouse.raw_ethereum.validators_summary\`
        GROUP BY val_id
    `;

    const [job] = await bigquery.createQueryJob({
        query: query,
        location: 'US',
    });
    const [rows] = await job.getQueryResults();

    // get a list of FeeDistributor instances from FeeDistributorFactory logs
    // get firstValidatorId and validatorCount from each FeeDistributor
    // create batches val_id ∈ [firstValidatorId, firstValidatorId + validatorCount - 1] out of rows

    rows.forEach(row => console.log(row));
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
