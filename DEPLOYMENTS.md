# NttManagerWithExecutor EVM Deployments

## Mainnet

### June 2, 2025

#### Version Info

Commit Hash:

<!-- cspell:disable -->

```sh
example-ntt-with-executor (main)$ git rev-parse HEAD
9ac9e68da771291a95727e56855d759388fe7fef
example-ntt-with-executor (main)$
```

<!-- cspell:enable -->

Foundry Version:

<!-- cspell:disable -->

```sh
evm (main)$ forge --version
forge Version: 1.1.0-stable
Commit SHA: d484a00089d789a19e2e43e63bbb3f1500eb2cbf
Build Timestamp: 2025-04-30T13:50:49.971365000Z (1746021049)
Build Profile: maxperf
evm (main)$
```

<!-- cspell:enable -->

#### Chains Deployed

Here are the deployed contract addresses for each chain. The number after the chain name is the Wormhole chain ID configured for the contract.

- Arbitrum (23): [0x3eBE296B3266E57e3D48Cab4504b42dCe109320F](https://arbiscan.io/address/0x3ebe296b3266e57e3d48cab4504b42dce109320f#code)
- Avalanche (6): [0x246E3968dA8f9aA3608BAa9FdBe83c8EB6B51671](https://snowtrace.io/address/0x246E3968dA8f9aA3608BAa9FdBe83c8EB6B51671/contract/43114/code)
- Base (30): [0x82cC11b8495db54F505cf7332FD84F2B4De737B2](https://basescan.org/address/0x82cC11b8495db54F505cf7332FD84F2B4De737B2#code)
- Ethereum (2): [0xBC8923bdA7F7f4398843E426Ac9906c0FC92F283](https://etherscan.io/address/0xbc8923bda7f7f4398843e426ac9906c0fc92f283#code)
- HyperEVM (47): [0x2925736843d3286451D7Da4bc80c325adf052EC7](https://purrsec.com/address/0x2925736843d3286451D7Da4bc80c325adf052EC7/contract)
- Linea (38): [0x98b3912498AeB7FB1Afc1582Bd85F3a59Ab3DfCe](https://lineascan.build/address/0x98b3912498aeb7fb1afc1582bd85f3a59ab3dfce#code)
- Optimism (24): [0xc2BeEE468046B08EE7fC84696bf61902304F4A3d](https://optimistic.etherscan.io/address/0xc2beee468046b08ee7fc84696bf61902304f4a3d#code)
- Polygon (5): [0xC786c85c442Efba2E253adD36cAF6C22B75ecD0e](https://polygonscan.com/address/0xc786c85c442efba2e253add36caf6c22b75ecd0e#code)
- Sonic (52): [0x1868CD4E5602Dad57cA2F8C930296BcAFe7430D4](https://sonicscan.org/address/0x1868cd4e5602dad57ca2f8c930296bcafe7430d4#code)
- Unichain (44): [0x3ACFCE6B1Be520147C63F05fA67b62103d15e06D](https://uniscan.xyz/address/0x3acfce6b1be520147c63f05fa67b62103d15e06d#code)
- World Chain (45): [0x7456c0291BBd32af68B1f6d13929F8EB2c6C53c8](https://worldscan.org/address/0x7456c0291bbd32af68b1f6d13929f8eb2c6c53c8#code)

## Testnet

### June 10, 2025

This version fixes a dust issue in the fee calculation.

#### Version Info

Commit Hash:

<!-- cspell:disable -->

```sh
example-ntt-with-executor (main)$ git rev-parse HEAD
e2ced94dc187e6885fc1d53068c6e12bbfeec5ee
example-ntt-with-executor (main)$ git branch
```

<!-- cspell:enable -->

Foundry Version:

<!-- cspell:disable -->

```sh
evm (main)$ forge --version
forge Version: 1.2.1-stable
Commit SHA: 42341d5c94947d566c21a539aead92c4c53837a2
Build Timestamp: 2025-05-26T05:24:48.799227114Z (1748237088)
Build Profile: maxperf
evm (main)$
```

<!-- cspell:enable -->

#### Chains Deployed

Here are the deployed contract addresses for each chain. The number after the chain name is the Wormhole chain ID configured for the contract.

- Sepolia (10002): [0x54DD7080aE169DD923fE56d0C4f814a0a17B8f41](https://sepolia.etherscan.io/address/0x54DD7080aE169DD923fE56d0C4f814a0a17B8f41)
- Base Sepolia (10004): [0x5845E08d890E21687F7Ebf7CbAbD360cD91c6245](https://sepolia.basescan.org/address/0x5845E08d890E21687F7Ebf7CbAbD360cD91c6245)
- Avalanche Fuji (6): [0x4e9Af03fbf1aa2b79A2D4babD3e22e09f18Bb8EE](https://testnet.snowtrace.io/address/0x4e9Af03fbf1aa2b79A2D4babD3e22e09f18Bb8EE)
- Sei EVM (40): [0x3F2D6441C7a59Dfe80f8e14142F9E28F6D440445](https://seitrace.com/?chain=atlantic-2/address/0x3F2D6441C7a59Dfe80f8e14142F9E28F6D440445)
- Converge (53): [0x3d8c26b67BDf630FBB44F09266aFA735F1129197](https://explorer-converge-testnet-1.t.conduit.xyz/address/0x3d8c26b67BDf630FBB44F09266aFA735F1129197)

### DEPRECATED: May 27, 2025

This version fixes a possible overflow in the fee calculation.

Note: Needed to update foundry from that used for the previous version because that is no longer available.

#### Version Info

Commit Hash:

<!-- cspell:disable -->

```sh
example-ntt-with-executor (main)$ git rev-parse HEAD
c6845e4dc61e7c707a42bd1088a87eb3b5b62fb5
example-ntt-with-executor (main)$
```

<!-- cspell:enable -->

Foundry Version:

<!-- cspell:disable -->

```sh
evm (main)$ forge --version
forge Version: 1.2.1-stable
Commit SHA: 42341d5c94947d566c21a539aead92c4c53837a2
Build Timestamp: 2025-05-26T05:24:48.799227114Z (1748237088)
Build Profile: maxperf
evm (main)$
```

<!-- cspell:enable -->

#### Chains Deployed

Here are the deployed contract addresses for each chain. The number after the chain name is the Wormhole chain ID configured for the contract.

- Sepolia (10002): [0xeE4ECA827e999F0489099ac35b10c4bE5036C422](https://sepolia.etherscan.io/address/0xeE4ECA827e999F0489099ac35b10c4bE5036C422)
- Base Sepolia (10004): [0x49D2c608Ae52b456A3896efa296e4F555f5BE480](https://sepolia.basescan.org/address/0x49D2c608Ae52b456A3896efa296e4F555f5BE480)
- Avalanche Fuji (6): [0x246E3968dA8f9aA3608BAa9FdBe83c8EB6B51671](https://testnet.snowtrace.io/address/0x246E3968dA8f9aA3608BAa9FdBe83c8EB6B51671)

### DEPRECATED: April 17, 2025

#### Version Info

Commit Hash:

<!-- cspell:disable -->

```sh
example-ntt-with-executor (main)$ git rev-parse HEAD
736fbd1dfaf28d19120effbf3c4a063ed640cee8
example-ntt-with-executor (main)$
```

<!-- cspell:enable -->

Foundry Version:

<!-- cspell:disable -->

```sh
evm (main)$ forge --version
forge Version: 1.0.0-stable
Commit SHA: e144b82070619b6e10485c38734b4d4d45aebe04
Build Timestamp: 2025-02-13T20:03:31.026474817Z (1739477011)
Build Profile: maxperf
evm (main)$
```

<!-- cspell:enable -->

#### Chains Deployed

Here are the deployed contract addresses for each chain. The number after the chain name is the Wormhole chain ID configured for the contract.

- Sepolia (10002): [0xB5F173b5167Cd7E67909a947fADD4b70FFa22759](https://sepolia.etherscan.io/address/0xB5F173b5167Cd7E67909a947fADD4b70FFa22759)
- Base Sepolia (10004): [0x6E7d8fBcC2821084CA1de9b97931FF9fEDAeE57e](https://sepolia.basescan.org/address/0x6E7d8fBcC2821084CA1de9b97931FF9fEDAeE57e)
- Avalanche Fuji (6): [0xFFe534e5d8bf7Ff8159765c5Ccc89E71B622CAff](https://testnet.snowtrace.io/address/0xFFe534e5d8bf7Ff8159765c5Ccc89E71B622CAff)

### DEPRECATED: March 18, 2025

#### Version Info

Commit Hash:

<!-- cspell:disable -->

```sh
example-ntt-with-executor (main)$ git rev-parse HEAD
46e0ad7d2e3e3814d963afed80b1e1f7f774aa49
example-ntt-with-executor (main)$
```

<!-- cspell:enable -->

Foundry Version:

<!-- cspell:disable -->

```sh
evm (main)$ forge --version
forge Version: 1.0.0-stable
Commit SHA: e144b82070619b6e10485c38734b4d4d45aebe04
Build Timestamp: 2025-02-13T20:03:31.026474817Z (1739477011)
Build Profile: maxperf
evm (main)$
```

<!-- cspell:enable -->

#### Chains Deployed

Here are the deployed contract addresses for each chain. The number after the chain name is the Wormhole chain ID configured for the contract.

- Sepolia (10002): [0xc15c5e2C79a5123677aA751Fb9415424530722A9](https://sepolia.etherscan.io/address/0xc15c5e2C79a5123677aA751Fb9415424530722A9)
- Base Sepolia (10004): [0xfD0eF3858a57db6626E36892DAE3dA4935600e94](https://sepolia.basescan.org/address/0xfD0eF3858a57db6626E36892DAE3dA4935600e94)
- Avalanche Fuji (6): [0x63D1cA54e198d2fFAf93cE51Cb88a618a3a4Ea50](https://testnet.snowtrace.io/address/0x63D1cA54e198d2fFAf93cE51Cb88a618a3a4Ea50)

### Bytecode Verification

If you wish to verify that the bytecode built locally matches what is deployed on chain, you can do something like this:

<!-- cspell:disable -->

```
forge verify-bytecode <contract_addr> NttManagerWithExecutor --rpc-url <archive_node_rpc> --verifier-api-key <your_etherscan_key>
```

<!-- cspell:enable -->
