// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
// 补充完整 Caller 合约 的 sendEther 方法，用于向指定地址发送 Ether。要求：

// 使用 call 方法发送 Ether
// 如果发送失败，抛出“sendEther failed”异常并回滚交易。
// 如果发送成功，则返回 true
contract Caller {

    function sendEther(address receiver, uint256 value) public returns (bool){
    
        (bool success, ) = payable(receiver).call{value: value}("");
        require(success, "sendEther failed");
        return success;
    }
    
}

