// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// 编写一个 Vesting 合约（可参考 OpenZepplin Vesting 相关合约）， 相关的参数有：
// - beneficiary： 受益人
// - token：锁定的 ERC20 地址
// - cliff 悬崖锁仓期：12 个月
// - duration 线性释放：接下来的 24 个月，从 第 13 个月起开始每月解锁 1/24 的 ERC20
// - totalAmount：总锁定数量：100 万
// Vesting 合约包含的方法 release() 用来释放当前解锁的 ERC20 给受益人，
// Vesting 合约部署后，开始计算 Cliff ，并转入 100 万 ERC20 资产。
contract Vesting {
    address public immutable beneficiary; // 受益人地址     
    IERC20 public immutable token; // 代币
    uint256 public immutable cliff; // 悬崖锁仓期 （12 个月（以秒为单位））
    uint256 public immutable start; // 开始时间 （当前合约部署时间）
    uint256 public immutable duration; // 线性锁仓期 （24 个月（以秒为单位））
    uint256 public immutable totalAmount; // 锁仓总数量（总锁定数量=100 万）
    uint256 public released; // 已释放金额（释放当前可领取的 ERC20 给受益人）
    constructor(address _beneficiary, address _token, uint256 _cliff, uint256 _duration, uint256 _totalAmount) {
        require(_beneficiary != address(0), "Invalid beneficiary");
        require(_token != address(0), "Invalid token");
        require(_duration > 0, "Duration must be > 0");
        require(_totalAmount > 0, "Amount must be > 0");
        beneficiary = _beneficiary;
        token = IERC20(_token);
        cliff = _cliff;
        duration = _duration;
        start = block.timestamp;
        totalAmount = _totalAmount;
    }
    // 计算当前可领取的 ERC20 数量
    function vestedAmount() public view returns (uint256) {
        // 如果当前时间小于开始时间+悬崖锁仓期，则返回0
        if (block.timestamp < start + cliff) {
            return 0;
        } else if (block.timestamp >= start + cliff + duration) { 
            // 如果当前时间大于等于开始时间+悬崖锁仓期+线性锁仓期，则返回总数量
            return totalAmount;
        } else {
            // 计算已经过去的时间（从 cliff 结束后开始计算）
            uint256 timePassed = block.timestamp - (start + cliff);
            // 计算当前应该释放的月份（每月30天）
            uint256 monthsPassed = timePassed / 30 days;
            // 确保不超过24个月
            if (monthsPassed > 24) {
                monthsPassed = 24;
            }
            // 计算当前可领取的 ERC20 数量（每月 1/24）
            return (totalAmount * monthsPassed) / 24;
        }
    }
    // 计算当前可领取的 ERC20 数量
    function releasable() public view returns (uint256) {
        return vestedAmount() - released;
    }
    // 释放当前可领取的 ERC20 给受益人
    function release() external {
        uint256 amount = releasable();
        require(amount > 0, "No tokens to release");
        released += amount;
        require(token.transfer(beneficiary, amount), "Transfer failed");
    }
}

