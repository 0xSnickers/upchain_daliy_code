// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./InscriptionToken.sol";

// 第二版工厂 (MemeFactory 的升级版)
// 通过最小代理 clone 的方式创建 token 实例，加上价格控制功能
contract V2Factory is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    using Clones for address;
    // 模板合约地址
    address public implementation;
    // 用户部署的 Token 列表
    mapping(address => address[]) public userTokens;
    // 用户部署的 Token 价格
    mapping(address => uint256) public tokenPrice;

    event TokenDeployed(address indexed token, address indexed owner, uint256 price);
    // 初始化
    function initialize(address _implementation) public initializer {
        // 初始化 Ownable 合约
        // 确保传了正确的 owner 地址进去。这样才能正确初始化可升级合约的所有权
        __Ownable_init(msg.sender);
        // 设置模板合约地址
        implementation = _implementation;
    }
    // 只有 owner 可以授权升级
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {
        // 空函数，用于授权升级
    }
    // 部署 Token
    function deployInscription(
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    ) external returns (address) {
        // 克隆模板合约
        address clone = implementation.clone();
        // 初始化 Token（构造函数不能在 clone 中使用，所以需要单独初始化）
        InscriptionToken(clone).initialize(symbol, totalSupply, perMint, msg.sender);
        // 记录用户部署的 Token 列表
        userTokens[msg.sender].push(clone);
        // 记录 Token 价格
        tokenPrice[clone] = price;
        emit TokenDeployed(clone, msg.sender, price);
        return clone;
    }
    // 铸币
    function mintInscription(address tokenAddr) external payable {
        uint256 price = tokenPrice[tokenAddr];
        require(msg.value == price, "Incorrect payment");
        InscriptionToken(tokenAddr).mint(msg.sender);
        // 可加收益分配逻辑
    }
}