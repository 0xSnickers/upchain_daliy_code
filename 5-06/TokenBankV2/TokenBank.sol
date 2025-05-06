// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract TokenBank is ReentrancyGuard {
    using Address for address;
    address public immutable token_address;
    // 存储每个用户对每种代币的余额
    mapping(address => uint256) public _balances;

    // 存储总存款量
    uint256 public _totalDeposits;
    // 事件定义
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    constructor(address token_address_) {
        token_address = token_address_;
    }
    function deposit(uint256 amount) public nonReentrant {
        require(amount > 0, "TokenBank: amount must be greater than 0");

        // 从用户地址转移代币到合约
        bool success = IERC20(token_address).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        require(success, "TokenBank: transfer failed");

        // 更新余额
        _balances[msg.sender] += amount;
        _totalDeposits += amount;

        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) public nonReentrant {
        require(amount > 0, "TokenBank: amount must be greater than 0");
        require(
            _balances[msg.sender] >= amount,
            "TokenBankV2: insufficient balance"
        );

        // 更新余额
        _balances[msg.sender] -= amount;
        _totalDeposits -= amount;

        // 转移代币回用户地址
        bool success = IERC20(token_address).transfer(msg.sender, amount);
        require(success, "TokenBank: transfer failed");

        emit Withdraw(msg.sender, amount);
    }

    function balanceOf(address user) public view returns (uint256) {
        return _balances[user];
    }

    /**
     * @dev 查询总存款量
     * @return 总存款量
     */
    function totalDeposits() public view returns (uint256) {
        return _totalDeposits;
    }
}
