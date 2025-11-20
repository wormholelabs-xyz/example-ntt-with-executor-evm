// SPDX-License-Identifier: Apache 2
pragma solidity ^0.8.17;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface IWETH is IERC20 {
    function deposit() external payable;

    function transfer(address to, uint256 value) external returns (bool);

    function withdraw(uint256) external;
}
