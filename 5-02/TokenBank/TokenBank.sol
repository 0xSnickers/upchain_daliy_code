// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./BaseERC20.sol";


event DepositeLog(address indexed _depositor,uint256 indexed _depositAmount);
event WithdrawLog(address indexed _addr);

contract TokenBank{
    mapping(address => uint256) public token_balances;
    address public token_address;

    // _token_address=token合约地址
    constructor(address _token_address) {
        token_address = _token_address;
    }
    // 存款
    function deposit(uint256 _depositAmount) external {
        require(_depositAmount > 0,"must deposits more than 0.");

        // 授权-允许 Token 的所有者批准某个地址消费他们的一部分Token
        bool success_approve = IBaseERC20(token_address).approve(msg.sender, address(this), _depositAmount);
        require(success_approve, "Token Approve Failed!");

        // 消费 Token
        bool success_transfer = IBaseERC20(token_address).transferFrom(msg.sender, address(this), _depositAmount);
        require(success_transfer, "Transfer Failed !");

        token_balances[msg.sender] += _depositAmount;

        emit DepositeLog(msg.sender, _depositAmount);
    }
    // 取款
    function withdraw(uint256 _amount) external {
        require(_amount > 0, "amount must > 0");
        require(token_balances[msg.sender] > 0, "not enough token balance!");
        require(IBaseERC20(token_address).transfer(msg.sender, _amount), "Transfer Failed !");
        token_balances[msg.sender] -= _amount;

        emit WithdrawLog(msg.sender);
    }
    // 查询Token余额
    function getBalance(address _addr) external view returns (uint256){
        return IBaseERC20(token_address).balanceOf(_addr);
    }
}