// SPDX-License-Identifier: Apache 2
pragma solidity ^0.8.19;

import {FeeArgs} from "../v2/interfaces/INttManagerWithExecutor.sol";

struct ExecutorWithTokenArgs {
    // The msg value to be passed into the Executor (e.g. for Wormhole fees).
    uint256 value;
    // The amount of the executor payment token.
    uint256 amount;
    // The executor payment token address.
    address srcToken;
    // The refund address used by the Executor.
    address refundAddress;
    // The signed quote to be passed into the Executor (EQ03).
    bytes signedQuote;
    // The relay instructions to be passed into the Executor.
    bytes instructions;
}

interface INttManagerWithExecutorWithToken {
    /// @notice Error when the refund to the sender fails.
    /// @dev Selector 0x2ca23714.
    /// @param refundAmount The refund amount.
    error RefundFailed(uint256 refundAmount);

    /// @notice Error when the payment to the payee fails.
    /// @dev Selector 0x1e67017f.
    /// @param feeAmount The fee amount.
    error PaymentFailed(uint256 feeAmount);

    /// @notice Transfer a given amount to a recipient on a given chain using the ExecutorWithToken for relaying.
    /// @param nttManager The NTT manager used for the transfer.
    /// @param amount The amount to transfer.
    /// @param recipientChain The Wormhole chain ID for the destination.
    /// @param recipientAddress The recipient address.
    /// @param refundAddress The address to which a refund for unussed gas is issued on the recipient chain.
    /// @param encodedInstructions Additional instructions to be forwarded to the recipient chain.
    /// @param executorArgs The arguments to be passed into the ExecutorWithToken.
    /// @param feeArgs The arguments used to compute and pay the referrer fee.
    /// @return msgId The resulting message ID of the transfer
    function transfer(
        address nttManager,
        uint256 amount,
        uint16 recipientChain,
        bytes32 recipientAddress,
        bytes32 refundAddress,
        bytes memory encodedInstructions,
        ExecutorWithTokenArgs calldata executorArgs,
        FeeArgs calldata feeArgs
    ) external payable returns (uint64 msgId);

    /// @notice Transfer a given amount to a recipient on a given chain using the ExecutorWithToken for relaying.
    /// @param nttManager The NTT manager used for the transfer.
    /// @param amount The amount to transfer.
    /// @param recipientChain The Wormhole chain ID for the destination.
    /// @param recipientAddress The recipient address.
    /// @param refundAddress The address to which a refund for unussed gas is issued on the recipient chain.
    /// @param encodedInstructions Additional instructions to be forwarded to the recipient chain.
    /// @param executorArgs The arguments to be passed into the ExecutorWithToken.
    /// @param feeArgs The arguments used to compute and pay the referrer fee.
    /// @return msgId The resulting message ID of the transfer
    function transferETH(
        address nttManager,
        uint256 amount,
        uint16 recipientChain,
        bytes32 recipientAddress,
        bytes32 refundAddress,
        bytes memory encodedInstructions,
        ExecutorWithTokenArgs calldata executorArgs,
        FeeArgs calldata feeArgs
    ) external payable returns (uint64 msgId);
}
