// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

// 透明代理初始化不能调用构造函数,使用 OwnableUpgradeable 初始化
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
// 必须继承 Initializable 来使用 initializer 修饰符，确保初始化函数只执行一次
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";

import  "./InscriptionToken.sol";

// 第一版工厂 （没使用clone，直接new）
// 直接通过 new 创建 InscriptionToken 合约实例
// 每次创建 Token 都是 full contract（昂贵）
// 无 mint 成本限制（没有 price）
contract InscriptionFactoryV1 is
    Initializable,
    OwnableUpgradeable
{
    // 用户部署的 Token 列表
    mapping(address => address[]) public userTokens;

    event TokenDeployed(address indexed token, address indexed owner);

    /// @custom:oz-upgrades-unsafe-allow constructor
    // 透明代理初始化不能调用构造函数
    constructor() {
        _disableInitializers(); // 在构造函数中禁用初始化
    }

    // 初始化函数，代替构造函数
    function initialize() public initializer {
        __Ownable_init(msg.sender); // OpenZeppelin 5.0 正确语法
    }

    // 部署 Token
    function deployInscription(
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint
    ) external virtual returns (address) {
        // 创建新的 InscriptionToken 合约实例
        InscriptionToken token = new InscriptionToken(msg.sender, symbol, totalSupply, perMint);
        address token_address = address(token);
        // 记录用户部署的 Token 列表
        userTokens[msg.sender].push(token_address);
        emit TokenDeployed(token_address, msg.sender);
        return token_address;
    }
      // 铸币
    function mintInscription(address tokenAddr) external virtual payable {
        InscriptionToken token = InscriptionToken(payable(tokenAddr));
        token.mint(msg.sender);
    }
     // 获取版本信息
     function version() public pure virtual returns (string memory) {
        return "v1.0";
    }
}