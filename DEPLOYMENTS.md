# NttManagerWithExecutor EVM Deployments

## Testnet

### April 17, 2025

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
