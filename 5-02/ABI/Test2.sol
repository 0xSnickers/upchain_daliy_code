pragma solidity ^0.8.0;

// 完善ABIEncoder合约的 encodeUint 和 encodeMultiple 函数，使用abi.encode对参数进行编码并返回
// 完善ABIDecoder合约的 decodeUint 和 decodeMultiple 函数，使用abi.decode将字节数组解码成对应类型的数据

contract ABIEncoder {
    function encodeUint(uint256 value) public pure returns (bytes memory) {
        return abi.encode(value);
    }

    function encodeMultiple(uint num, string memory text) public pure returns (bytes memory) {
       return abi.encode(num, text);
    }
}

contract ABIDecoder {
    function decodeUint(bytes memory data) public pure returns (uint) {
        (uint num) = abi.decode(data, (uint));
        return num;
    }

    function decodeMultiple(bytes memory data) public pure returns (uint, string memory) {
        (uint num, string memory text) =  abi.decode(data, (uint, string));
        return (num, text);
    }
}