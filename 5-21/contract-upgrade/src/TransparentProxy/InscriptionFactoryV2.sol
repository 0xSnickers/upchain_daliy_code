// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
// import "./InscriptionToken.sol";
import "./InscriptionFactoryV1.sol";

// 第二版工厂 (MemeFactory 的升级版)
// 通过最小代理 clone 的方式创建 token 实例，加上价格控制功能
contract InscriptionFactoryV2 is InscriptionFactoryV1{
    using Clones for address;
    // 新增的状态变量 - 必须在所有 V1 状态变量之后
    address public implementation;
    mapping(address => uint256) public tokenPrice;
    event TokenDeployed(address indexed token, address indexed owner, uint256 price);
    constructor() {
        _disableInitializers();
    }

    // V2 特有的初始化函数
    function initializeV2(address _implementation) public reinitializer(2){
        require(implementation == address(0), "Already initialized V2");
        implementation = _implementation;
    }

    // 新的 V2 函数（带价格的部署）
    // 注意：这里的参数与 V1 不同, 不能使用 override 重写
    function deployInscriptionV2(
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    ) external returns (address) {
        require(implementation != address(0), "Implementation not set");
        address clone = implementation.clone();
        InscriptionToken(payable(clone)).initialize(
            msg.sender,
            symbol,
            totalSupply,
            perMint,
            price
        );
        userTokens[msg.sender].push(clone);
        tokenPrice[clone] = price;
        emit TokenDeployed(clone, msg.sender, price);
        return clone;
    }

    // V2 的付费铸币函数
    function mintInscription(address tokenAddr) external virtual override payable {
        uint256 price = tokenPrice[tokenAddr];
        require(msg.value == price, "Incorrect payment");
        InscriptionToken(payable(tokenAddr)).mint(msg.sender);
    }

    // 获取版本信息
    function version() public pure override returns (string memory) {
        return "v2.0";
    }
}