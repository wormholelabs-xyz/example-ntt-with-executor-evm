# Example NTT With Executor EVM

This repo contains an EVM helper contract for bundling an [NTT](https://github.com/wormhole-foundation/native-token-transfers) transfer with an [Executor](https://github.com/wormholelabs-xyz/example-messaging-executor) request for execution in a single transaction.

For the SVM (Solana) contract, see https://github.com/wormholelabs-xyz/example-ntt-with-executor-svm

Deployments can be found at https://wormholelabs.notion.site/Executor-Addresses-Public-1f93029e88cb80df940eeb8867a01081

## Example Usage

First, build the contracts to generate the ABI:

```bash
forge build
```

Here's a basic example using viem to approve and transfer tokens:

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

  // Step 1: Approve tokens
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
        dbps: 0, // referrer fee
        payee: account.address,
      },
    ],
    value: estimatedCost,
  });

  console.log("Transfer complete:", transferTx);
}

transferWithExecutor().catch(console.error);
```

**Notes**:

- For Solana transfers, convert recipient addresses from base58 to 32-byte hex format

⚠ **This software is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
implied. See the License for the specific language governing permissions and limitations under the License.** Or plainly
spoken - this is a very complex piece of software which targets a bleeding-edge, experimental smart contract runtime.
Mistakes happen, and no matter how hard you try and whether you pay someone to audit it, it may eat your tokens, set
your printer on fire or startle your cat. Cryptocurrencies are a high-risk investment, no matter how fancy.
