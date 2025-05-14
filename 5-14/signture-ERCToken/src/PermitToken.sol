// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PermitToken is ERC20, ERC20Permit, Ownable {
    constructor(string memory _name, string memory _symbol) 
        ERC20(_name, _symbol)
        ERC20Permit(_name)
        Ownable(msg.sender)
    {
        // 初始发行 1000000 个代币给合约部署者
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    // 铸造新代币的函数，只有合约拥有者可以调用
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    // 销毁代币的函数
    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }
} 