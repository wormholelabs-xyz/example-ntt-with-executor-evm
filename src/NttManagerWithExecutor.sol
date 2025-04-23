// SPDX-License-Identifier: Apache 2
pragma solidity ^0.8.19;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import "example-messaging-executor/evm/src/interfaces/IExecutor.sol";
import "example-messaging-executor/evm/src/libraries/ExecutorMessages.sol";
import "native-token-transfers/evm/src/interfaces/INttManager.sol";

import "./interfaces/INttManagerWithExecutor.sol";

string constant nttManagerWithExecutorVersion = "NttManagerWithExecutor-0.0.1";

/// @title NttManagerWithExecutor
/// @author Wormhole Project Contributors.
/// @notice The NttManagerWithExecutor contract is a shim contract that initiates
///         an NTT transfer using the executor for relaying.
contract NttManagerWithExecutor is INttManagerWithExecutor {
    uint16 public immutable chainId;
    IExecutor public immutable executor;

    string public constant VERSION = nttManagerWithExecutorVersion;

    constructor(uint16 _chainId, address _executor) {
        assert(_chainId != 0);
        assert(_executor != address(0));
        chainId = _chainId;
        executor = IExecutor(_executor);
    }

    // ==================== External Interface ===============================================

    /// @inheritdoc INttManagerWithExecutor
    function transfer(
        address nttManager,
        uint256 amount,
        uint16 recipientChain,
        bytes32 recipientAddress,
        bytes32 refundAddress,
        bool shouldQueue,
        bytes memory encodedInstructions,
        ExecutorArgs calldata executorArgs,
        FeeArgs calldata feeArgs
    ) external payable returns (uint64 msgId) {
        INttManager nttm = INttManager(nttManager);

        // Custody the tokens in this contract and approve NTT to spend them.
        // Not worrying about dust here since the `NttManager` will revert in that case.
        address token = nttm.token();
        amount = custodyTokens(token, amount);

        // Transfer the fee to the referrer.
        amount = payFee(token, amount, feeArgs);

        // Initiate the transfer.
        SafeERC20.safeApprove(IERC20(token), nttManager, amount);
        msgId = nttm.transfer{value: msg.value - executorArgs.value}(
            amount, recipientChain, recipientAddress, refundAddress, shouldQueue, encodedInstructions
        );

        // Generate the executor event.
        executor.requestExecution{value: executorArgs.value}(
            recipientChain,
            nttm.getPeer(recipientChain).peerAddress,
            executorArgs.refundAddress,
            executorArgs.signedQuote,
            ExecutorMessages.makeNTTv1Request(
                chainId, bytes32(uint256(uint160(address(nttm)))), bytes32(uint256(msgId))
            ),
            executorArgs.instructions
        );

        // Refund any excess value back to the caller.
        // TODO: Not sure this is right.
        uint256 currentBalance = address(this).balance;
        if (currentBalance > 0) {
            (bool refundSuccessful,) = payable(msg.sender).call{value: currentBalance}("");
            if (!refundSuccessful) {
                revert RefundFailed(currentBalance);
            }
        }
    }

    // necessary for receiving native assets
    receive() external payable {}

    // ==================== Internal Functions ==============================================

    function custodyTokens(address token, uint256 amount) internal returns (uint256) {
        // query own token balance before transfer
        uint256 balanceBefore = getBalance(token);

        // deposit tokens
        SafeERC20.safeTransferFrom(IERC20(token), msg.sender, address(this), amount);

        // return the balance difference
        return getBalance(token) - balanceBefore;
    }

    function getBalance(address token) internal view returns (uint256 balance) {
        // fetch the specified token balance for this contract
        (, bytes memory queriedBalance) =
            token.staticcall(abi.encodeWithSelector(IERC20.balanceOf.selector, address(this)));
        balance = abi.decode(queriedBalance, (uint256));
    }

    // @dev The fee is calculated as a percentage of the amount being transferred.
    function payFee(address token, uint256 amount, FeeArgs calldata feeArgs) internal returns (uint256) {
        uint256 fee = calculateFee(amount, feeArgs.dbps);
        if (fee > 0) {
            // Don't need to check for fee greater than or equal to amount because it can never be (since dbps is a uint16).
            amount -= fee;
            SafeERC20.safeTransfer(IERC20(token), feeArgs.payee, fee);
        }
        return amount;
    }

    function calculateFee(uint256 amount, uint16 dbps) public pure returns (uint256 fee) {
        unchecked {
            uint256 q = amount / 100000;
            uint256 r = amount % 100000;
            fee = q * dbps + (r * dbps) / 100000;
        }
    }
}
