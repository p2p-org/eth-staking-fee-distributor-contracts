# eth-staking-fee-distributor-contracts

## Running tests

```shell
cd eth-staking-fee-distributor-contracts
yarn
cp .env.example .env
# edit .env with the actual values
yarn typechain
curl -L https://foundry.paradigm.xyz | bash
source /Users/$USER/.bashrc
foundryup
yarn test
```

## Basic use case
The basic use case is reflected in `./test/foundry/Integration.t.sol`'s `test_Main_Use_Case` function.

1. Anyone (deployer, does not matter who) deploys `FeeDistributorFactory` providing `_defaultClientBasisPoints` argument.
This default value of client basis points will be used in case later on, during a client instance creation, in `createFeeDistributor` function, `_clientConfig.basisPoints == 0`.
Initially, the plan is to use `9000` as the default value.


2. Anyone (deployer, does not matter who) deploys `Oracle`.


3. Anyone (deployer, does not matter who) deploys `P2pOrgUnlimitedEthDepositor` providing arguments:
   - `_mainnet`: true (means "mainnet")
   - `_feeDistributorFactory`: address of `FeeDistributorFactory`


4. The deployer calls `setP2pEth2Depositor` on `FeeDistributorFactory` with the address of the `P2pOrgUnlimitedEthDepositor` contract from Step 3.


5. Anyone (deployer, does not matter who) deploys reference implementations of FeeDistributor contracts. Currently, there are 3 of them:
   - `ElOnlyFeeDistributor`
     arguments:
       - address of `FeeDistributorFactory` from Step 1.
       - address of the service (P2P) fee recipient
   - `OracleFeeDistributor`
     arguments:
       - address of `Oracle` from Step 2.
       - address of `FeeDistributorFactory` from Step 1.
       - address of the service (P2P) fee recipient
   - `ContractWcFeeDistributor`
   arguments:
     - address of `FeeDistributorFactory` from Step 1.
     - address of the service (P2P) fee recipient


6. The deployer calls `transferOwnership` on `FeeDistributorFactory` with the secure P2P address as an argument.


7. The owner calls `changeOperator` on `FeeDistributorFactory` with the address of the operator. 
The operator is an Ethereum account who can call `createFeeDistributor` for each new client/FeeDistributor type/FeeDistributor percentages.
The operator can be a hot wallet, less secure than the owner. 
Since the primary way to create `FeeDistributor` instances is `P2pOrgUnlimitedEthDepositor`'s `addEth`, 
the operator is needed only for creating alternative `FeeDistributor` instances when either client or referrer configs need to be updated.


8. The deployer does the same steps (6 and 7) for `Oracle`.


9. A client calls `addEth` on `P2pOrgUnlimitedEthDepositor` sending (32 * validator count) ETH and providing the arguments:
   - `_referenceFeeDistributor`: address of FeeDistributor template that determines the terms of staking service
   - `_clientConfig` address and basis points (percent * 100) of the client
   - `_referrerConfig` address and basis points (percent * 100) of the referrer.

The client's ETH is now held in the `P2pOrgUnlimitedEthDepositor` contract. A new `FeeDistributor` instance has been deployed if it didn't exist for the same values of
`_referenceFeeDistributor`, `_clientConfig`, and `_referrerConfig`. If it did exist, no additional contract would be deployed. 
Instead, the newly deposited ETH value would be added to the stored `depositAmount` value corresponding to the `FeeDistributor` instance address.


10. P2P service listens to the `P2pOrgUnlimitedEthDepositor__ClientEthAdded` events emitted on `addEth` execution.
If it determines that a certain `FeeDistributor` instance has at least 32 ETH, it calls `makeBeaconDeposit` on `P2pOrgUnlimitedEthDepositor` providing the arguments:
    - `_feeDistributorInstance`: user FeeDistributor instance that determines the terms of staking service (from Step 9)
    - `_pubkeys`: BLS12-381 public keys
    - `_signatures`: BLS12-381 signatures
    - `_depositDataRoots`: SHA-256 hashes of the SSZ-encoded DepositData objects

As a result, multiple ETH2 deposits are made.


11. P2P service sets the `_newFeeDistributorAddress` from Step 9 as the EL rewards recipient in validators' settings.
Now the per client/terms of service copy of `FeeDistributor` contract will be receiving EL rewards (MEV, priority fees).


12. (Periodically, e.g. daily) P2P oracle service fetches the latest CL rewards sums for each `OracleFeeDistributor` instance's validators.
This data is used as the `oracleData` argument for `./scripts/buildMerkleTreeForFeeDistributorAddress.ts` function.
The result is a Merkle Tree.


13. The operator calls `report` on `Oracle` providing the Merkle Root as the argument.


14. Anyone  (client, P2P withdrawer service, does not matter who) calls `./scripts/obtainProof.ts` function providing the address of the `OracleFeeDistributor` instance as the argument.
It returns:
   - `proof` - Merkle proof (the leaf's sibling, and each non-leaf hash that could not otherwise be calculated without additional leaf nodes)
   - `_amountInGwei` - sum of CL rewards for all validators corresponding to the `OracleFeeDistributor` instance.


15. Anyone at any time can call `withdraw` on a per client/terms of service copy of `FeeDistributor`.
For `OracleFeeDistributor` the required arguments are: `_proof` and `_amountInGwei` from Step 14.
For `ElOnlyFeeDistributor` and `ContractWcFeeDistributor` no arguments are needed.

The result will be sending the whole current contract's balance to 
    - address of the service (P2P)
    - address of the client
    - address of the referrer (optional)
    
   proportionally to the pre-defined
    - % of EL rewards that should go to the service (P2P)
    - % of EL rewards that should go to the client
    - % of EL rewards that should go to the referrer (optional)


## Contracts

**FeeDistributorFactory** deploys new `FeeDistributor` instances based on provided `FeeDistributor` template (reference instance) that determines the type and values:
  - `_clientConfig`: address and basis points (percent * 100) of the client
  - `_referrerConfig`: address and basis points (percent * 100) of the referrer
that determine percentages of rewards that will go to the client, the service, and the referrer (terms of service).

Its `createFeeDistributor` function can be called by either `P2pOrgUnlimitedEthDepositor` contract during `addEth` transaction
or the P2P operator if the validators already exist.


**FeeDistributor** stores
- address of `FeeDistributorFactory`
- address of the service (P2P) fee recipient
- address and basis points of EL rewards that should go to the client
- address and basis points of EL rewards that should go to the referrer (optional)

`FeeDistributor` contract instance is unique and has its own address if all of these are the same:
- `_referenceFeeDistributor`: address of the reference implementation of FeeDistributor used as the basis for clones
- `_clientConfig`: address and basis points (percent * 100) of the client
- `_referrerConfig`: address and basis points (percent * 100) of the referrer

`FeeDistributor` contract's address is assigned in a validator's setting as EL rewards recipient. Thus, its balance increases over time with each EL reward.

Anyone at any time can call `withdraw` on the user's own copy of `FeeDistributor` (See Step 15 above).
Also, it's possible for the P2P operator and the client to call `withdraw` as an **ERC-4337** UserOperation.
An example of how to do it 
- for `ElOnlyFeeDistributor` and `ContractWcFeeDistributor` can be found at `./scripts/sendErc4337UserOperation.ts`
- for `OracleFeeDistributor` can be found at `./scripts/sendErc4337UserOperationForOracleFeeDistributor.ts`
UserOperation will allow the P2P operator and the client not to pay for the gas. 
Gas fee will be deducted from the `FeeDistributor` instance itself.
`FeeDistributor` is an ERC-4337 `Sender` but it is restricted to `withdraw` function only.

Currently, there are 3 types of `FeeDistributor`:
- `ElOnlyFeeDistributor` accepting and splitting EL rewards only
- `OracleFeeDistributor` accepting EL rewards only but splitting them with consideration of CL rewards
- `ContractWcFeeDistributor` accepting and splitting both CL and EL rewards

New types can be added in the future. 
Clients can implement and deploy their own type of `FeeDistributor` and then use it as a `_referenceFeeDistributor` for `addEth` function in `P2pOrgUnlimitedEthDepositor`.
P2P will then be able to evaluate the proposed terms of service.
If they are OK, P2P will proceed with `makeBeaconDeposit`.
If they are not, the client will be able to return their ETH from `P2pOrgUnlimitedEthDepositor` via the `refund` function.


**Oracle** stores Merkle Root, which is used to verify data (`FeeDistributor` instance address, _amountInGwei) using Merkle Proof.

**P2pOrgUnlimitedEthDepositor** is a batch deposit contract.
Its `makeBeaconDeposit` function passes client's ether to the official ETH2 DepositContract and calls `FeeDistributorFactory` to create an instance of `FeeDistributor`.

Its `refund` function allows the client to get their ETH back if P2P did not use it for staking during the pre-defined `TIMEOUT`.
