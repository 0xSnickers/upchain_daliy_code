// SPDX-License-Identifier: MIT
pragma solidity =0.6.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MemeToken is ERC20 {
    address public owner;
    uint256 public totalSupply_;
    uint256 public perMint;
    uint256 public price;
    uint256 public minted;
    string private tokenSymbol;
    event ReceivedFee(address indexed from, uint256 amount);
    constructor() public ERC20("", "") {
        // Empty constructor, initialization will happen through initialize()
    }

    function initialize(
        address _owner,
        string calldata _symbol,
        uint256 _totalSupply,
        uint256 _perMint,
        uint256 _price
    ) external {
        require(owner == address(0), "Already initialized");
        owner = _owner;
        totalSupply_ = _totalSupply;
        perMint = _perMint;
        price = _price;
        tokenSymbol = _symbol;
    }


    function symbol() public view override returns (string memory) {
        return tokenSymbol;
    }

    function mint(address _sender) external payable {
        require(minted + perMint <= totalSupply_, "Exceeds total supply");
        
        minted += perMint;
        _mint(_sender, perMint);
    }

    function withdrawFees() external {
        require(msg.sender == owner, "Only owner");
        payable(owner).transfer(address(this).balance);
    }
    receive() external payable { 
        emit ReceivedFee(msg.sender, msg.value);
    }
}
