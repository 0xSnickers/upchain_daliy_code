// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

interface ITokenReceiver {
    function tokensReceived(
        address sender,
        address token,
        uint256 amount,
        bytes calldata data
    ) external returns (bool);
} 