// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../src/TransparentProxy/InscriptionFactoryV1.sol";
import "../src/TransparentProxy/InscriptionFactoryV2.sol";

// 升级 InscriptionFactoryV1 到 InscriptionFactoryV2
contract UpgradeTransparentProxyScript is Script {
    // ERC1967 标准存储槽 (IMPLEMENTATION_SLOT 和 ADMIN_SLOT 在 ERC1967Utils 定义为常量)
    // PROXY_ADDRESS 代理合约的存储槽（用于获取 Admin 和 当前代理的实现合约）
    bytes32 private constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 private constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
  
    function run() external {
        // 从环境变量获取地址
        address TOKEN_TEMPLATE_ADDRESS = 0xD84379CEae14AA33C123Af12424A37803F885889; // Inscription Token 模板地址
        address INSCRIPTION_FACTORY_V1_IMPL_ADDRESS = 0x2B0d36FACD61B71CC05ab8F3D2355ec3631C0dd5; // V1 实现逻辑合约地址
        address payable PROXY_ADDRESS = payable(0xfbC22278A96299D91d41C453234d97b4F5Eb9B2d); // V1 代理地址
        
        // 获取私钥
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_LOCAL");

        // 开始广播交易
        vm.startBroadcast(deployerPrivateKey);

        // 部署 InscriptionFactoryV2 的实现合约
        console.log("=== Deploying V2 implementation ===");
        InscriptionFactoryV2 factoryV2Implementation = new InscriptionFactoryV2();
        address V2_IMPL_ADDRESS = address(factoryV2Implementation);
        console.log("InscriptionFactoryV2 Implementation deployed to:", V2_IMPL_ADDRESS);
        // 准备升级数据
        // - 用 abi.encodeWithSelector 编码初始化函数的调用数据
        bytes memory initDataV2 = abi.encodeWithSelector(
            factoryV2Implementation.initializeV2.selector,
            TOKEN_TEMPLATE_ADDRESS
        );

        // 6. 获取 new TransparentUpgradeableProxy() 时创建的 ProxyAdmin 合约地址
        // - 用 vm.load 从代理合约的存储槽中获取 ProxyAdmin 地址
        // ⚠️ 注意： ADMIN_SLOT 存储的是 ProxyAdmin 合约的地址，不是 owner 地址
        address proxyAdminAddress = address(uint160(uint256(vm.load(PROXY_ADDRESS, ADMIN_SLOT))));
        console2.log("ProxyAdmin Address:", proxyAdminAddress);
        // 验证 ProxyAdmin 地址
        require(proxyAdminAddress != address(0), "ProxyAdmin address is zero");
        
        // 验证当前实现地址
        // - 用 vm.load 从代理合约的存储槽中获取当前实现地址
        address currentImpl = address(uint160(uint256(vm.load(PROXY_ADDRESS, IMPLEMENTATION_SLOT))));
        console2.log("Current Implementation:", currentImpl);
        require(currentImpl == address(INSCRIPTION_FACTORY_V1_IMPL_ADDRESS), "Current implementation is not V1");

        // 升级到新的实现合约
        console.log("=== Upgrading proxy ===");
        try ProxyAdmin(proxyAdminAddress).upgradeAndCall(
            ITransparentUpgradeableProxy(PROXY_ADDRESS),
            V2_IMPL_ADDRESS, // V2 的实现合约地址
            initDataV2 // 空的calldata，不调用任何函数
        ) {
            console.log("Upgrade successful!");
        } catch Error(string memory reason) {
            console.log("Upgrade failed with reason:", reason);
            vm.stopBroadcast();
            return;
        } catch {
            console.log("Upgrade failed with unknown error");
            vm.stopBroadcast();
            return;
        }

        // 验证升级后的状态
        // console.log("=== Post-upgrade verification ===");
        
        // 检查版本
        // try InscriptionFactoryV2(PROXY_ADDRESS).version() returns (string memory version) {
        //     console.log("Contract version:", version);
        // } catch {
        //     console.log("Failed to get version - might still be V1");
        // }

        // 检查owner是否保持不变
        // try InscriptionFactoryV2(PROXY_ADDRESS).owner() returns (address newOwner) {
        //     console.log("Owner after upgrade:", newOwner);
        // } catch {
        //     console.log("Failed to get owner after upgrade");
        // }


        // 验证 V2 功能
        // try InscriptionFactoryV2(PROXY_ADDRESS).implementation() returns (address impl) {
        //     console.log("Token template address set to:", impl);
        // } catch {
        //     console.log("Failed to get implementation address");
        // }

        console.log("=== Summary ===");
        console.log("Proxy address:", PROXY_ADDRESS);
        console.log("New implementation address:", V2_IMPL_ADDRESS);
        console.log("Token template address:", TOKEN_TEMPLATE_ADDRESS);

        vm.stopBroadcast();
    }
}