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
