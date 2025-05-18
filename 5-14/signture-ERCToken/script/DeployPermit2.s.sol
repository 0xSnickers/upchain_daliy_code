// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {TokenBankWithERC20Token} from "../src/TokenBankWithERC20Token.sol";
import {OldToken} from "../src/OldToken.sol";
import {PermitToken} from "../src/PermitToken.sol";

contract DeployPermit2Script is Script {
    TokenBankWithERC20Token public tokenBankWithERC20Token;
    OldToken public oldToken;   
    PermitToken public permitToken;
    function setUp() public {}

    function run() public {
        // 从环境变量中读取私钥对应的地址
        // uint256 private_key = vm.envUint("PRIVATE_KEY_LOCAL");
        uint256 private_key = vm.envUint("PRIVATE_KEY_SEPOLIA");
        vm.startBroadcast(private_key);
        // // 不支持 Permit 的代币
        // oldToken = new OldToken("Old Snikers", "OSNK");
        // console.log("oldToken address => ", address(oldToken));  
        // // 支持 Permit 的代币   
        // permitToken = new PermitToken("Permit Snikers", "PSNK");
        // console.log("permitToken address => ", address(permitToken));  
        // 支持存取款任意ERC20代币的合约    
        tokenBankWithERC20Token = new TokenBankWithERC20Token(0x000000000022D473030F116dDEE9F6B43aC78BA3);
        console.log("tokenBankWithERC20Token address => ", address(tokenBankWithERC20Token));  
        vm.stopBroadcast();
    }
}
