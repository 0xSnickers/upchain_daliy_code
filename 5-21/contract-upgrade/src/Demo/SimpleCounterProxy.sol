// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// 原来版本的合约
contract CounterV1 {
    uint256 private counter; // slot=0
    // 升级前（i 参数未使用）
    function add(uint256 i) public {
        counter += 1;
    }

    function get() public view returns (uint256) {
        return counter;
    }
}

// 升级后的合约
contract CounterV2 {
    uint256 private counter;
    // 升级后的合约需要在 counter 插槽之后的位置，定义新的storage变量
    // 新storage变量...
    function add(uint256 i) public {
        counter += i;
    }

    function get() public view returns (uint256) {
        return counter;
    }
}

// 升级代理
contract CounterProxy {
    // 1:代理和逻辑合约的存储布局不一致发生无法预期的错误
    uint256 public counter; // counter slot 位置必须对应升级合约
    address public impl;
    constructor(address _impl){
        impl = _impl;
    }
    function upgradeTo(address _impl) public {
        impl = _impl;
    }
    function add(uint256 i) public {
        bytes memory callData = abi.encodeWithSignature("add(uint256)", i);
        (bool ok, ) = address(impl).delegatecall(callData);
        if (!ok) revert("Delegate call failed");
    }

    function get() public returns (uint256) {
        bytes memory callData = abi.encodeWithSignature("get()");
        (bool ok, bytes memory retVal) = address(impl).delegatecall(callData);
        if (!ok) revert("Delegate call failed");
        return abi.decode(retVal, (uint256));
    }
}
