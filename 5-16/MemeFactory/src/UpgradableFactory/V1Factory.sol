// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./InscriptionToken.sol";

// 第一版工厂 （没使用clone，直接new）
// 直接通过 new 创建 InscriptionToken 合约实例
// 每次创建 Token 都是 full contract（昂贵）
// 无 mint 成本限制（没有 price）
contract V1Factory is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    // 用户部署的 Token 列表
    mapping(address => address[]) public userTokens;

    event TokenDeployed(address indexed token, address indexed owner);
    // 初始化
    function initialize() public initializer {
        // 初始化 Ownable 合约
        // 确保传了正确的 owner 地址进去。这样才能正确初始化可升级合约的所有权
        __Ownable_init(msg.sender);
    }
    // 授权升级
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    // 部署 Token
    function deployInscription(
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint
    ) external returns (address) {
        // 创建 Token
        InscriptionToken token = new InscriptionToken(symbol, totalSupply, perMint, msg.sender);
        // 记录用户部署的 Token 列表
        userTokens[msg.sender].push(address(token));
        emit TokenDeployed(address(token), msg.sender);
        return address(token);
    }
    // 铸币
    function mintInscription(address tokenAddr) external {
        InscriptionToken token = InscriptionToken(tokenAddr);
        token.mint(msg.sender);
    }
}