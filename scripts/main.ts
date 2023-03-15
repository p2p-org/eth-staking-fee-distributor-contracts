import { generateMockPubkeyRewardData } from "./generateMockPubkeyRewardData"
import fs from "fs"
import { buildMerkleTreeForIndividualValidators } from "./buildMerkleTreeForIndividualValidators"

async function main() {
    const ValidatorsCount = 1000000

    // replace it with data from BigQuery
    const pubkeyRewardData = generateMockPubkeyRewardData(ValidatorsCount);

    const allValidatorsTree = buildMerkleTreeForIndividualValidators(pubkeyRewardData)

    // Send it to the Oracle contract
    console.log('All Validators Tree Merkle Root:', allValidatorsTree.root);

    // Send tree.json file to the website and to the withdrawer
    fs.writeFileSync("allValidatorsTree.json", JSON.stringify(allValidatorsTree.dump()));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
