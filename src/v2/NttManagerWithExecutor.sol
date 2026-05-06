// SPDX-License-Identifier: Apache 2
pragma solidity ^0.8.19;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import "example-messaging-executor/evm/src/interfaces/IExecutor.sol";
import "example-messaging-executor/evm/src/libraries/ExecutorMessages.sol";
import "native-token-transfers/evm/src/interfaces/INttManager.sol";

import "./interfaces/INttManagerWithExecutor.sol";
import "../interfaces/INttManagerWethUnwrap.sol";

string constant nttManagerWithExecutorVersion = "NttManagerWithExecutor-0.0.2";

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
        bytes memory encodedInstructions,
        ExecutorArgs calldata executorArgs,
        FeeArgs calldata feeArgs
    ) external payable returns (uint64 msgId) {
        INttManager nttm = INttManager(nttManager);

        // Custody the tokens in this contract and approve NTT to spend them.
        // Not worrying about dust here since the `NttManager` will revert in that case.
        address token = nttm.token();
        amount = custodyTokens(token, amount);

        // Transfer the fees to the referrer.
        payFee(token, feeArgs);

        // Approve the bridge to spend the tokens.
        _maxApproveIfNeeded(token, nttManager, amount);

        // Initiate the transfer.
        msgId = nttm.transfer{value: msg.value - executorArgs.value - feeArgs.nativeTokenFee}(
            amount, recipientChain, recipientAddress, refundAddress, false, encodedInstructions
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

        // Refund any excess value.
        uint256 currentBalance = address(this).balance;
        if (currentBalance > 0) {
            (bool refundSuccessful,) = payable(executorArgs.refundAddress).call{value: currentBalance}("");
            if (!refundSuccessful) {
                revert RefundFailed(currentBalance);
            }
        }
    }

    /// @inheritdoc INttManagerWithExecutor
    function transferETH(
        address nttManager,
        uint256 amount,
        uint16 recipientChain,
        bytes32 recipientAddress,
        bytes32 refundAddress,
        bytes memory encodedInstructions,
        ExecutorArgs calldata executorArgs,
        FeeArgs calldata feeArgs
    ) external payable returns (uint64 msgId) {
        INttManagerWethUnwrap nttm = INttManagerWethUnwrap(nttManager);
        IWETH weth = nttm.weth();
        address token = address(weth);
        require(token != address(0), "WETH does not exist");

        // This requires the amount + wormhole fee + executionAmount + nativeTokenFee to be covered by msg.value.
        require(msg.value >= amount + executorArgs.value + feeArgs.nativeTokenFee, "Not enough msg value");
        uint256 remainingValue = msg.value - (amount + executorArgs.value + feeArgs.nativeTokenFee);

        // Deposit the amount to be transferred into WETH.
        weth.deposit{value: amount}();

        // Transfer the fees to the referrer.
        payFee(token, feeArgs);

        // Approve the bridge to spend the tokens.
        _maxApproveIfNeeded(token, nttManager, amount);

        // Initiate the transfer.
        msgId = nttm.transfer{value: remainingValue}(
            amount, recipientChain, recipientAddress, refundAddress, false, encodedInstructions
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

        // Refund any excess value.
        uint256 currentBalance = address(this).balance;
        if (currentBalance > 0) {
            (bool refundSuccessful,) = payable(executorArgs.refundAddress).call{value: currentBalance}("");
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

    // @dev The fee is taken in addition to the amount being transferred.
    function payFee(address token, FeeArgs calldata feeArgs) internal {
        if (feeArgs.transferTokenFee > 0) {
            // custody separately in case the amount after transfer doesn't match
            uint256 fee = custodyTokens(token, feeArgs.transferTokenFee);
            SafeERC20.safeTransfer(IERC20(token), feeArgs.payee, fee);
        }
        if (feeArgs.nativeTokenFee > 0) {
            (bool paymentSuccessful,) = payable(feeArgs.payee).call{value: feeArgs.nativeTokenFee}("");
            if (!paymentSuccessful) {
                revert PaymentFailed(feeArgs.nativeTokenFee);
            }
        }
    }

    /// @dev This is based on what is in the MayanForwarder contract here: https://github.com/mayan-finance/swap-bridge/blob/main/src/MayanForwarder.sol
    function _maxApproveIfNeeded(address tokenAddr, address spender, uint256 amount) internal {
        IERC20 token = IERC20(tokenAddr);
        uint256 currentAllowance = token.allowance(address(this), spender);
        if (currentAllowance < amount) {
            SafeERC20.safeApprove(token, spender, 0);
            SafeERC20.safeApprove(token, spender, type(uint256).max);
        }
    }
}
