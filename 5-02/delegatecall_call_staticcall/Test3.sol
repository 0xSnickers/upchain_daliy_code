// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
// 补充完整 Caller 合约的 callGetData 方法，
// 使用 staticcall 调用 Callee 合约中 getData 函数，并返回值。
// 当调用失败时，抛出“staticcall function failed”异常。
contract Caller {

    function callGetData(address callee) public view returns (uint256){
        bytes memory getDataMethod = abi.encodeWithSignature("getData()");
        // staticcall: 禁止修改状态
        (bool success, bytes memory data) = callee.staticcall(getDataMethod);
        require(success, "staticcall function failed");
        // 返回值类型转换
        (uint256 result) = abi.decode(data, (uint256));
        return result;
    }
    
}

contract Callee {
    function getData() public view returns (uint256){
        return uint256(uint160(address(this))); // 将地址转换为 uint256
    }
}
