// SPDX-License-Identifier: Apache 2
pragma solidity ^0.8.19;

import "native-token-transfers/evm/src/interfaces/INttManager.sol";
import "./IWETH.sol";

interface INttManagerWethUnwrap is INttManager {
    function weth() external returns (IWETH);
}
