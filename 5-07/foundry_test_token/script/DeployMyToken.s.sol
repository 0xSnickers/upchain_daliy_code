// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { MyToken } from "../src/MyToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DeployMyTokenrScript is Script {
    MyToken public token_addr;

    function setUp() public {}

    function run() public {
       // 从环境变量中读取私钥对应的地址
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // 开始广播交易
        vm.startBroadcast(deployerPrivateKey);
        token_addr = new MyToken("Sniker", "SNK");
        vm.stopBroadcast();

    }
}
