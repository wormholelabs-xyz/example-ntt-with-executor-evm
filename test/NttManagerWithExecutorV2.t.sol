// SPDX-License-Identifier: Apache 2
pragma solidity >=0.8.8 <0.9.0;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "./Mocks.sol";

import {NttManagerWithExecutor, nttManagerWithExecutorVersion} from "../src/v2/NttManagerWithExecutor.sol";
import "../src/v2/interfaces/INttManagerWithExecutor.sol";

contract TestNttManagerWithExecutorV2 is Test {
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
        uint256 transferTokenFee = 1;
        uint256 nativeTokenFee = 2;
        token.mintDummy(address(user_A), 5 * 10 ** decimals);

        nttManager.setPeer(chainId2, toWormholeFormat(address(0x1)), peerDecimals, type(uint64).max);
        nttManager.setOutboundLimit(packTrimmedAmount(type(uint64).max, 8).untrim(decimals));

        vm.startPrank(user_A);
        token.approve(address(nttManagerWithExecutor), 1 * 10 ** decimals + transferTokenFee);

        uint256 startingBalance = token.balanceOf(address(user_A));
        uint256 nttManagerStartingBalance = address(nttManagerWithExecutor).balance;
        uint256 amount = 123000000000000;

        uint256 expectedTokenFee = transferTokenFee;
        uint256 expectedNativeFee = address(referrer).balance + nativeTokenFee;

        ExecutorArgs memory executorArgs = _createExecutorArgs(chainId2, 100);
        FeeArgs memory feeArgs =
            FeeArgs({transferTokenFee: transferTokenFee, nativeTokenFee: nativeTokenFee, payee: referrer});
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
        assertEq(endingBalance, startingBalance - amount - transferTokenFee);
        uint256 nttManagerEndingBalance = address(nttManagerWithExecutor).balance;
        assertEq(nttManagerEndingBalance, nttManagerStartingBalance);
        assertEq(expectedTokenFee, token.balanceOf(referrer));
        assertEq(expectedNativeFee, address(referrer).balance);
    }

    function test_transferWithExecutorNoRateLimiting() public {
        MockToken token = MockToken(nttManagerNoRateLimiting.token());
        uint8 decimals = token.decimals();
        uint256 transferTokenFee = 1;
        uint256 nativeTokenFee = 2;
        token.mintDummy(address(user_A), 5 * 10 ** decimals);

        nttManagerNoRateLimiting.setPeer(chainId2, toWormholeFormat(address(0x1)), 9, type(uint64).max);
        nttManagerNoRateLimiting.setOutboundLimit(packTrimmedAmount(type(uint64).max, 8).untrim(decimals));

        vm.startPrank(user_A);
        token.approve(address(nttManagerWithExecutor), 1 * 10 ** decimals + transferTokenFee);

        uint256 startingBalance = token.balanceOf(address(user_A));
        uint256 nttManagerStartingBalance = address(nttManagerWithExecutor).balance;
        uint256 amount = 1 * 10 ** decimals;

        uint256 expectedTokenFee = transferTokenFee;
        uint256 expectedNativeFee = address(referrer).balance + nativeTokenFee;

        ExecutorArgs memory executorArgs = _createExecutorArgs(chainId2, 100);
        FeeArgs memory feeArgs =
            FeeArgs({transferTokenFee: transferTokenFee, nativeTokenFee: nativeTokenFee, payee: referrer});
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
        assertEq(endingBalance, startingBalance - amount - transferTokenFee);
        uint256 nttManagerEndingBalance = address(nttManagerWithExecutor).balance;
        assertEq(nttManagerEndingBalance, nttManagerStartingBalance);
        assertEq(expectedTokenFee, token.balanceOf(referrer));
        assertEq(expectedNativeFee, address(referrer).balance);
    }

    function test_transferWithExecutorNoFee() public {
        MockToken token = MockToken(nttManager.token());
        uint8 decimals = token.decimals();
        token.mintDummy(address(user_A), 5 * 10 ** decimals);

        nttManager.setPeer(chainId2, toWormholeFormat(address(0x1)), 9, type(uint64).max);
        nttManager.setOutboundLimit(packTrimmedAmount(type(uint64).max, 8).untrim(decimals));

        vm.startPrank(user_A);
        token.approve(address(nttManagerWithExecutor), 1 * 10 ** decimals);

        uint256 startingBalance = token.balanceOf(address(user_A));
        uint256 nttManagerStartingBalance = address(nttManagerWithExecutor).balance;
        uint256 amount = 1 * 10 ** decimals;

        ExecutorArgs memory executorArgs = _createExecutorArgs(chainId2, 100);
        FeeArgs memory feeArgs = FeeArgs({transferTokenFee: 0, nativeTokenFee: 0, payee: address(0)});
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
    }
}
