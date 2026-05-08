// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {NttManagerWithExecutor, nttManagerWithExecutorVersion} from "../src/v1/NttManagerWithExecutor.sol";
import "forge-std/Script.sol";

// DeployNttManagerWithExecutorV1 is a forge script to deploy the NttManagerWithExecutor v0.0.1 contract.
// Use ./sh/deployNttManagerWithExecutorV1.sh to invoke this.
contract DeployNttManagerWithExecutorV1 is Script {
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
