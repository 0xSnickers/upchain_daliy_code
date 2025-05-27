// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "forge-std/Script.sol";
import "../src/UUPS/NFTMarketV1.sol";
import "../src/UUPS/NFTMarketV2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// UUPS NFTMarketV2 升级脚本
contract UpgradeWithUUPSScript is Script {
    // sepolia UUPS 代理合约地址
    address constant PROXY_ADDRESS = 0xe56AA3135E82D66a3D1525C1418C0f8d05012deA; 

    function run() external {
        // 1. 获取部署者私钥
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_SEPOLIA");
        vm.startBroadcast(deployerPrivateKey);
        //  部署 NFTMarketV2 实现合约（为后续升级准备）
        NFTMarketV2 marketV2Implementation = new NFTMarketV2();
        // 2. 将代理合约转换为 V1 接口以调用升级函数
        NFTMarketV1 proxy = NFTMarketV1(payable(PROXY_ADDRESS));

        // 3. 调用升级函数
        proxy.upgradeToAndCall(
            address(marketV2Implementation), // V2 实现合约地址
            "" // 如果需要在升级时调用初始化函数，这里可以传入初始化数据
        );

        // 4. 验证升级是否成功
        // 将代理合约转换为 V2 接口
        NFTMarketV2 proxyV2 = NFTMarketV2(payable(PROXY_ADDRESS));

        // 输出一些验证信息
        console2.log("Upgrade completed");
        console2.log("Proxy address:", address(proxyV2));
        console2.log(
            "NFTMarketV2 Implementation:",
            address(marketV2Implementation)
        );
        vm.stopBroadcast();
    }
}
