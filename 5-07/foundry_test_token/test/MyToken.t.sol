// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {MyToken} from "../src/MyToken.sol";

contract CounterTest is Test {
    MyToken public token;
    address public owner = address(0xABCD); // 自定义部署者地址

    function setUp() public {
        vm.prank(owner); // 模拟由 owner 地址部署
        token = new MyToken("Snikers", "SNK");
    }

    function testNameAndSymbol() public view {
        assertEq(token.name(), "Snikers");
        assertEq(token.symbol(), "SNK");
    }

    function testDecimals() public view{
        assertEq(token.decimals(), 18);
    }

    function testInitialSupply() public view{
        uint256 expectedSupply = 1_000_000 * 10 ** 18;
        assertEq(token.totalSupply(), expectedSupply);
        assertEq(token.balanceOf(owner), expectedSupply);
    }

    function testTransfer() public {
        address recipient = address(0xBEEF);
        uint256 amount = 1000 * 10 ** 18;
        // 临时修改下一次外部调用的 msg.sender = owner
        vm.prank(owner);
        // Test：owner 赚钱给-> recipient
        token.transfer(recipient, amount);

        assertEq(token.balanceOf(recipient), amount);
        assertEq(token.balanceOf(owner), token.totalSupply() - amount);
    }

    function testOnlyOwnerAccess() public view{
        assertEq(token.owner(), owner);
    }
}
