// SPDX-License-Identifier: Apache 2
pragma solidity >=0.8.8 <0.9.0;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Upgrade.sol";

import {Executor} from "example-messaging-executor/evm/src/Executor.sol";
import {ExecutorWithToken} from "example-messaging-executor/evm/src/ExecutorWithToken.sol";
import {IExecutor} from "example-messaging-executor/evm/src/interfaces/IExecutor.sol";
import "native-token-transfers/evm/src/NttManager/NttManager.sol";
import "native-token-transfers/evm/src/NttManager/NttManagerNoRateLimiting.sol";
import "native-token-transfers/evm/src/Transceiver/Transceiver.sol";

import "../src/NttManagerWithExecutorWithToken.sol";
import "../src/interfaces/INttManagerWithExecutorWithToken.sol";

contract MockToken is ERC20, ERC1967Upgrade {
    constructor() ERC20("MockToken", "DTKN") {}

    // NOTE: this is purposefully not called mint() to so we can test that in
    // locking mode the NttManager contract doesn't call mint (or burn)
    function mintDummy(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function mint(address, uint256) public virtual {
        revert("Locking nttManager should not call 'mint()'");
    }

    function burnFrom(address, uint256) public virtual {
        revert("No nttManager should call 'burnFrom()'");
    }

    function burn(address, uint256) public virtual {
        revert("Locking nttManager should not call 'burn()'");
    }

    function upgrade(address newImplementation) public {
        _upgradeTo(newImplementation);
    }
}

contract MockExecutorPaymentToken is ERC20 {
    constructor() ERC20("MockPaymentToken", "MPT") {}

    function mintDummy(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract MockExecutorWithToken is ExecutorWithToken {
    uint16 public immutable ourChain;
    address public immutable defaultPayee;

    constructor(uint16 _chainId, address _executor, address _defaultPayee) ExecutorWithToken(_executor) {
        ourChain = _chainId;
        defaultPayee = _defaultPayee;
    }

    // NOTE: This was copied from the tests in the executor repo.
    function encodeSignedQuoteHeader(Executor.SignedQuoteHeader memory signedQuote)
        public
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            signedQuote.prefix,
            signedQuote.quoterAddress,
            signedQuote.payeeAddress,
            signedQuote.srcChain,
            signedQuote.dstChain,
            signedQuote.expiryTime
        );
    }

    function createSignedQuote(uint16 dstChain) public view returns (bytes memory) {
        return createSignedQuote(dstChain, 60);
    }

    function createSignedQuote(uint16 dstChain, uint64 quoteLife) public view returns (bytes memory) {
        Executor.SignedQuoteHeader memory signedQuote = IExecutor.SignedQuoteHeader({
            prefix: "EQ03",
            quoterAddress: address(0),
            payeeAddress: bytes32(uint256(uint160(defaultPayee))),
            srcChain: ourChain,
            dstChain: dstChain,
            expiryTime: uint64(block.timestamp + quoteLife)
        });
        return encodeSignedQuoteHeader(signedQuote);
    }

    function createExecutorInstructions() public pure returns (bytes memory) {
        return new bytes(0);
    }

    function createArgs(uint16 dstChain, uint256 value, uint256 amount, address srcToken)
        public
        view
        returns (ExecutorWithTokenArgs memory args)
    {
        args.value = value;
        args.amount = amount;
        args.srcToken = srcToken;
        args.refundAddress = msg.sender;
        args.signedQuote = createSignedQuote(dstChain);
        args.instructions = createExecutorInstructions();
    }

    function msgValue() public pure returns (uint256) {
        return 0;
    }
}

contract MockNttManager is NttManager {
    constructor(address token, Mode mode, uint16 chainId, uint64 rateLimitDuration, bool skipRateLimiting)
        NttManager(token, mode, chainId, rateLimitDuration, skipRateLimiting)
    {}
}

contract MockNttManagerNoRateLimiting is NttManagerNoRateLimiting {
    constructor(address token, Mode mode, uint16 chainId) NttManagerNoRateLimiting(token, mode, chainId) {}
}

contract MockTransceiver is Transceiver {
    uint16 constant SENDING_CHAIN_ID = 1;
    bytes4 constant TEST_TRANSCEIVER_PAYLOAD_PREFIX = 0x99455454;

    constructor(address nttManager) Transceiver(nttManager) {}

    function getTransceiverType() external pure override returns (string memory) {
        return "dummy";
    }

    function _quoteDeliveryPrice(
        uint16, /* recipientChain */
        TransceiverStructs.TransceiverInstruction memory /* transceiverInstruction */
    ) internal pure override returns (uint256) {
        return 0;
    }

    function _sendMessage(
        uint16, /* recipientChain */
        uint256, /* deliveryPayment */
        address, /* caller */
        bytes32, /* recipientNttManagerAddress */
        bytes32, /* refundAddres */
        TransceiverStructs.TransceiverInstruction memory, /* instruction */
        bytes memory /* payload */
    ) internal override {
        // do nothing
    }

    function receiveMessage(bytes memory encodedMessage) external {
        TransceiverStructs.TransceiverMessage memory parsedTransceiverMessage;
        TransceiverStructs.NttManagerMessage memory parsedNttManagerMessage;
        (parsedTransceiverMessage, parsedNttManagerMessage) =
            TransceiverStructs.parseTransceiverAndNttManagerMessage(TEST_TRANSCEIVER_PAYLOAD_PREFIX, encodedMessage);
        _deliverToNttManager(
            SENDING_CHAIN_ID,
            parsedTransceiverMessage.sourceNttManagerAddress,
            parsedTransceiverMessage.recipientNttManagerAddress,
            parsedNttManagerMessage
        );
    }

    function parseMessageFromLogs(Vm.Log[] memory logs)
        public
        pure
        returns (uint16 recipientChain, bytes memory payload)
    {}
}

// TODO: set this up so the common functionality tests can be run against both
contract TestNttManagerWithExecutorWithToken is Test {
    NttManagerWithExecutorWithToken nttManagerWithExecutorWithToken;
    Executor executor;
    MockExecutorWithToken executorWithToken;
    MockNttManager nttManager;
    MockNttManagerNoRateLimiting nttManagerNoRateLimiting;
    MockTransceiver transceiver;
    MockTransceiver transceiverNoRateLimiting;
    MockExecutorPaymentToken executorPaymentToken;

    using TrimmedAmountLib for uint256;
    using TrimmedAmountLib for TrimmedAmount;

    uint16 constant chainId = 7;
    uint16 constant chainId2 = 8;

    address user_A = address(0x123);
    address user_B = address(0x456);
    address referrer = address(0x789);
    address executorPayee = address(0xABC);

    function setUp() public {
        executor = new Executor(chainId);
        executorWithToken = new MockExecutorWithToken(chainId, address(executor), executorPayee);
        nttManagerWithExecutorWithToken = new NttManagerWithExecutorWithToken(chainId, address(executorWithToken));

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

        // Deploy the executor payment token.
        executorPaymentToken = new MockExecutorPaymentToken();

        // Give everyone some money to play with.
        vm.deal(user_A, 1 ether);
        vm.deal(user_B, 1 ether);
        vm.deal(referrer, 1 ether);
        vm.deal(executorPayee, 1 ether);
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

    function test_transferWithExecutorWithToken() public {
        MockToken token = MockToken(nttManager.token());
        uint8 decimals = token.decimals();
        uint8 peerDecimals = 9;
        uint256 transferTokenFee = 1;
        uint256 nativeTokenFee = 2;
        uint256 executorTokenAmount = 500;
        token.mintDummy(address(user_A), 5 * 10 ** decimals);
        executorPaymentToken.mintDummy(address(user_A), 10000);

        nttManager.setPeer(chainId2, toWormholeFormat(address(0x1)), peerDecimals, type(uint64).max);
        nttManager.setOutboundLimit(packTrimmedAmount(type(uint64).max, 8).untrim(decimals));

        vm.startPrank(user_A);
        token.approve(address(nttManagerWithExecutorWithToken), 1 * 10 ** decimals + transferTokenFee);
        executorPaymentToken.approve(address(nttManagerWithExecutorWithToken), executorTokenAmount);

        uint256 startingBalance = token.balanceOf(address(user_A));
        uint256 startingExecutorTokenBalance = executorPaymentToken.balanceOf(address(user_A));
        uint256 nttManagerStartingBalance = address(nttManagerWithExecutorWithToken).balance;
        uint256 amount = 123000000000000;

        uint256 expectedTokenFee = transferTokenFee;
        uint256 expectedNativeFee = address(referrer).balance + nativeTokenFee;

        ExecutorWithTokenArgs memory executorArgs =
            executorWithToken.createArgs(chainId2, 100, executorTokenAmount, address(executorPaymentToken));
        FeeArgs memory feeArgs =
            FeeArgs({transferTokenFee: transferTokenFee, nativeTokenFee: nativeTokenFee, payee: referrer});
        uint64 s1 = nttManagerWithExecutorWithToken.transfer{value: 10000}(
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
        uint256 nttManagerEndingBalance = address(nttManagerWithExecutorWithToken).balance;
        assertEq(nttManagerEndingBalance, nttManagerStartingBalance);
        assertEq(expectedTokenFee, token.balanceOf(referrer));
        assertEq(expectedNativeFee, address(referrer).balance);
        // Verify the executor payment token was transferred from the user.
        assertEq(executorPaymentToken.balanceOf(address(user_A)), startingExecutorTokenBalance - executorTokenAmount);
    }

    function test_transferWithExecutorWithTokenNoRateLimiting() public {
        MockToken token = MockToken(nttManagerNoRateLimiting.token());
        uint8 decimals = token.decimals();
        uint256 transferTokenFee = 1;
        uint256 nativeTokenFee = 2;
        uint256 executorTokenAmount = 500;
        token.mintDummy(address(user_A), 5 * 10 ** decimals);
        executorPaymentToken.mintDummy(address(user_A), 10000);

        nttManagerNoRateLimiting.setPeer(chainId2, toWormholeFormat(address(0x1)), 9, type(uint64).max);
        nttManagerNoRateLimiting.setOutboundLimit(packTrimmedAmount(type(uint64).max, 8).untrim(decimals));

        vm.startPrank(user_A);
        token.approve(address(nttManagerWithExecutorWithToken), 1 * 10 ** decimals + transferTokenFee);
        executorPaymentToken.approve(address(nttManagerWithExecutorWithToken), executorTokenAmount);

        uint256 startingBalance = token.balanceOf(address(user_A));
        uint256 startingExecutorTokenBalance = executorPaymentToken.balanceOf(address(user_A));
        uint256 nttManagerStartingBalance = address(nttManagerWithExecutorWithToken).balance;
        uint256 amount = 1 * 10 ** decimals;

        uint256 expectedTokenFee = transferTokenFee;
        uint256 expectedNativeFee = address(referrer).balance + nativeTokenFee;

        ExecutorWithTokenArgs memory executorArgs =
            executorWithToken.createArgs(chainId2, 100, executorTokenAmount, address(executorPaymentToken));
        FeeArgs memory feeArgs =
            FeeArgs({transferTokenFee: transferTokenFee, nativeTokenFee: nativeTokenFee, payee: referrer});
        uint64 s1 = nttManagerWithExecutorWithToken.transfer{value: 10000}(
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
        uint256 nttManagerEndingBalance = address(nttManagerWithExecutorWithToken).balance;
        assertEq(nttManagerEndingBalance, nttManagerStartingBalance);
        assertEq(expectedTokenFee, token.balanceOf(referrer));
        assertEq(expectedNativeFee, address(referrer).balance);
        assertEq(executorPaymentToken.balanceOf(address(user_A)), startingExecutorTokenBalance - executorTokenAmount);
    }

    function test_transferWithExecutorWithTokenNoFee() public {
        MockToken token = MockToken(nttManager.token());
        uint8 decimals = token.decimals();
        uint256 executorTokenAmount = 500;
        token.mintDummy(address(user_A), 5 * 10 ** decimals);
        executorPaymentToken.mintDummy(address(user_A), 10000);

        nttManager.setPeer(chainId2, toWormholeFormat(address(0x1)), 9, type(uint64).max);
        nttManager.setOutboundLimit(packTrimmedAmount(type(uint64).max, 8).untrim(decimals));

        vm.startPrank(user_A);
        token.approve(address(nttManagerWithExecutorWithToken), 1 * 10 ** decimals);
        executorPaymentToken.approve(address(nttManagerWithExecutorWithToken), executorTokenAmount);

        uint256 startingBalance = token.balanceOf(address(user_A));
        uint256 startingExecutorTokenBalance = executorPaymentToken.balanceOf(address(user_A));
        uint256 nttManagerStartingBalance = address(nttManagerWithExecutorWithToken).balance;
        uint256 amount = 1 * 10 ** decimals;

        ExecutorWithTokenArgs memory executorArgs =
            executorWithToken.createArgs(chainId2, 100, executorTokenAmount, address(executorPaymentToken));
        FeeArgs memory feeArgs = FeeArgs({transferTokenFee: 0, nativeTokenFee: 0, payee: address(0)});
        uint64 s1 = nttManagerWithExecutorWithToken.transfer{value: 10000}(
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
        uint256 nttManagerEndingBalance = address(nttManagerWithExecutorWithToken).balance;
        assertEq(nttManagerEndingBalance, nttManagerStartingBalance);
        assertEq(executorPaymentToken.balanceOf(address(user_A)), startingExecutorTokenBalance - executorTokenAmount);
    }
}
