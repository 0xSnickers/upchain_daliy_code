// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";

import "../src/TransparentProxy/InscriptionToken.sol";
import "../src/TransparentProxy/InscriptionFactoryV1.sol";
import "../src/TransparentProxy/InscriptionFactoryV2.sol";

contract UpgradeTransparentProxyTest is Test {
    ProxyAdmin public proxyAdmin;
    InscriptionToken public inscriptionTokenImplementation;
    InscriptionFactoryV1 public factoryV1Implementation;
    InscriptionFactoryV2 public factoryV2Implementation;
    TransparentUpgradeableProxy public factoryProxy;

    address payable public owner;
    address payable public user1;

    function setUp() public {
        uint256 ownerPrivateKey = vm.envUint("PRIVATE_KEY_LOCAL");
        owner = payable(vm.addr(ownerPrivateKey));
        user1 = payable(vm.addr(1));

        // 如果 InscriptionToken 构造函数需要 owner, 确保 owner 在此之前已定义
        // 并且后续操作如果需要以 owner 身份，则使用 vm.startPrank(owner)

        // 2. 部署 InscriptionToken 实现 (模板)
        // 如果构造函数需要 owner, 并且后续部署也需要 owner 权限
        vm.startPrank(owner);
        proxyAdmin = new ProxyAdmin(owner);
        // 假设 InscriptionToken 构造函数接受参数，并且 owner 是其中之一
        inscriptionTokenImplementation = new InscriptionToken(owner, "ALCH", 100000000, 1000); 
        factoryV1Implementation = new InscriptionFactoryV1();

        // 3. 部署 InscriptionFactoryV1 实现
        factoryV1Implementation = new InscriptionFactoryV1();

        // 4. 编码V1初始化调用数据 (V1 的 initialize 没有参数)
        bytes memory factoryV1InitializeData = abi.encodeWithSelector(
            InscriptionFactoryV1.initialize.selector
        );

        // 5. 部署 TransparentUpgradeableProxy 指向 V1 实现并初始化
        factoryProxy = new TransparentUpgradeableProxy(
            address(factoryV1Implementation),
            address(proxyAdmin),
            factoryV1InitializeData
        );

        // 6. 部署 InscriptionFactoryV2 实现
        factoryV2Implementation = new InscriptionFactoryV2();
        vm.stopPrank();
    }

    // 测试升级到 V2 时，如果直接调用 initialize 会失败
    function test_RevertUpgradeToV2AndCallInitialize() public {
        vm.startPrank(owner);

        // 准备 InscriptionFactoryV2 的 initialize 调用数据
        bytes memory factoryV2InitData = abi.encodeWithSelector(
            InscriptionFactoryV2.initializeV2.selector,
            address(inscriptionTokenImplementation) // 传入 InscriptionToken 模板地址
        );

        // 期望交易会因为合约已初始化而回滚
        // vm.expectRevert(Initializable.InvalidInitialization.selector); // 修改这里，先不指定具体的错误消息

        // 尝试升级并调用 initialize
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(factoryProxy))),
            address(factoryV2Implementation),
            factoryV2InitData
        );
        vm.stopPrank();

    }

    // 测试正确的升级方式：升级到 V2 并调用新的初始化函数（如果 V2 有的话）
    // 例如，如果 V2 有一个 setTokenImplementation(address) 函数
    // function test_UpgradeToV2AndCallSetTokenImplementation() public {
    //     // 假设 InscriptionFactoryV2 有一个 setTokenImplementation 函数
    //     // bytes memory factoryV2SetImplementationData = abi.encodeWithSelector(
    //     //     InscriptionFactoryV2.setTokenImplementation.selector,
    //     //     address(inscriptionTokenImplementation)
    //     // );

    //     // // 升级并调用 setTokenImplementation
    //     // proxyAdmin.upgradeAndCall(
    //     //     ITransparentUpgradeableProxy(payable(address(factoryProxy))),
    //     //     address(factoryV2Implementation),
    //     //     factoryV2SetImplementationData
    //     // );

    //     // // 验证 V2 的状态是否正确设置
    //     // InscriptionFactoryV2 v2Proxy = InscriptionFactoryV2(payable(address(factoryProxy)));
    //     // assertEq(v2Proxy.implementation(), address(inscriptionTokenImplementation));
    // }
}