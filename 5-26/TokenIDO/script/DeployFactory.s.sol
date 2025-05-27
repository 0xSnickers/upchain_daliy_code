// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "@uniswap/v2-core/contracts/UniswapV2Factory.sol";

contract DeployFactory is Script {
    function run() external {
        vm.startBroadcast();
        new UniswapV2Factory(msg.sender);
        vm.stopBroadcast();
    }
}
