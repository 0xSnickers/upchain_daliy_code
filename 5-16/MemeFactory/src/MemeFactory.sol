// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./MemeLogic.sol";

// MemeFactory部署后，核心函数：
// implementation	模板合约地址（MemeLogic 实例）
// projectOwner	平台方地址，收取 1% 铸造手续费
// tokenToOwner	每个 clone 合约对应的代币发行人
// isValidToken	校验地址是否为合法 clone
// deployInscription(...)	克隆模板合约并初始化（部署新的 Meme Token）
// mintInscription(...)	允许用户铸造指定 Meme Token，并自动完成收益分配
contract MemeFactory {
    using Clones for address;
    address public immutable implementation;
    address public immutable owner;
    uint256 public constant PROJECT_FEE_PERCENTAGE = 1; // 1% fee for project owner
    mapping(address => address) public tokenToOwner;
    mapping(address => bool) public isValidToken;
    // MemeDeployed：每次部署一个 Meme 会发出该事件，便于前端监听。
    event MemeDeployed(address indexed token, address indexed owner, string symbol, uint256 totalSupply, uint256 perMint, uint256 price);
    // MemeMinted：每次用户 mint 会触发该事件，记录地址/金额/数量。
    event MemeMinted(address indexed token, address indexed minter, uint256 amount, uint256 cost);
    error IncorrectPaymentAmount(uint256 _msgValue, uint256 _mintCost);
    modifier OnlyOwner(){
        require(msg.sender == owner, "MemeFactory: Not owner");
        _;
    }

    constructor() {
        // 部署后，MemeFactory 自动内部部署了一个 MemeLogic 逻辑合约实例，用作所有 meme clone 的逻辑源头
        implementation = address(new MemeLogic()); // 部署模板
        owner = msg.sender;
    }
    // @notice 发行代币
    // @param  symbol 代币符号
    // @param uint256 totalSupply 总供应量 如：1000000000
    // @param uint256 perMint 每次锻造的数量 如：10000
    // @param uint256 price 铸造价格 如：100000000000000 wei = 0.0001ETH
    // 每次 mintInscription Mint 成本 = 0.0001ETH * 10000 = 1ETH
    function deployInscription(
        string calldata symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    ) external returns (address) {
        require(totalSupply > 0, "Total supply must be > 0");
        require(perMint > 0 && perMint <= totalSupply, "Invalid perMint amount");
        require(price > 0, "Price must be > 0");
        // clone 一个新的 MemeLogic 合约
        address clone = implementation.clone();
        // 初始化它（通过 initialize()）
        // MemeLogic 因为拥有 receive 功能，则需要加上 payable 类型转换
        MemeLogic(payable(clone)).initialize(msg.sender, symbol, totalSupply, perMint, price);
        // 把发行人地址和合约地址映射记录
        tokenToOwner[clone] = msg.sender;
        isValidToken[clone] = true;

        emit MemeDeployed(clone, msg.sender, symbol, totalSupply, perMint, price);
        // 返回新的合约地址
        return clone;
    }
    // @notice 购买者铸造代币（任何用户都可以通过调用 mintInscription(tokenAddr) 来 mint 某个 Meme。）
    // @param address tokenAddr 代币地址
    function mintInscription(address tokenAddr) external payable {
        require(isValidToken[tokenAddr], "Invalid token address");
        
        MemeLogic token = MemeLogic(payable(tokenAddr));
    
        uint256 mintCost = token.price() * token.perMint(); 

        if(msg.value != mintCost){
            revert IncorrectPaymentAmount(msg.value, mintCost);
        }
        // require(msg.value == mintCost, "Incorrect payment amount");

        // 费用会自动分配：1%给项目方，99%给代币发行者
        uint256 projectFee = (mintCost * PROJECT_FEE_PERCENTAGE) / 100;
        uint256 ownerFee = mintCost - projectFee;

        // Send fees
        // 转给 Factory 项目合约
        payable(address(this)).transfer(projectFee);
        // 方式一：直接转给发行代币的EOA用户地址
        // payable(tokenToOwner[tokenAddr]).transfer(ownerFee);
        // 方式二：转给代币合约地址（后续用户自己提取）
        payable(tokenAddr).transfer(ownerFee);

        token.mint{value: 0}(msg.sender);

        emit MemeMinted(tokenAddr, msg.sender, token.perMint(), mintCost);
    }
    receive() external payable { }

    function withdraw(address _to) public OnlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0,"Insufficient balance");
        // 将余额转到项目方
        (bool success, ) = payable(_to).call{value: balance}("");
        require(success, "Withdraw failed");
    }
}
