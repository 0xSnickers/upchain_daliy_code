pragma solidity ^0.8.0;

// 补充完整getFunctionSelector1函数，返回 getValue 函数的签名

// 补充完整getFunctionSelector2函数，返回 setValue 函数的签名

contract FunctionSelector {
    uint256 private storedValue;

    function getValue() public view returns (uint) {
        return storedValue;
    }

    function setValue(uint value) public {
        storedValue = value;
    }

    function getFunctionSelector1() public pure returns (bytes4 _res) {
        _res = bytes4(keccak256("getValue()"));
    }

    function getFunctionSelector2() public pure returns (bytes4 _res) {
        _res = bytes4(keccak256("setValue(uint256)"));

    }
}
