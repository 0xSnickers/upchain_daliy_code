// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "forge-std/Script.sol";
import "../src/UUPS/NFTMarketV1.sol";
import "../src/UUPS/NFTMarketV2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";


// UUPS NFTMarketV2 升级脚本
contract UpgradeWithUUPSScript is Script {
    // 这些地址需要根据实际部署情况填写
    address constant PROXY_ADDRESS = address(0x123);          // 之前部署的代理合约地址
    address constant NEW_IMPLEMENTATION = address(0x456);     // 之前部署的 V2 实现合约地址

    function run() external {
        // 1. 获取部署者私钥
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_SEPOLIA");
        vm.startBroadcast(deployerPrivateKey);

        // 2. 将代理合约转换为 V1 接口以调用升级函数
        NFTMarketV1 proxy = NFTMarketV1(payable(PROXY_ADDRESS));

        // 3. 调用升级函数
        proxy.upgradeToAndCall(
            NEW_IMPLEMENTATION,    // V2 实现合约地址
            ""                    // 如果需要在升级时调用初始化函数，这里可以传入初始化数据
        );

        // 4. 验证升级是否成功
        // 将代理合约转换为 V2 接口
        NFTMarketV2 proxyV2 = NFTMarketV2(payable(PROXY_ADDRESS));
        
        // 输出一些验证信息
        console2.log("Upgrade completed");
        console2.log("Proxy address:", address(proxyV2));
        console2.log("New implementation:", NEW_IMPLEMENTATION);

        vm.stopBroadcast();
    }
}