import { DepositData } from "./models/DepositData"

const SAMPLE_DEPOSIT_DATA = {
    pubkey: '0x87f08e27a19e0d15764838e3af5c33645545610f268c2dadba3c2c789e2579a5d5300a3d72c6fb5fce4e9aa1c2f32d40',
    withdrawal_credentials: '0x010000000000000000000000b3e84b6c6409826dc45432b655d8c9489a14a0d7',
    signature: '0x816597afd6c13068692512ed57e7c6facde10be01b247c58d67f15e3716ec7eb9856d28e25e1375ab526b098fdd3094405435a9bf7bf95369697365536cb904f0ae4f8da07f830ae1892182e318588ce8dd6220be2145f6c29d28e0d57040d42',
    deposit_data_root: '0x34b7017543befa837eb0af8a32b2c6e543b1d869ff526680c9d59291b742d5b7',
}

export function generateMockDepositData(n: number): DepositData[] {
    const values = [...Array(n).keys()].map(() => (SAMPLE_DEPOSIT_DATA))

    return values
}

