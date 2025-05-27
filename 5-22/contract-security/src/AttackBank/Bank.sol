// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Bank{
    mapping(address => uint256) public deposits;
    function deposit() public payable {
        deposits[msg.sender] += msg.value;
    }
    function withdraw() public {
        require(deposits[msg.sender] > 0, "No funds to withdraw");
        (bool success, ) = msg.sender.call{value: deposits[msg.sender]}("");
        deposits[msg.sender] = 0;
        require(success, "Failed to send Ether");
    }
    // 加入防止重入攻击的nonReentrant
    // function withdraw() public ReentrancyGuard{
    //     require(deposits[msg.sender] > 0, "No funds to withdraw");
    //     (bool success, ) = msg.sender.call{value: deposits[msg.sender]}("");
    //     deposits[msg.sender] = 0;
    //     require(success, "Failed to send Ether");
    // }
    function getBalance() public view returns(uint256){
        return address(this).balance;
    }
}