import { getValidatorIdsForFeeDistributor } from "./getValidatorIdsForFeeDistributor"
import { getRowsFromBigQuery } from "./getRowsFromBigQuery"

export async function getClRewards(feeDistributor: string) {
    const ids = getValidatorIdsForFeeDistributor(feeDistributor)
    const rows = await getRowsFromBigQuery(ids)
    return rows.reduce((accumulator, row) => accumulator + row.val_amount, 0)
}
