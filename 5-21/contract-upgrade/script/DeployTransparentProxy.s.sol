// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol"; // 导入 ProxyAdmin

import "../src/TransparentProxy/InscriptionToken.sol";
import "../src/TransparentProxy/InscriptionFactoryV1.sol";
import "../src/TransparentProxy/InscriptionFactoryV2.sol";
// 部署 InscriptionFactoryV1 + 透明代理合约脚本
contract DeployTransparentProxyScript is Script {
  
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_LOCAL");
        // uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_SEPOLIA");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署 InscriptionToken 实现 (for V2 factory, but needed for V1 test/logic)
        // 虽然 V1 工厂不直接使用模板，但为了测试和未来的 V2 升级，我们在这里部署它
        InscriptionToken inscriptionTokenImplementation = new InscriptionToken(deployer, "ALCH", 100000000, 1000);
        console.log("InscriptionToken Implementation deployed to:", address(inscriptionTokenImplementation));

        // 2. 部署 InscriptionFactoryV1 实现
        InscriptionFactoryV1 factoryV1Implementation = new InscriptionFactoryV1();
        console.log("InscriptionFactoryV1 Implementation deployed to:", address(factoryV1Implementation));
         
        // 编码V1初始化通话数据
        // V1 工厂的 initialize 函数没有参数
        bytes memory factoryV1InitializeData = abi.encodeWithSelector(
            factoryV1Implementation.initialize.selector
        );

        // 3. 为 V1 部署 TransparentUpgradeableProxy
        // 代理的 admin 设置为上面部署的 proxyAdmin
        TransparentUpgradeableProxy factoryV1Proxy = new TransparentUpgradeableProxy(
            address(factoryV1Implementation),
            deployer, // Admin address is ProxyAdmin
            factoryV1InitializeData
        );
        console.log("InscriptionFactoryV1 Proxy deployed to:", address(factoryV1Proxy));

        console.log("--- Deployment Complete ---");
        // proxy=>代理合约地址
        console.log("PROXY_INSCRIPTION_FACTORY_ADDRESS (V1):", address(factoryV1Proxy));
        // V1版本实现合约地址
        console.log("INSCRIPTION_FACTORY_V1_IMPL_ADDRESS:", address(factoryV1Implementation));
        // Token 模板地址
        console.log("INSCRIPTION_TOKEN_TEMPLATE_ADDRESS:", address(inscriptionTokenImplementation)); // Token impl address

        vm.stopBroadcast();
    }
}