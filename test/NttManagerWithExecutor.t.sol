// SPDX-License-Identifier: Apache 2
pragma solidity >=0.8.8 <0.9.0;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Upgrade.sol";

import "example-messaging-executor/evm/src/Executor.sol";
import "native-token-transfers/evm/src/NttManager/NttManager.sol";
import "native-token-transfers/evm/src/NttManager/NttManagerNoRateLimiting.sol";
import "native-token-transfers/evm/src/Transceiver/Transceiver.sol";

import "../src/NttManagerWithExecutor.sol";
import "../src/interfaces/INttManagerWithExecutor.sol";

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

contract MockExecutor is Executor {
    constructor(uint16 _chainId) Executor(_chainId) {}

    function chainId() public view returns (uint16) {
        return ourChain;
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
            prefix: "EQ01",
            quoterAddress: address(0),
            payeeAddress: bytes32(0),
            srcChain: ourChain,
            dstChain: dstChain,
            expiryTime: uint64(block.timestamp + quoteLife)
        });
        return encodeSignedQuoteHeader(signedQuote);
    }

    function createExecutorInstructions() public pure returns (bytes memory) {
        return new bytes(0);
    }

    function createArgs(uint16 dstChain, uint256 value) public view returns (ExecutorArgs memory args) {
        args.value = value;
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
contract TestNttManagerWithExecutor is Test {
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
        token.mintDummy(address(user_A), 5 * 10 ** decimals);

        nttManager.setPeer(chainId2, toWormholeFormat(address(0x1)), 9, type(uint64).max);
        nttManager.setOutboundLimit(packTrimmedAmount(type(uint64).max, 8).untrim(decimals));

        vm.startPrank(user_A);
        token.approve(address(nttManagerWithExecutor), 3 * 10 ** decimals);

        uint256 startingBalance = address(nttManagerWithExecutor).balance;

        ExecutorArgs memory executorArgs = executor.createArgs(chainId2, 100);
        uint64 s1 = nttManagerWithExecutor.transfer{value: 10000}(
            address(nttManager),
            1 * 10 ** decimals,
            chainId2,
            toWormholeFormat(user_B),
            toWormholeFormat(user_A),
            false,
            new bytes(1),
            executorArgs
        );

        assertEq(s1, 0);

        uint256 endingBalance = address(nttManagerWithExecutor).balance;
        assertEq(endingBalance, startingBalance);
    }

    function test_transferWithExecutorNoRateLimiting() public {
        MockToken token = MockToken(nttManagerNoRateLimiting.token());
        uint8 decimals = token.decimals();
        token.mintDummy(address(user_A), 5 * 10 ** decimals);

        nttManagerNoRateLimiting.setPeer(chainId2, toWormholeFormat(address(0x1)), 9, type(uint64).max);
        nttManagerNoRateLimiting.setOutboundLimit(packTrimmedAmount(type(uint64).max, 8).untrim(decimals));

        vm.startPrank(user_A);
        token.approve(address(nttManagerWithExecutor), 3 * 10 ** decimals);

        uint256 startingBalance = address(nttManagerWithExecutor).balance;

        ExecutorArgs memory executorArgs = executor.createArgs(chainId2, 100);
        uint64 s1 = nttManagerWithExecutor.transfer{value: 10000}(
            address(nttManagerNoRateLimiting),
            1 * 10 ** decimals,
            chainId2,
            toWormholeFormat(user_B),
            toWormholeFormat(user_A),
            false,
            new bytes(1),
            executorArgs
        );

        assertEq(s1, 0);

        uint256 endingBalance = address(nttManagerWithExecutor).balance;
        assertEq(endingBalance, startingBalance);
    }
}
