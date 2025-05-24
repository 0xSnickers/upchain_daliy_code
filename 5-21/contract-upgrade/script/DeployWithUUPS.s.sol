// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "forge-std/Script.sol";
import "../src/UUPS/NFTMarketV1.sol";
import "../src/UUPS/NFTMarketV2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
//  部署 NFTMarketV1+ UUPS代理合约
contract DeployWithUUPSScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_SEPOLIA");
        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署 NFTMarketV1 实现合约
        NFTMarketV1 marketV1Implementation = new NFTMarketV1();
        
        // 2. 准备 NFTMarketV1 的初始化数据
        bytes memory marketInitData = abi.encodeWithSelector(
            NFTMarketV1.initialize.selector
        );
        
        // 3. 部署 NFTMarketV1 代理合约
        ERC1967Proxy marketProxy = new ERC1967Proxy(
            address(marketV1Implementation),
            marketInitData
        );

        // 4. 部署 NFTMarketV2 实现合约（为后续升级准备）
        NFTMarketV2 marketV2Implementation = new NFTMarketV2();

        vm.stopBroadcast();

        // 输出部署地址
        console2.log("NFTMarketV1 Implementation:", address(marketV1Implementation));
        console2.log("NFTMarket Proxy:", address(marketProxy));
        console2.log("NFTMarketV2 Implementation:", address(marketV2Implementation));
    }
}