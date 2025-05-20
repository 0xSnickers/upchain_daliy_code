// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {PermitTokenBank} from "../src/PermitTokenBank.sol";

contract DeployPermit2Script is Script {
    PermitTokenBank public permitTokenBank;
    function setUp() public {}

    function run() public {
        // 从环境变量中读取私钥对应的地址
        uint256 private_key = vm.envUint("PRIVATE_KEY_SEPOLIA");
        vm.startBroadcast(private_key);
        // 支持存取款任意ERC20代币的合约    
        permitTokenBank = new PermitTokenBank(0x03e86E790524019B23E7B4c6fdE3565eD46Ca55d);
        console.log("permitTokenBank address => ", address(permitTokenBank));  
        vm.stopBroadcast();
    }
}
