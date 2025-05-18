// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// 钱包工厂合约(负责通过 CREATE2 生成合约)
contract WalletFactory {
    constructor() {}

    event WalletDeployed(address wallet, address owner);

    function getBytecode(address owner) public pure returns (bytes memory) {
        return abi.encodePacked(
                type(SimpleWallet).creationCode, // 被部署的合约
                abi.encode(owner)                // owner
            );
    }

    function getKeccak256ForByteCode(bytes memory _bytecode) public pure returns (bytes32){
        return keccak256(_bytecode);
    }

    function getKeccak256ForSalt(string memory _salt) public pure returns (bytes32){
        return keccak256(abi.encodePacked(_salt));
    }
    // @desc 提前预测生成的合约地址
    // salt: 任意值，用于区分不同部署
    // bytecodeHash: 合约构造函数编码后的字节码（getBytecode 返回之后经过 keccak256 转换）
    // @return 要部署的合约地址
    function computeAddress(bytes32 salt, bytes32 bytecodeHash)
        public
        view
        returns (address)
    {
        return address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                bytes1(0xff),
                                address(this),
                                salt,
                                bytecodeHash
                            )
                        )
                    )
                )
            );
    }
    // @notice 将 computeAddress 生成的预测合约地址进行部署
    // @param bytes32 salt 调用 getKeccak256ForSalt 函数生成的盐值 (与 computeAddress 的 salt 一致)
    // @param address owner 代币发行人（ 与 getBytecode 中的 owner 一致）
    function deploy(bytes32 salt, address owner) public returns (address) {
        bytes memory bytecode = getBytecode(owner);
        address addr;

        assembly {
            addr := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }

        emit WalletDeployed(addr, owner);
        return addr;
    }
}

// 被部署的合约 (用户充值的“钱包”)
contract SimpleWallet {
  address public owner;

    constructor(address _owner) payable {
        owner = _owner;
    }

    function withdraw() external {
        require(msg.sender == owner, "Not owner");
        payable(owner).transfer(address(this).balance);
    }

    receive() external payable {}
}
