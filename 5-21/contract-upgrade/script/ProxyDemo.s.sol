// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import  "../src/ProxyDemo/V1.sol";
import  "../src/ProxyDemo/V2.sol";

contract ProxyDemoScript is Script {
    // ERC1967 标准存储槽 (IMPLEMENTATION_SLOT 和 ADMIN_SLOT 在 ERC1967Utils 定义为常量)
    bytes32 private constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 private constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_LOCAL");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署 V1 实现合约
        V1 v1Impl = new V1();
        console2.log("V1 Impl:", address(v1Impl));

        // 2. 编码初始化数据
        bytes memory initData = abi.encodeWithSelector(v1Impl.initialize.selector);

        // 3. 部署 Transparent Proxy 指向 V1
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(v1Impl),
            deployer,
            initData
        );
        console2.log("Proxy Address (Initial V1):", address(proxy));

        // 4. 部署 V2 实现合约
        V2 v2Impl = new V2();
        console2.log("V2 Impl:", address(v2Impl));

        // 5. 编码 V2 初始化数据
        bytes memory initDataV2 = abi.encodeWithSelector(
            v2Impl.initializeV2.selector,
            "I'm upgraded"
        );

        // 6. 获取代理合约创建的 ProxyAdmin 实例 
        // - 用 vm.load 从代理合约的存储槽中获取 ProxyAdmin 地址
        address proxyAdminAddress = address(uint160(uint256(vm.load(address(proxy), ADMIN_SLOT))));
        console2.log("ProxyAdmin Address:", proxyAdminAddress);

        // 验证 ProxyAdmin 地址
        require(proxyAdminAddress != address(0), "ProxyAdmin address is zero");
        
        // 验证当前实现地址
        // - 用 vm.load 从代理合约的存储槽中获取当前实现地址
        address currentImpl = address(uint160(uint256(vm.load(address(proxy), IMPLEMENTATION_SLOT))));
        console2.log("Current Implementation:", currentImpl);
        require(currentImpl == address(v1Impl), "Current implementation is not V1");

        // 7. 执行 upgradeAndCall 升级
        // - 调用 ProxyAdmin 的 upgradeAndCall（）函数来升级代理合约
        try ProxyAdmin(proxyAdminAddress).upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(proxy))),
            address(v2Impl),
            initDataV2
        ) {
            console.log("Upgrade successful!");
            
            // 验证升级后的实现地址
            address newImpl = address(uint160(uint256(vm.load(address(proxy), IMPLEMENTATION_SLOT))));
            console2.log("New Implementation:", newImpl);
            require(newImpl == address(v2Impl), "New implementation is not V2");
        } catch Error(string memory reason) {
            console.log("Upgrade failed with reason:", reason);
            vm.stopBroadcast();
            return;
        } catch {
            console.log("Upgrade failed with unknown error");
            vm.stopBroadcast();
            return;
        }
        console2.log("Upgraded to V2 at Proxy:", address(proxy));

        vm.stopBroadcast();
    }
}
