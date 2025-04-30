// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 编写一个 Bank 合约，实现功能：
// 1. 可以通过 Metamask 等钱包直接给 Bank 合约地址存款
// 2. 在 Bank 合约记录每个地址的存款金额
// 3. 编写 withdraw() 方法，仅管理员可以通过该方法提取资金。
// 4. 用数组记录存款金额的前 3 名用户

contract Bank {
    struct User{
        address addr;
        uint amount;
    }
    // 记录每个地址的存款金额
    User[] internal  bank_addr_list;
   
    // address[] internal top_three_addr; 
   
    // 声明当前合约可接收ETH
    receive() external payable {
    }
    // 1. 给 Bank 合约地址存款
    function deposit() external payable {
        require(msg.value > 0, "msg.value must > 0!");
        
        // 把钱存到合约
        payable(address(this)).transfer(msg.value);

        // 2. 记录每个地址的存款金额
        uint _length = bank_addr_list.length;

        if(_length == 0){
            bank_addr_list.push(User(msg.sender, msg.value));
            return;
        }

        // 遍历查看当前地址是否已经有存款
        bool is_existing =  false;

        for(uint i=0; i < _length; i++){
            if(bank_addr_list[i].addr == msg.sender){
                // 有存款，累加余额
                bank_addr_list[i].amount += msg.value;
                is_existing = true;
            }
        }

        if(!is_existing){
            // 第一次存💰
            bank_addr_list.push(User(msg.sender, msg.value));
        }
        
    }
    // @notice 3. 仅管理员可以通过该方法提取资金
    // @param withdraw_addr 将合约的资金提取到这里
    // @param amount 提取多少
    function withdraw(address payable withdraw_addr, uint amount) external {
        require(msg.sender == address(this), "only manager can withdraw!");
        require(amount > 0, "amount must > 0!");
        withdraw_addr.transfer(amount);
    }
    
    // 获取指定地址存款余额
    function getBalanceByAddr(address addr) external view returns (uint balance){
        for(uint i = 0 ; i < bank_addr_list.length; i++){
            if(bank_addr_list[i].addr == addr){
                balance = bank_addr_list[i].amount;
                break;
            }
        }
        balance = balance / 1e18;
    }
    
    // 4. 存款金额的前 3 名用户
    function getTop3() public view returns (User[3] memory) {
        require(bank_addr_list.length > 0, "Empty array");
        
        User[3] memory top3;
        
        // 初始化前3名
        for (uint i = 0; i < 3 && i < bank_addr_list.length; i++) {
            top3[i] = User({
                addr: bank_addr_list[i].addr,
                amount: bank_addr_list[i].amount
            });
        }
        
        // 部分排序
        for (uint i = 3; i < bank_addr_list.length; i++) {
            uint256 currentBalance = bank_addr_list[i].amount;
            
            // 检查是否能进入前3
            if (currentBalance > top3[2].amount) {
                top3[2] = User(bank_addr_list[i].addr, currentBalance);
                
                // 保持前3有序
                if (top3[2].amount > top3[1].amount) {
                    (top3[1], top3[2]) = (top3[2], top3[1]);
                    if (top3[1].amount > top3[0].amount) {
                        (top3[0], top3[1]) = (top3[1], top3[0]);
                    }
                }
            }
        }
        
        return top3;
    }
}