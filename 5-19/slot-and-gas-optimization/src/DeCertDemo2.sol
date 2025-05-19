// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// 重新修改 MyWallet 合约的 transferOwernship 和 auth 逻辑，使用内联汇编方式来 set和get owner 地址。
contract DeCertDemo1 { 
    string public name;
    mapping (address => bool) public approved;
    address public owner;
    // modifier auth {
    //     require (msg.sender == owner, "Not authorized");
    //     _;
    // }
    modifier auth() {
        address _owner;
        assembly {
            _owner := sload(2) // slot 2 是我们手动用于 owner 存储
        }
        require(msg.sender == _owner, "Not authorized");
        _;
    }

    constructor(string memory _name) {
        name = _name;
        // owner = msg.sender;
        assembly {
            sstore(2, caller()) // 设置 owner 为部署者
        }
    } 

    function transferOwnership(address _newOwner) public auth {
        require(_newOwner!=address(0), "New owner is the zero address");
        // owner = _addr;
        assembly {
            sstore(2, _newOwner) // 手动设置 owner 地址到 slot 2
        }
    }
    function getOwner() public view returns (address _owner) {
        assembly {
            _owner := sload(2) // 从 slot 2 读取 owner
        }
    }
}