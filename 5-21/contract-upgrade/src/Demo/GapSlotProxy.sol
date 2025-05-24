
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
// 模拟继承关系 A -> B -> C
contract A {
    uint256 public a; // slot 0
    uint256[50] private __gap; // 预留 slot 1~50: gap（占位，未使用）

    function add(uint256 i) public virtual {
        a += 1;
    }
    function get() public view virtual returns(uint256) {
        return a;
    }
}

contract B is A{
    uint256 public b; // slot 51

    function add(uint256 i) public  override virtual{
        // 此时 GapSlotProxy 调用 add 已经不再改变 a 的值
        b += i;
    }
    function get() public view override virtual returns (uint256) {
        return b;
    }
}

contract C is B{
    uint256 public c; // slot 52
 
    function add(uint256 i) public  override {
        // 此时 GapSlotProxy 调用 add 已经不再改变 a 的值
        c += i;
    }
    function get() public view override returns (uint256) {
        return c;
    }
}

// A合约升级 -> A_V2
contract A_V2 {
    uint256 public a;              // slot 0（不变）
    uint256 public newVar1;        // slot 1（原 __gap[0]）
    uint256 public newVar2;        // slot 2（原 __gap[1]）
    uint256[48] private __gap;     // slot 3~50（保留 gap）
    function add(uint256 i) public virtual {
        a += 1;
        newVar1 += 1;
        newVar2 += 1;
    }
    function get() public view virtual returns(uint256) {
        return a;
    }
}

contract GapSlotProxy{
    uint256 public a; // slot 0
    uint256 public newVar1;        // slot 1（原 __gap[0]）
    uint256 public newVar2;        // slot 2（原 __gap[1]）
    uint256[48] private __gap; // 预留 slot 1~50: gap（占位，未使用）
    uint256 public b; // slot 51
    uint256 public c; // slot 52

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
