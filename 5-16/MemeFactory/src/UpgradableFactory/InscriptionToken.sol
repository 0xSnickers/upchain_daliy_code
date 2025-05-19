// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract InscriptionToken is ERC20 {
    address public owner;
    uint256 public totalSupply_;
    uint256 public perMint;
    uint256 public minted;
    bool public initialized;
    string private tokenSymbol;

    constructor(
        string memory _symbol,
        uint256 totalSupply,
        uint256 _perMint,
        address _owner
    ) ERC20("Meme Token", _symbol) {
        owner = _owner;
        totalSupply_ = totalSupply;
        perMint = _perMint;
        initialized = true;
        tokenSymbol = _symbol;

    }

    function initialize(
        string memory _symbol,
        uint256 totalSupply,
        uint256 _perMint,
        address _owner
    ) external {
        require(!initialized, "Already initialized");
        // _name = "Meme Token";
        tokenSymbol = _symbol;
        owner = _owner;
        totalSupply_ = totalSupply;
        perMint = _perMint;
        initialized = true;
    }
    function symbol() public view override returns (string memory) {
        return tokenSymbol;
    }
    function mint(address to) external {
        require(msg.sender == owner, "Only owner can mint");
        require(minted + perMint <= totalSupply_, "Exceeds total supply");
        minted += perMint;
        _mint(to, perMint * 1e18);
    }
}