// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {PermitToken} from "../src/PermitToken.sol";
import {PermitTokenBank} from "../src/PermitTokenBank.sol";

contract SigntureScript is Script {
    PermitToken public myToken;
    PermitTokenBank public tokenBank;

    function setUp() public {}

    function run() public {
                // 从环境变量中读取私钥对应的地址
                
        uint256 private_key_sepolia = vm.envUint("PRIVATE_KEY_LOCAL");
        // uint256 private_key_sepolia = vm.envUint("PRIVATE_KEY_SEPOLIA");
        vm.startBroadcast(private_key_sepolia);

        myToken = new PermitToken("Snikers", "SNK");
        console.log("PermitToken address => ", address(myToken));  
        tokenBank = new PermitTokenBank(address(myToken));
        console.log("PermitTokenBank address => ", address(tokenBank));

        vm.stopBroadcast();
    }
}
