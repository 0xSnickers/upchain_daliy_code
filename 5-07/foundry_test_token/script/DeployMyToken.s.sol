// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import { MyToken } from "../src/MyToken.sol";

contract DeployMyTokenrScript is Script {
    MyToken public token;

    function setUp() public {}

    function run() public {
       // 从环境变量中读取私钥对应的地址
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // 开始广播交易
        vm.startBroadcast(deployerPrivateKey);
        MyToken token = new MyToken("Snikers2", "SNK2");
        vm.stopBroadcast();

        console.log("MyToken deployed at:", address(token));
    }
}
