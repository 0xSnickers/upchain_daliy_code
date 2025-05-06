// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface ITokenReceiver {
    function tokensReceived(
        address sender,
        address token,
        uint256 amount
    ) external returns (bool);
} 

contract MyToken is ERC20, Ownable {
    constructor() ERC20("Snikers", "SNK") Ownable(msg.sender) {
        // 初始发行 1000000 个代币给合约部署者
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    /**
     * @dev 带回调的转账函数
     * @param to 接收代币的地址
     * @param amount 转账数量
     * @return 是否成功
     */
    function transferWithCallback(address to, uint256 amount) public returns (bool) {
        // 执行转账
        bool success = transfer(to, amount);
        require(success, "MyToken: transfer failed");

        // 如果接收者是合约，调用其 tokensReceived 方法
        if (to.code.length > 0) {
            try ITokenReceiver(to).tokensReceived(msg.sender, address(this), amount) returns (bool result) {
                require(result, "MyToken: callback failed");
            } catch {
                revert("MyToken: callback failed");
            }
        }

        return true;
    }
} 