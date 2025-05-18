// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {ERC721WithSignature} from "../src/ERC721WithSignature.sol";

contract ERC721WithSignatureScript is Script {
    ERC721WithSignature public erc721_with_signature;

    function setUp() public {}

    function run() public {
        // 从环境变量中读取私钥对应的地址
        // uint256 private_key = vm.envUint("PRIVATE_KEY_LOCAL");
        uint256 private_key = vm.envUint("PRIVATE_KEY_SEPOLIA");
        string memory erc721_base_uri = vm.envString("ERC721_BASE_URI");
        vm.startBroadcast(private_key);
        erc721_with_signature = new ERC721WithSignature("Snikers", "SNK", erc721_base_uri);
        console.log("ERC721WithSignature address => ", address(erc721_with_signature));  
        vm.stopBroadcast();
    }
}
