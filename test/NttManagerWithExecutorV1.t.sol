// SPDX-License-Identifier: Apache 2
pragma solidity >=0.8.8 <0.9.0;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "./Mocks.sol";

import {NttManagerWithExecutor, nttManagerWithExecutorVersion} from "../src/v1/NttManagerWithExecutor.sol";
import "../src/v1/interfaces/INttManagerWithExecutor.sol";

contract TestNttManagerWithExecutorV1 is Test {
    NttManagerWithExecutor nttManagerWithExecutor;
    MockExecutor executor;
    MockNttManager nttManager;
    MockNttManagerNoRateLimiting nttManagerNoRateLimiting;
    MockTransceiver transceiver;
    MockTransceiver transceiverNoRateLimiting;

    using TrimmedAmountLib for uint256;
    using TrimmedAmountLib for TrimmedAmount;

    uint16 constant chainId = 7;
    uint16 constant chainId2 = 8;

    address user_A = address(0x123);
    address user_B = address(0x456);
    address referrer = address(0x789);

    function _createExecutorArgs(uint16 dstChain, uint256 value) internal view returns (ExecutorArgs memory args) {
        args.value = value;
        args.refundAddress = msg.sender;
        args.signedQuote = executor.createSignedQuote(dstChain);
        args.instructions = executor.createExecutorInstructions();
    }

    function setUp() public {
        executor = new MockExecutor(chainId);
        nttManagerWithExecutor = new NttManagerWithExecutor(chainId, address(executor));

        string memory url = "https://ethereum-sepolia-rpc.publicnode.com";
        vm.createSelectFork(url);

        MockToken t = new MockToken();

        NttManager implementation = new MockNttManager(address(t), IManagerBase.Mode.LOCKING, chainId, 0, true);

        nttManager = MockNttManager(address(new ERC1967Proxy(address(implementation), "")));
        nttManager.initialize();

        NttManagerNoRateLimiting implementationNoRateLimiting =
            new MockNttManagerNoRateLimiting(address(t), IManagerBase.Mode.LOCKING, chainId);

        nttManagerNoRateLimiting =
            MockNttManagerNoRateLimiting(address(new ERC1967Proxy(address(implementationNoRateLimiting), "")));
        nttManagerNoRateLimiting.initialize();

        transceiver = new MockTransceiver(address(nttManager));
        nttManager.setTransceiver(address(transceiver));

        transceiverNoRateLimiting = new MockTransceiver(address(nttManagerNoRateLimiting));
        nttManagerNoRateLimiting.setTransceiver(address(transceiverNoRateLimiting));

        // Give everyone some money to play with.
        vm.deal(user_A, 1 ether);
        vm.deal(user_B, 1 ether);
        vm.deal(referrer, 1 ether);
    }

    function test_directTransfer() public {
        MockToken token = MockToken(nttManager.token());
        uint8 decimals = token.decimals();
        token.mintDummy(address(user_A), 5 * 10 ** decimals);

        nttManager.setPeer(chainId2, toWormholeFormat(address(0x1)), 9, type(uint64).max);
        nttManager.setOutboundLimit(packTrimmedAmount(type(uint64).max, 8).untrim(decimals));

        vm.startPrank(user_A);
        token.approve(address(nttManager), 3 * 10 ** decimals);

        uint64 s1 = nttManager.transfer{value: 10000}(
            1 * 10 ** decimals, chainId2, toWormholeFormat(user_B), toWormholeFormat(user_A), false, new bytes(1)
        );

        assertEq(s1, 0);
    }

    function test_transferWithExecutor() public {
        MockToken token = MockToken(nttManager.token());
        uint8 decimals = token.decimals();
        uint8 peerDecimals = 9;
        token.mintDummy(address(user_A), 5 * 10 ** decimals);

        nttManager.setPeer(chainId2, toWormholeFormat(address(0x1)), peerDecimals, type(uint64).max);
        nttManager.setOutboundLimit(packTrimmedAmount(type(uint64).max, 8).untrim(decimals));

        vm.startPrank(user_A);
        token.approve(address(nttManagerWithExecutor), 1 * 10 ** decimals);

        uint256 startingBalance = token.balanceOf(address(user_A));
        uint256 nttManagerStartingBalance = address(nttManagerWithExecutor).balance;
        uint256 amount = 123000000000000;

        uint16 dbps = 100;
        uint256 expectedFee = nttManagerWithExecutor.calculateFee(amount, dbps);

        // The combination of this amount and dbps gives us a fee with dust. Remove that from the expected fee.
        expectedFee = expectedFee.trim(decimals, peerDecimals).untrim(decimals);

        ExecutorArgs memory executorArgs = _createExecutorArgs(chainId2, 100);
        FeeArgs memory feeArgs = FeeArgs({dbps: dbps, payee: referrer});
        uint64 s1 = nttManagerWithExecutor.transfer{value: 10000}(
            address(nttManager),
            amount,
            chainId2,
            toWormholeFormat(user_B),
            toWormholeFormat(user_A),
            new bytes(1),
            executorArgs,
            feeArgs
        );

        assertEq(s1, 0);

        uint256 endingBalance = token.balanceOf(address(user_A));
        assertEq(endingBalance, startingBalance - amount);
        uint256 nttManagerEndingBalance = address(nttManagerWithExecutor).balance;
        assertEq(nttManagerEndingBalance, nttManagerStartingBalance);
        assertEq(expectedFee, token.balanceOf(referrer));
    }

    function test_transferWithExecutorNoRateLimiting() public {
        MockToken token = MockToken(nttManagerNoRateLimiting.token());
        uint8 decimals = token.decimals();
        token.mintDummy(address(user_A), 5 * 10 ** decimals);

        nttManagerNoRateLimiting.setPeer(chainId2, toWormholeFormat(address(0x1)), 9, type(uint64).max);
        nttManagerNoRateLimiting.setOutboundLimit(packTrimmedAmount(type(uint64).max, 8).untrim(decimals));

        vm.startPrank(user_A);
        token.approve(address(nttManagerWithExecutor), 1 * 10 ** decimals);

        uint256 startingBalance = token.balanceOf(address(user_A));
        uint256 nttManagerStartingBalance = address(nttManagerWithExecutor).balance;
        uint256 amount = 1 * 10 ** decimals;
        uint256 expectedFee = (amount * 1) / 100000;

        ExecutorArgs memory executorArgs = _createExecutorArgs(chainId2, 100);
        FeeArgs memory feeArgs = FeeArgs({dbps: 1, payee: referrer});
        uint64 s1 = nttManagerWithExecutor.transfer{value: 10000}(
            address(nttManagerNoRateLimiting),
            amount,
            chainId2,
            toWormholeFormat(user_B),
            toWormholeFormat(user_A),
            new bytes(1),
            executorArgs,
            feeArgs
        );

        assertEq(s1, 0);

        uint256 endingBalance = token.balanceOf(address(user_A));
        assertEq(endingBalance, startingBalance - amount);
        uint256 nttManagerEndingBalance = address(nttManagerWithExecutor).balance;
        assertEq(nttManagerEndingBalance, nttManagerStartingBalance);
        assertEq(expectedFee, token.balanceOf(referrer));
    }

    function test_calculateFee() public view {
        assertEq(12345, nttManagerWithExecutor.calculateFee(123456, 10000));
        assertEq(1234, nttManagerWithExecutor.calculateFee(123456, 1000));
        assertEq(123, nttManagerWithExecutor.calculateFee(123456, 100));
        assertEq(12, nttManagerWithExecutor.calculateFee(123456, 10));
        assertEq(1, nttManagerWithExecutor.calculateFee(123456, 1));

        // A zero fee is valid.
        assertEq(0, nttManagerWithExecutor.calculateFee(123456, 0));

        // A zero result is valid.
        assertEq(0, nttManagerWithExecutor.calculateFee(1, 1));

        // Try the max fee.
        assertEq(80907406, nttManagerWithExecutor.calculateFee(123456789, type(uint16).max));

        // Try the max amount
        assertEq(
            75884345681675168670837245025443620411640484450627543643258527679585869509531,
            nttManagerWithExecutor.calculateFee(type(uint256).max, type(uint16).max)
        );
        assertEq(type(uint256).max / 100000, nttManagerWithExecutor.calculateFee(type(uint256).max, 1));
        assertEq(0, nttManagerWithExecutor.calculateFee(type(uint256).max, 0));
    }

    // @dev This test verifies that the new calculation does not over/under flow.
    function test_calculateFeeFuzz(uint256 amount, uint16 dbps) public view returns (uint256 fee) {
        fee = nttManagerWithExecutor.calculateFee(amount, dbps);
    }
}
