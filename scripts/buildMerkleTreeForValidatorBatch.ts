export function buildMerkleTreeForValidatorBatch(oracleData: string[][]) {

    // https://www.geeksforgeeks.org/what-is-the-efficient-way-to-insert-a-number-into-a-sorted-array-of-numbers-in-javascript/
    const arr = oracleData;

    function add(el, arr) {
        arr.splice(findLoc(el, arr) + 1, 0, el);
        return arr;
    }

    function findLoc(string[] el, arr, st, en) {
        st = st || 0;
        en = en || arr.length;
        for (let i = 0; i < arr.length; i++) {
            if (arr[i] > el)
                return i - 1;
        }
        return en;
    }

    for (let i = 0; i < ValidatorsCount; i++) {

    }
}
