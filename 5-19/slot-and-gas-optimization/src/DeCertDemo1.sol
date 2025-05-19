// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract DeCertDemo1 { 
    string public name;
    mapping (address => bool) public approved;
    address public owner;
    modifier auth {
        require (msg.sender == owner, "Not authorized");
        _;
    }

    constructor(string memory _name) {
        name = _name;
        owner = msg.sender;
    } 

    function transferOwernship(address _addr) public auth {
        require(_addr!=address(0), "New owner is the zero address");
        require(owner != _addr, "New owner is the same as the old owner");
        owner = _addr;
    }
}