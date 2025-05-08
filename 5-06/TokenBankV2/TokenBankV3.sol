// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// 支持存储 ETH + ERC20 Token
contract TokenBank is ReentrancyGuard {
    using Address for address;
    
    // 存储每个用户的 ETH 余额
    mapping(address => uint256) public ethBalances;
    
    // 存储每个用户对每种代币的余额
    // token => user => balance
    mapping(address => mapping(address => uint256)) public tokenBalances;
    
    // 存储总存款量
    uint256 public totalEthDeposits;
    mapping(address => uint256) public totalTokenDeposits;
    
    // 事件定义
    event EthDeposit(address indexed user, uint256 amount);
    event EthWithdraw(address indexed user, uint256 amount);
    event TokenDeposit(address indexed user, address indexed token, uint256 amount);
    event TokenWithdraw(address indexed user, address indexed token, uint256 amount);

    // 接收 ETH 的函数
    receive() external payable {
        depositEth();
    }

    /**
     * @dev 存入 ETH
     */
    function depositEth() public payable nonReentrant {
        require(msg.value > 0, "TokenBank: amount must be greater than 0");
        
        ethBalances[msg.sender] += msg.value;
        totalEthDeposits += msg.value;
        
        emit EthDeposit(msg.sender, msg.value);
    }

    /**
     * @dev 存入 ERC20 Token
     * @param token Token 合约地址
     * @param amount 存入数量
     */
    function depositToken(address token, uint256 amount) public nonReentrant {
        require(amount > 0, "TokenBank: amount must be greater than 0");
        require(token != address(0), "TokenBank: invalid token address");

        // 从用户地址转移代币到合约
        bool success = IERC20(token).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        require(success, "TokenBank: transfer failed");

        // 更新余额
        tokenBalances[token][msg.sender] += amount;
        totalTokenDeposits[token] += amount;

        emit TokenDeposit(msg.sender, token, amount);
    }

    /**
     * @dev 提取 ETH
     * @param amount 提取数量
     */
    function withdrawEth(uint256 amount) public nonReentrant {
        require(amount > 0, "TokenBank: amount must be greater than 0");
        require(ethBalances[msg.sender] >= amount, "TokenBank: insufficient balance");

        // 更新余额
        ethBalances[msg.sender] -= amount;
        totalEthDeposits -= amount;

        // 转移 ETH 回用户地址
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "TokenBank: transfer failed");

        emit EthWithdraw(msg.sender, amount);
    }

    /**
     * @dev 提取 ERC20 Token
     * @param token Token 合约地址
     * @param amount 提取数量
     */
    function withdrawToken(address token, uint256 amount) public nonReentrant {
        require(amount > 0, "TokenBank: amount must be greater than 0");
        require(token != address(0), "TokenBank: invalid token address");
        require(tokenBalances[token][msg.sender] >= amount, "TokenBank: insufficient balance");

        // 更新余额
        tokenBalances[token][msg.sender] -= amount;
        totalTokenDeposits[token] -= amount;

        // 转移代币回用户地址
        bool success = IERC20(token).transfer(msg.sender, amount);
        require(success, "TokenBank: transfer failed");

        emit TokenWithdraw(msg.sender, token, amount);
    }

    /**
     * @dev 查询用户的 ETH 余额
     * @param user 用户地址
     * @return ETH 余额
     */
    function ethBalanceOf(address user) public view returns (uint256) {
        return ethBalances[user];
    }

    /**
     * @dev 查询用户的 Token 余额
     * @param token Token 合约地址
     * @param user 用户地址
     * @return Token 余额
     */
    function tokenBalanceOf(address token, address user) public view returns (uint256) {
        return tokenBalances[token][user];
    }

    /**
     * @dev 查询总 ETH 存款量
     * @return 总 ETH 存款量
     */
    function totalEthDeposits() public view returns (uint256) {
        return totalEthDeposits;
    }

    /**
     * @dev 查询总 Token 存款量
     * @param token Token 合约地址
     * @return 总 Token 存款量
     */
    function totalTokenDeposits(address token) public view returns (uint256) {
        return totalTokenDeposits[token];
    }
}
