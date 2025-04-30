// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
// ETH批量转账
contract BatchTransferETH {
    // error 自定义错误：1.如果转账失败，我们就会抛出这个错误 ｜ 2.记录失败的接收地址和金额。
    // 特点：相比 revert("xxx")，自定义错误 更省 Gas
    error TransferFailed(address to, uint256 amount);
  
    /// @notice 批量转账 ETH
    /// @param recipients 接收地址数组
    /// @param amounts 对应每个接收地址的转账金额（单位：wei）
    function batchTransferETH(address[] calldata recipients, uint256[] calldata amounts) external payable {
        // recipients 和 amounts 长度必须一致
        require(recipients.length == amounts.length, "Length mismatch");

        uint256 totalAmount;
        // 计算当前批量转账需要的总金额
        for (uint256 i = 0; i < recipients.length; i++) {
            totalAmount += amounts[i];
        }
        // 当前合约余额小于totalAmount，则抛出异常
        require(msg.value >= totalAmount, "Insufficient ETH sent");

        for (uint256 i = 0; i < recipients.length; i++) {
            // 这里的 payable(recipients[i]) 作用：强制类型转换
            // - 把 recipients[i] 这个地址，转换为 payable address 类型，然后再调用 .call{...}
            // - address 类型是默认不可接受ETH，只有 address payable 类型，才允许你调用 .transfer() 或 .call{value:...}() 等发送 ETH 的方法
            (bool success, ) = payable(recipients[i]).call{value: amounts[i]}("");

            // 如果其中一个转账失败，则触发error（并把失败的地址+amount传入）
            if (!success) revert TransferFailed(recipients[i], amounts[i]);
        }

        // 多余的退还
        uint256 remaining = msg.value - totalAmount;
        if (remaining > 0) {
            payable(msg.sender).transfer(remaining);
        }
    }
}
