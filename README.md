# Staking draft

## Running tests

```shell
cd staking-draft
yarn
yarn typechain
yarn test
```

## Basic use case
The basic use case is reflected in ./test/test-fee-distributor.ts

1. Anyone (deployer, does not matter who) deploys `FeeDistributorFactory`.


2. Anyone (deployer, does not matter who) deploys a reference implementation of `FeeDistributor` providing the constant arguments:
   - address of `FeeDistributorFactory`
   - address of the service (P2P) fee recipient
   - % of EL rewards that should go to the service (P2P)
   - % of EL rewards that should go to the client


3. The deployer calls `initialize` on `FeeDistributorFactory` with the address of the reference implementation of `FeeDistributor` from Step 2.


4. The deployer calls `transferOwnership` with the secure P2P address as an argument.
Only the secure P2P address can now change the reference implementation of `FeeDistributor` and create new (per client) instances of `FeeDistributor` based on the reference implementation. 


5. When a new client comes, the secure P2P address calls `createFeeDistributor` on `FeeDistributorFactory` with the client address as an argument.
In the transaction log, there will be a `FeeDistributorCreated` event containing the address of the newly created instance of `FeeDistributor`.


6. Set the address from Step 5 as the EL rewards recipient in a validator's settings.
Now the user's own copy of `FeeDistributor` contract will be receiving EL rewards (MEV, priority fees).


7. Anyone at any time can call `withdraw` on the user's own copy of `FeeDistributor`. The result will be sending the whole current contract's balance to 
    - address of the service (P2P)
    - address of the client
    
   proportionally to the pre-defined
    - % of EL rewards that should go to the service (P2P)
    - % of EL rewards that should go to the client
      
   (See Step 2).


## Contracts

We have 2 contracts: **FeeDistributorFactory** and **FeeDistributor**.

**FeeDistributorFactory** stores a reference implementation of `FeeDistributor` in its `s_referenceFeeDistributor` storage slot.

The owner of `FeeDistributorFactory` can change this reference implementation (upgrade) at any time via `FeeDistributorFactory`'s `initialize` function.

For each client, a new instance of `FeeDistributor` is created via `FeeDistributorFactory`'s `createFeeDistributor`.

**FeeDistributor** stores
- address of `FeeDistributorFactory`
- address of the service (P2P) fee recipient
- % of EL rewards that should go to the service (P2P)
- % of EL rewards that should go to the client
- address of the client

Each client gets their own copy of `FeeDistributor` contract with their own address.

`FeeDistributor` contract's address is assigned in a validator's setting as EL rewards recipient. Thus, its balance increases over time with each EL reward.

Anyone at any time can call `withdraw` on the user's own copy of `FeeDistributor` (See Step 7 above).
