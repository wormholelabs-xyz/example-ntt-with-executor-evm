# Example NTT With Executor EVM

This repo contains EVM helper contracts for bundling an [NTT](https://github.com/wormhole-foundation/native-token-transfers) transfer with an [Executor](https://github.com/wormholelabs-xyz/example-messaging-executor) request for execution in a single transaction.

For the SVM (Solana) contract, see https://github.com/wormholelabs-xyz/example-ntt-with-executor-svm

Deployments can be found at https://wormholelabs.notion.site/Executor-Addresses-Public-1f93029e88cb80df940eeb8867a01081

## Contracts

### NttManagerWithExecutor

Bundles an NTT transfer with an Executor relay request (EQ01 — native gas payment). The user pays the executor relay fee in the chain's native token (e.g. ETH).

### NttManagerWithExecutorWithToken

Bundles an NTT transfer with an ExecutorWithToken relay request (EQ03 — token-based payment). The user pays the executor relay fee in an ERC-20 token (e.g. USDC) instead of native gas.

## Version History

### Fee Structure

- **v0.0.1**: Percentage-based referrer fees using `dbps` (tenths of basis points), deducted from the transfer amount.
- **v0.0.2** (current): Fixed referrer fees using `FeeArgs` with `transferTokenFee` (token) and `nativeTokenFee` (native), taken *in addition to* the transfer amount.

## Example Usage

First, build the contracts to generate the ABI:

```bash
forge build
```

### NttManagerWithExecutor (Native Gas Payment)

```javascript
import { createWalletClient, createPublicClient, http, erc20Abi } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { sepolia } from "viem/chains";
import nttExecutorAbi from "./out/NttManagerWithExecutor.sol/NttManagerWithExecutor.json" assert { type: "json" };

const account = privateKeyToAccount("0x...");
const publicClient = createPublicClient({
  chain: sepolia,
  transport: http("https://your-rpc-url.com"),
});
const walletClient = createWalletClient({
  account,
  chain: sepolia,
  transport: http("https://your-rpc-url.com"),
});

async function transferWithExecutor() {
  // Contract addresses
  const tokenAddress = "0x...";
  const nttManagerAddress = "0x...";
  const nttManagerWithExecutorAddress = "0x...";

  // Transfer parameters
  const amount = 1000000000000000n; // Amount to transfer
  const recipientChain = 1; // Target chain ID
  const recipientAddress = "0x..."; // 32-byte recipient address

  // Get quote from executor service (implement based on your executor API)
  const { signedQuote, estimatedCost } = await getExecutorQuote();

  // Step 1: Approve transfer tokens
  await walletClient.writeContract({
    address: tokenAddress,
    abi: erc20Abi,
    functionName: "approve",
    args: [nttManagerWithExecutorAddress, amount],
  });

  // Step 2: Transfer with executor
  const transferTx = await walletClient.writeContract({
    address: nttManagerWithExecutorAddress,
    abi: nttExecutorAbi.abi,
    functionName: "transfer",
    args: [
      nttManagerAddress,
      amount,
      recipientChain,
      recipientAddress,
      recipientAddress, // refund address
      "0x01000101", // encodedInstructions
      {
        value: estimatedCost,
        refundAddress: account.address,
        signedQuote: signedQuote,
        instructions: "0x...", // relay instructions from executor
      },
      {
        transferTokenFee: 0n, // referrer token fee
        nativeTokenFee: 0n, // referrer native fee
        payee: account.address,
      },
    ],
    value: estimatedCost,
  });

  console.log("Transfer complete:", transferTx);
}

transferWithExecutor().catch(console.error);
```

### NttManagerWithExecutorWithToken (Token-Based Payment)

```javascript
import { createWalletClient, createPublicClient, http, erc20Abi } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { sepolia } from "viem/chains";
import nttExecutorWithTokenAbi from "./out/NttManagerWithExecutorWithToken.sol/NttManagerWithExecutorWithToken.json" assert { type: "json" };

const account = privateKeyToAccount("0x...");
const publicClient = createPublicClient({
  chain: sepolia,
  transport: http("https://your-rpc-url.com"),
});
const walletClient = createWalletClient({
  account,
  chain: sepolia,
  transport: http("https://your-rpc-url.com"),
});

async function transferWithExecutorWithToken() {
  // Contract addresses
  const tokenAddress = "0x..."; // NTT transfer token
  const executorPaymentTokenAddress = "0x..."; // Token used to pay executor (e.g. USDC)
  const nttManagerAddress = "0x...";
  const nttManagerWithExecutorWithTokenAddress = "0x...";

  // Transfer parameters
  const amount = 1000000000000000n; // Amount to transfer
  const executorTokenAmount = 1000000n; // Amount to pay executor in payment token
  const recipientChain = 1; // Target chain ID
  const recipientAddress = "0x..."; // 32-byte recipient address

  // Get EQ03 quote from executor service (implement based on your executor API)
  const { signedQuote, wormholeFee } = await getExecutorQuote();

  // Step 1: Approve transfer tokens
  await walletClient.writeContract({
    address: tokenAddress,
    abi: erc20Abi,
    functionName: "approve",
    args: [nttManagerWithExecutorWithTokenAddress, amount],
  });

  // Step 2: Approve executor payment tokens
  await walletClient.writeContract({
    address: executorPaymentTokenAddress,
    abi: erc20Abi,
    functionName: "approve",
    args: [nttManagerWithExecutorWithTokenAddress, executorTokenAmount],
  });

  // Step 3: Transfer with executor (token payment)
  const transferTx = await walletClient.writeContract({
    address: nttManagerWithExecutorWithTokenAddress,
    abi: nttExecutorWithTokenAbi.abi,
    functionName: "transfer",
    args: [
      nttManagerAddress,
      amount,
      recipientChain,
      recipientAddress,
      recipientAddress, // refund address
      "0x01000101", // encodedInstructions
      {
        value: wormholeFee, // native ETH for wormhole fee only
        amount: executorTokenAmount, // executor payment in token
        srcToken: executorPaymentTokenAddress,
        refundAddress: account.address,
        signedQuote: signedQuote, // EQ03 signed quote
        instructions: "0x...", // relay instructions from executor
      },
      {
        transferTokenFee: 0n, // referrer token fee
        nativeTokenFee: 0n, // referrer native fee
        payee: account.address,
      },
    ],
    value: wormholeFee, // only wormhole fee in native ETH
  });

  console.log("Transfer complete:", transferTx);
}

transferWithExecutorWithToken().catch(console.error);
```

**Notes**:

- For Solana transfers, convert recipient addresses from base58 to 32-byte hex format
- `NttManagerWithExecutorWithToken` requires two token approvals: one for the NTT transfer token and one for the executor payment token
- The `value` field in `ExecutorWithTokenArgs` covers native ETH costs (e.g. Wormhole fees) while `amount`/`srcToken` cover the executor relay fee in ERC-20

⚠ **This software is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
implied. See the License for the specific language governing permissions and limitations under the License.** Or plainly
spoken - this is a very complex piece of software which targets a bleeding-edge, experimental smart contract runtime.
Mistakes happen, and no matter how hard you try and whether you pay someone to audit it, it may eat your tokens, set
your printer on fire or startle your cat. Cryptocurrencies are a high-risk investment, no matter how fancy.
