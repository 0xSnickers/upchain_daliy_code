// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// 原来版本的合约
contract CounterV1 {
    struct User{
        address user;
        uint256 count;
    }
    uint256 private counter; // slot=0
    mapping(address => User) public userInfo;
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
     struct User{
        address user;
        uint256 count;
        uint256 version;
    }
    uint256 private counter; // slot=0
    mapping(address => uint256) public userInfo;
    function add(uint256 i) public {
        counter += i;
    }

    function get() public view returns (uint256) {
        return counter;
    }
}

// 升级代理
contract CounterProxy {
    struct User{
        address user;
        uint256 count;
        uint256 version;
    }
    uint256 private counter; // slot=0
    mapping(address => uint256) public userInfo;
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

   
    function _get() public returns (uint256) {
        bytes memory callData = abi.encodeWithSignature("get()");
        (bool ok, bytes memory retVal) = address(impl).delegatecall(callData);
        if (!ok) revert("Delegate call failed");
        return abi.decode(retVal, (uint256));
    }
}
