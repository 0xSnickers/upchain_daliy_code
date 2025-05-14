// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// ERC721Enumerable: 基于 ERC721 拓展
contract MyERC721Enumerable is ERC721Enumerable, Ownable {
    uint256 public nextTokenId;
    string private baseTokenURI;

    constructor(string memory _name, string memory _symbol, string memory _initBaseURI) ERC721(_name, _symbol) Ownable(msg.sender) {
        baseTokenURI = _initBaseURI;
    }

    /// @notice 铸造一个 NFT 给指定地址
    function mint(address to) external onlyOwner {
        _safeMint(to, nextTokenId);
        nextTokenId++;
    }

  
    /// @notice 设置 baseURI（只有合约拥有者可以）
    function setBaseURI(string memory _baseTokenURI) public onlyOwner {
        baseTokenURI = _baseTokenURI;
    }
    /// @notice 返回 token 的元数据 URL(重写_baseURI)
    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
    }
}
