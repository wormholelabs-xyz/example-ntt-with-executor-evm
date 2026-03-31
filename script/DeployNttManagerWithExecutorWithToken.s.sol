// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {
    NttManagerWithExecutorWithToken,
    nttManagerWithExecutorWithTokenVersion
} from "../src/NttManagerWithExecutorWithToken.sol";
import "forge-std/Script.sol";

// DeployNttManagerWithExecutorWithToken is a forge script to deploy the NttManagerWithExecutorWithToken contract. Use ./sh/deployNttManagerWithExecutorWithToken.sh to invoke this.
// e.g. anvil
// EVM_CHAIN_ID=31337 MNEMONIC=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 OUR_CHAIN_ID=2 ./sh/deployNttManagerWithExecutorWithToken.sh
// e.g. anvil --fork-url https://ethereum-rpc.publicnode.com
// EVM_CHAIN_ID=1 MNEMONIC=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 OUR_CHAIN_ID=2 ./sh/deployNttManagerWithExecutorWithToken.sh
contract DeployNttManagerWithExecutorWithToken is Script {
    function test() public {} // Exclude this from coverage report.

    function dryRun(uint16 ourChain, address executorWithToken) public {
        _deploy(ourChain, executorWithToken);
    }

    function run(uint16 ourChain, address executorWithToken) public returns (address deployedAddress) {
        vm.startBroadcast();
        (deployedAddress) = _deploy(ourChain, executorWithToken);
        vm.stopBroadcast();
    }

    function _deploy(uint16 ourChain, address executorWithToken) internal returns (address deployedAddress) {
        bytes32 salt = keccak256(abi.encodePacked(nttManagerWithExecutorWithTokenVersion));
        NttManagerWithExecutorWithToken nttManagerWithExecutorWithToken =
            new NttManagerWithExecutorWithToken{salt: salt}(ourChain, executorWithToken);

        return (address(nttManagerWithExecutorWithToken));
    }
}
