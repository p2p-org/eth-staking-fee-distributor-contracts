import { BigQuery } from "@google-cloud/bigquery"

async function main() {
    const bigquery = new BigQuery();

    const query = `SELECT *
      FROM \`p2p-data-warehouse.raw_ethereum.validators_summary\`
      LIMIT 100`;

    const options = {
        query: query,
        location: 'US',
    };
    const [job] = await bigquery.createQueryJob(options);
    const [rows] = await job.getQueryResults();
    rows.forEach(row => console.log(row));
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
