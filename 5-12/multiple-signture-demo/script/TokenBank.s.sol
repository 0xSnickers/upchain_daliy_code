// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {TokenBank} from "../src/TokenBank.sol";

contract TokenBankScript is Script {
    TokenBank public tokenBank;

    function setUp() public {}

    function run() public {
        // 从环境变量中读取私钥对应的地址
        address sepolia_SNK_address = vm.envAddress("SEPOLIA_SNK_ADDRESS");
        uint256 private_key_sepolia = vm.envUint("PRIVATE_KEY_SEPOLIA");
        // tokenBank owner 改成 => https://app.safe.global 多签钱包地址
        address multiple_signture_address = 0xE2A0D284CD0FBe362b06f9F4FAB89bFF8123f8D1;
        console.log("sepolia_SNK_address =>", sepolia_SNK_address);
        console.log("private_key_sepolia =>", private_key_sepolia);

        // 开始广播交易
        vm.startBroadcast(private_key_sepolia);
        tokenBank = new TokenBank(sepolia_SNK_address, multiple_signture_address);
        console.log("tokenBank address=>", address(tokenBank));
        vm.stopBroadcast();
    }
}
