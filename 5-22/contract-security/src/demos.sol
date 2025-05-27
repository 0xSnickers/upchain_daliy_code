// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";


// entrants 可能会存在 length 数量过大
// 导致遍历的时候 gas 超出限制导致方法无法正常运行
contract demo2{
    address[] public entrants;
   function enter() public {
        // Check for duplicate entrants
        for (uint256 i; i < entrants.length; i++) {
            if (entrants[i] == msg.sender) {
                revert("You've already entered!");
            }
        }
        entrants.push(msg.sender);
    }
}

// 问题：会导致拒绝服务（DoS）攻击
contract demo3{
    uint256 public totalDeposits;
    mapping(address => uint256) public deposits;

    function deposit() external payable {
        deposits[msg.sender] += msg.value;
        totalDeposits += msg.value;
    }

    function withdraw() external {
        // 如使用 selfdestruct 或直接 send 方法去改变 address(this).balance
        // 下面判断永远过不了（合约会被 🔒 死）
        assert(address(this).balance == totalDeposits);
    
        uint256 amount = deposits[msg.sender];
        totalDeposits -= amount;
        deposits[msg.sender] = 0;

        payable(msg.sender).transfer(amount); // 0
    }
}


// 问题：v, r, s 签名可能会被重入攻击（被别人用高 gas 覆盖）
contract demo4 is EIP712{
    using ECDSA for bytes32;

    bytes32 public constant TYPEHASH = keccak256("withdrawBySig(uint256 amount)");
    mapping(address => uint256) public balances;
    mapping(address => bool) public inWhitelist;
    constructor() EIP712("Test","1"){}
    function withdrawBySig(uint8 v, bytes32 r, bytes32 s, uint256 amount) external payable {
        bytes32 structHash = keccak256(abi.encode(TYPEHASH, amount));
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, v, r, s);
        require(inWhitelist[signer], "error signer");
        _withdraw(signer, amount);
    }

    function _withdraw(address user, uint256 amount) internal {
        uint256 currentBalance = balances[user];
        if (currentBalance < amount) {
            // revert SignatureReplay__InsufficientBalance(currentBalance, amount);
            revert("SignatureReplay__InsufficientBalance");
        }
        balances[user] = currentBalance - amount;
        payable(msg.sender).transfer(amount);
    }
  
}

// 问题：count 会造成算术溢出（unchecked会跳过溢出检查）
contract demo5 {
    uint256 public moneyToSplitUp = 225;
    uint256 public users = 4;
    uint count;

    function shareMoney() public view returns (uint256 ) {
        return moneyToSplitUp / users;
    }

    function decrement() public {
        unchecked {
            count--;
        }
    }
}



// 问题：未来以太网不会对 （EOA｜合约） 用户进行区分（统一合并）
contract demo6 {
    function isContract(address account) public view returns (bool) {
        uint size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    // 确保仅有 EOA 能调用
    function protected() external {
        require(msg.sender.code.length == 0, "no contract allowed");
    }
    
}

