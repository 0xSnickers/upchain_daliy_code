// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ITokenReceiver.sol";
import "forge-std/console.sol";

contract MyToken is ERC20, Ownable {
    error CallbackFailed();

    constructor(
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        // 初始发行 1000000 个代币给合约部署者
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    /**
     * @dev 带回调的转账函数【类似 ERC20 transferAndCall 函数】
     * @param to 接收代币的地址
     * @param amount 转账数量
     * @param data 转账附带的 data
     * @return 是否成功
     */
    function transferWithCallback(
        address to,
        uint256 amount,
        bytes calldata data
    ) public returns (bool) {
        // 执行转账
        bool success = transfer(to, amount);
        require(success, "MyToken: transfer failed");

        // 如果接收者是合约，调用其 tokensReceived 方法
        if (to.code.length > 0) {
            try ITokenReceiver(to).tokensReceived(msg.sender,address(this),amount,data) returns (bool result) {
                // 如果 tokensReceived 返回 false 执行回退
                require(result, "MyToken: callback failed");
            } catch Error(string memory reason) {
                // catch Error 只能捕获显式 require("reason"), revert("reason")
                // 并返回 字符串 错误提示
                console.log("reason => ", reason); 
                
                revert(reason);
            } 
              catch {
                // 捕获到 tokensReceived 触发require回退
                // revert("MyToken: catch callback failed");
                revert CallbackFailed();
            }
        }

        return true;
    }
}
