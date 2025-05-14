// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MyERC721Enumerable} from "../src/NFTMarket/MyERC721Enumerable.sol";
// import {BaseERC721} from "../src/NFTMarket/BaseERC721.sol";
import {NFTMarket} from "../src/NFTMarket/NFTMarket.sol";
contract DeployNFTMarketScript is Script {
    // BaseERC721 public base_erc721;
    MyERC721Enumerable public base_erc721;
    NFTMarket public nft_market;

    function setUp() public {}

    function run() public {
        // 从环境变量中读取私钥对应的地址
        //     address sepolia_SNK_address = vm.envAddress("SEPOLIA_SNK_ADDRESS");
        // sepolia 私钥
        // uint256 private_key_sepolia = vm.envUint("PRIVATE_KEY_SEPOLIA");

        // anvil 私钥
        uint256 private_key_local = vm.envUint("PRIVATE_KEY_LOCAL");
        
        // BASE URI 地址
        string memory erc721_base_uri = vm.envString("ERC721_BASE_URI");
        string memory _name = "Sniker";
        string memory _symbol = "SNK";

        // 多签钱包地址
        // address multiple_signture_address = 0xE2A0D284CD0FBe362b06f9F4FAB89bFF8123f8D1;

        // 开始广播交易
        vm.startBroadcast(private_key_local);

        base_erc721 = new MyERC721Enumerable(_name, _symbol, erc721_base_uri);

        console.log("BaseERC721 contract address =>", address(base_erc721));

        // 设置 NFTMarket(收取平台手续费地址)
        nft_market = new NFTMarket();
        console.log("NFTMarket contract address =>", address(nft_market));

        vm.stopBroadcast();
    }
}
