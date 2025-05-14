// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MyToken} from "../src/TokenBank/MyToken.sol";
import {TokenBank} from "../src/TokenBank/TokenBank.sol";
contract DeployTokenBankScript is Script {
    MyToken public myToken;
    TokenBank public tokenBank;
    function setUp() public {}

    function run() public {
        // 从环境变量中读取私钥对应的地址
        // uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_LOCAL");
        // 开始广播交易
        // vm.startBroadcast(deployerPrivateKey);
        vm.startBroadcast();
        // 初始化部署两个合约
        myToken = new MyToken("Snikers","SNK");
        console.log("MyToken contract address =>", address(myToken));
        tokenBank = new TokenBank();
        console.log("tokenBank contract address =>", address(tokenBank));
        vm.stopBroadcast();
    }
}
