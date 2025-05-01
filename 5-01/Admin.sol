// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./Bank.sol";
// Admin 合约
contract Admin {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier OnlyAdminOwner() {
        require(msg.sender == owner, "Only Admin owner");
        _;
    }

    // 通过 IBank 接口调用 Bank 的 withdraw 函数【这里bank参数传 BigBank 合约地址】
    function adminWithdraw(IBank bank) external OnlyAdminOwner {
        bank.withdraw(payable(address(this)));
    }

    function getBalance() external view returns (uint) {
        return address(this).balance;
    }

    receive() external payable {}
}