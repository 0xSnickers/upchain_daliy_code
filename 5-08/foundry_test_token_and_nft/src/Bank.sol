// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBank {
    function withdraw(address _addr, uint amount) external;
    function getBalance() external view returns (uint);
    function setAdmin(address newOwner) external;
}

contract Bank is IBank{
    uint constant CONSTANT_NUM = 3; // Top 3
    address public owner;
    mapping(address=>uint) balances;
    mapping(address=>bool) deposite_user_exist;
    address[] deposite_user; 
    address[CONSTANT_NUM] top_three_addr;
    uint size;
    constructor(){
        // 初始化时，保存当前合约地址
        owner = msg.sender;
    }
    // 函数修改器
    modifier OnlyOwner(){
        require(msg.sender == owner, "Only owner can call this function.");
        _;
    }

    receive() external payable {
        require(msg.value > 0, "Invalid deposite.");
        // 不需要再转账给自己
        if(!deposite_user_exist[msg.sender]){
            deposite_user_exist[msg.sender] = true;
            deposite_user.push(msg.sender);
        }
        balances[msg.sender] += msg.value;
        insert();
    }

  
   
    function insert() internal {
        // 是否已经在 top3 中
        int existingIndex = -1;
        for (uint i = 0; i < size; i++) {
            if (top_three_addr[i] == msg.sender) {
                existingIndex = int(i);
                break;
            }
        }

        if (existingIndex != -1) {
            // 已存在，只需要重新排序
            sortDescending();
            return;
        }

        if (size < CONSTANT_NUM) {
            // 未满，直接添加
            top_three_addr[size] = msg.sender;
            size++;
        } else {
            // 找出当前 top3 中最小值的 index
            uint lowestIndex = 0;
            for (uint i = 1; i < CONSTANT_NUM; i++) {
                if (balances[top_three_addr[i]] < balances[top_three_addr[lowestIndex]]) {
                    lowestIndex = i;
                }
            }

            // 仅当 msg.sender 的余额更大，且不重复，才替换
            if (balances[msg.sender] > balances[top_three_addr[lowestIndex]]) {
                top_three_addr[lowestIndex] = msg.sender;
            }
        }

        sortDescending();
    }

    

    function sortDescending() internal {
        for (uint256 i = 0; i < CONSTANT_NUM; i++) {
            for (uint256 j = i + 1; j < CONSTANT_NUM; j++) {
                if (balances[top_three_addr[j]] > balances[top_three_addr[i]]) {
                    (top_three_addr[i], top_three_addr[j]) = (top_three_addr[j], top_three_addr[i]);
                }
            }
        }
    }

    // 仅管理员可以通过该方法提取资金。
    function withdraw(address _addr, uint amount) external OnlyOwner {
        require(amount > 0, "withdraw: amount must > 0");
        require(balances[_addr] >= amount, "Bank: insufficient balance");
        balances[_addr] -= amount;
        (bool success,) = payable(_addr).call{value: amount}("");
        require(success, "withdraw failed!");
    }

    function get_top_three_balance() external view returns(uint[CONSTANT_NUM] memory result){
        for(uint i=0; i < top_three_addr.length; i++){
            result[i] = balances[top_three_addr[i]];
        }
    }

    function get_top_three_addr() external view returns(address[CONSTANT_NUM] memory){
        return top_three_addr;
    }
    function balanceOf(address addr) external view returns(uint){
        return balances[addr];
    }
    function getBalance() external view returns(uint){
        return address(this).balance;
    }
    // 支持转移管理员权限
    function setAdmin(address newOwner) external OnlyOwner {
        require(newOwner != address(0), "Invalid owner");
        owner = newOwner;
    }
}