export function getValidatorIdsForFeeDistributor(feeDistributor: string) {
    const data = {
        '0x2a060E2f6DBC2C66645D976aa9F469d1008370a6': [
            42,
            100500
        ],
        '0xf930490C288F54A8DF9d076C9d6199C5974a50cA': [
            100001,
            100002,
            100003
        ],
        '0x3275B812AF213e19cB4159C1e181ccc7f773Fc3D': [
            500500
        ],
        '0x20Db593fE7baE861C5FA6a2Ea9fCD84515b07E00': [
            9000,
            10000,
            11000,
            12000
        ]
    }

    return data[feeDistributor]
}
