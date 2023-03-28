# eth-staking-fee-distributor-contracts

## Running tests

```shell
cd eth-staking-fee-distributor-contracts
yarn
cp .env.example .env
# edit .env with the actual values
yarn typechain
yarn test
```

## Basic use case
The basic use case is reflected in `./test/00-integration-test-low-cl-rewards.ts`

1. Anyone (deployer, does not matter who) deploys `FeeDistributorFactory` providing `_defaultClientBasisPoints` argument.
This default value of client basis points will be used in case later on, during a client instance creation, in `createFeeDistributor` function, `_clientConfig.basisPoints == 0`.
Initially, the plan is to use `9000` as the default value.


2. Anyone (deployer, does not matter who) deploys `Oracle`.


3. Anyone (deployer, does not matter who) deploys `P2pEth2Depositor` providing arguments:
   - `_mainnet`: true (means "mainnet")
   - `_depositContract`: 0x0000000000000000000000000000000000000000 (will be replaced with 0x00000000219ab540356cBB839Cbe05303d7705Fa, the real ETH2 DepositContract address).
   - `_feeDistributorFactory`: address of `FeeDistributorFactory`


4. The deployer calls `setP2pEth2Depositor` on `FeeDistributorFactory` with the address of the `P2pEth2Depositor` contract from Step 3.


5. Anyone (deployer, does not matter who) deploys a reference implementation of `FeeDistributor` providing the arguments:
   - address of `Oracle` from Step 2.
   - address of `FeeDistributorFactory` from Step 1.
   - address of the service (P2P) fee recipient


6. The deployer calls `setReferenceInstance` on `FeeDistributorFactory` with the address of the reference implementation of `FeeDistributor` from Step 5.


7. The deployer calls `transferOwnership` on `FeeDistributorFactory` with the secure P2P address as an argument.
Only the secure P2P address can now change the reference implementation of `FeeDistributor`. 


8. The owner calls `changeOperator` on `FeeDistributorFactory` with the address of the operator. 
The operator is an Ethereum account whose only responsibility is to call `createFeeDistributor` for each new batch deposit.
The operator can be a hot wallet, less secure than the owner. 
Since the primary way to create `FeeDistributor` instances is `P2pEth2Depositor`'s `deposit`, 
the operator is needed only for creating alternative `FeeDistributor` instances when either client or referrer configs need to be updated.


9. The deployer does the same steps (7 and 8) for `Oracle`.


10. A client calls `deposit` on `P2pEth2Depositor` sending (32 * validator count) ETH and providing the arguments:
   - `_pubkeys`: array of BLS12-381 public keys.
   - `_withdrawal_credentials`: commitment to a public keys for withdrawals. 1, same for all
   - `_signatures`: array of BLS12-381 signatures.
   - `_deposit_data_roots`: array of the SHA-256 hashes of the SSZ-encoded DepositData objects.
   - `_clientConfig`: address and basis points (percent * 100) of the client
   - `_referrerConfig`: address and basis points (percent * 100) of the referrer.

As a result, multiple ETH2 deposits are made and a corresponding `FeeDistributor` instance is created.
The emitted log event `P2pEth2DepositEvent` contains the summary:
   - `_from`: the address of the depositor
   - `_newFeeDistributorAddress`: a FeeDistributor instance that has just been deployed
   - `_firstValidatorId`: validator Id (number of all deposits previously made to ETH2 DepositContract plus 1)
   - `_validatorCount`: number of ETH2 deposits made with 1 P2pEth2Depositor's deposit


11. Set the `_newFeeDistributorAddress` from Step 9 as the EL rewards recipient in a validator's settings.
Now the per batch deposit copy of `FeeDistributor` contract will be receiving EL rewards (MEV, priority fees).


12. (Periodically, e.g. daily) P2P oracle service fetches the latest CL rewards sums for each validator batch (validator IDs from `firstValidatorId` to `_validatorCount`).
This data is used as the `oracleData` argument for `./scripts/buildMerkleTreeForValidatorBatch.ts` function.
The result is a Merkle Tree.


13. The operator calls `report` on `Oracle` providing the Merkle Root as the argument.


14. Anyone  (client, P2P withdrawer service, does not matter who) calls `./scripts/obtainProof.ts` function providing `_firstValidatorId` as the argument.
It returns:
   - `proof` - Merkle proof (the leaf's sibling, and each non-leaf hash that could not otherwise be calculated without additional leaf nodes)
   - `value` - array of 3 numbers: `_firstValidatorId`, `_validatorCount`, `_amountInGwei`.


15. Anyone at any time can call `withdraw` on a per batch deposit copy of `FeeDistributor`.
The requied arguments are: `_proof` and `_amountInGwei` from Step 14.

The result will be sending the whole current contract's balance to 
    - address of the service (P2P)
    - address of the client
    - address of the referrer (optional)
    
   proportionally to the pre-defined
    - % of EL rewards that should go to the service (P2P)
    - % of EL rewards that should go to the client
    - % of EL rewards that should go to the referrer (optional)


## Contracts

**FeeDistributorFactory** stores a reference implementation of `FeeDistributor` in its `s_referenceFeeDistributor` storage slot.

The owner of `FeeDistributorFactory` can change this reference implementation (upgrade) at any time via `FeeDistributorFactory`'s `setReferenceInstance` function.

For each batch deposit, a new instance of `FeeDistributor` is created via `FeeDistributorFactory`'s `createFeeDistributor`.

**FeeDistributor** stores
- address of `FeeDistributorFactory`
- address of the service (P2P) fee recipient
- address and basis points of EL rewards that should go to the client
- address and basis points of EL rewards that should go to the referrer (optional)

Each batch deposit gets their own copy of `FeeDistributor` contract with their own address.

`FeeDistributor` contract's address is assigned in a validator's setting as EL rewards recipient. Thus, its balance increases over time with each EL reward.

Anyone at any time can call `withdraw` on the user's own copy of `FeeDistributor` (See Step 15 above).

**Oracle** stores Merkle Root, which is used to verify data (_firstValidatorId, _validatorCount, _amountInGwei) using Merkle Proof.

**P2pEth2Depositor** is a batch deposit contract. It does not have any storage.
Its `deposit` function passes all the ether to the official ETH2 DepositContract and calls `FeeDistributorFactory` to create an instance of `FeeDistributor`.

**P2pMessageSender** is a small auxiliary contract. Its only purpose is to write any text to event log.
This functionality will be used for sending persisted messages without structural contraints. 
