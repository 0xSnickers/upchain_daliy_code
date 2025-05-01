// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
// • 继承 Bank 后会继承父合约的所有状态变量和函数
//   包括 owner、balances 等，前提是它们不是 private 修饰的
import "./Bank.sol";

contract BigBank is Bank{
      // 限额限制 modifier
    modifier AboveMinimumDeposit() {
        require(msg.value > 0.001 ether, "Deposit must be > 0.001 ETH");
        _;
    }
   // 重写 receive，加上限额限制
    receive() external payable override AboveMinimumDeposit {
        // 保留 Bank 中的存款逻辑
        payable(address(this)).transfer(msg.value);
        if (!deposite_user_exist[msg.sender]) {
            deposite_user_exist[msg.sender] = true;
            deposite_user.push(msg.sender);
        }
        balances[msg.sender] += msg.value;
        insert();
    }
   

    // 支持转移管理员权限
    function changeOwner(address newOwner) external{
        require(newOwner != address(0), "Invalid owner");
        owner = newOwner;
    }
    
}