// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NttManagerWithExecutor, nttManagerWithExecutorVersion} from "../src/NttManagerWithExecutor.sol";
import "forge-std/Script.sol";

// DeployNttManagerWithExecutor is a forge script to deploy the NttManagerWithExecutor contract. Use ./sh/deployNttManagerWithExecutor.sh to invoke this.
// e.g. anvil
// EVM_CHAIN_ID=31337 MNEMONIC=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 OUR_CHAIN_ID=2 ./sh/deployNttManagerWithExecutor.sh
// e.g. anvil --fork-url https://ethereum-rpc.publicnode.com
// EVM_CHAIN_ID=1 MNEMONIC=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 OUR_CHAIN_ID=2 ./sh/deployNttManagerWithExecutor.sh
contract DeployNttManagerWithExecutor is Script {
    function test() public {} // Exclude this from coverage report.

    function dryRun(uint16 ourChain, address executor) public {
        _deploy(ourChain, executor);
    }

    function run(uint16 ourChain, address executor) public returns (address deployedAddress) {
        vm.startBroadcast();
        (deployedAddress) = _deploy(ourChain, executor);
        vm.stopBroadcast();
    }

    function _deploy(uint16 ourChain, address executor) internal returns (address deployedAddress) {
        bytes32 salt = keccak256(abi.encodePacked(nttManagerWithExecutorVersion));
        NttManagerWithExecutor nttManagerWithExecutor = new NttManagerWithExecutor{salt: salt}(ourChain, executor);

        return (address(nttManagerWithExecutor));
    }
}
