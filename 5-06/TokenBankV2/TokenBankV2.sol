// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./MyToken.sol";
import "./TokenBank.sol";

contract TokenBankV2 is TokenBank, ITokenReceiver {
    constructor(address token_address_) TokenBank(token_address_) {}
    /**
     * @dev 实现 ITokenReceiver 接口
     * @param sender 发送者地址
     * @param token 代币合约地址
     * @param amount 转账数量
     * @return 是否成功
     */
    function tokensReceived(
        address sender,
        address token,
        uint256 amount
    ) external override returns (bool) {
        require(token == token_address, "TokenBankV2: tokensReceived failed");

        // 更新余额
        _balances[sender] += amount;
        _totalDeposits += amount;

        emit Deposit(sender, amount);
        return true;
    }

} 