// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Bank} from "../src/Bank.sol";

// 为 Bank 合约 编写测试。

// 测试Case 包含：

// 断言检查存款前后用户在 Bank 合约中的存款额更新是否正确。
// 检查存款金额的前 3 名用户时候正确，分别检查有1个、2个、3个、4 个用户， 以及同一个用户多次存款的情况。
// 检查只有管理员可取款，其他人不可以取款。

contract BankTest is Test {
    Bank public bank;
    address public admin;
    address public user1;
    address public user2;
    address public user3;
    address public user4;

    function setUp() public {
        // 设置测试账户
        admin = makeAddr("admin");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        user4 = makeAddr("user4");

        // 部署银行合约
        bank = new Bank();

        // 给测试用户分配 ETH
        vm.deal(user1, 1000 ether);
        vm.deal(user2, 1000 ether);
        vm.deal(user3, 1000 ether);
        vm.deal(user4, 1000 ether);

        // 设置管理员
        bank.setAdmin(admin);
    }
    // 验证存款后余额更新是否正确
    function test_DepositAndBalance() public {
        // 用户1存款
        vm.startPrank(user1);
        (bool success,) = address(bank).call{value: 50 ether}("");
        require(success, "ETH transfer failed");
        assertEq(bank.balanceOf(user1), 50 ether);
        vm.stopPrank();

        // 用户2存款
        vm.startPrank(user2);
        (success,) = address(bank).call{value: 30 ether}("");
        require(success, "ETH transfer failed");
        assertEq(bank.balanceOf(user2), 30 ether, "User2 balance should be 30 ether");
        vm.stopPrank();
    }

    function test_TopDepositors() public {
        // 用户1存款 100 ether
        vm.startPrank(user1);
        (bool success,) = address(bank).call{value: 100 ether}("");
        require(success, "ETH transfer failed");
        vm.stopPrank();

        // 用户2存款 80 ether
        vm.startPrank(user2);
        (success,) = address(bank).call{value: 80 ether}("");
        require(success, "ETH transfer failed");
        vm.stopPrank();

        // 用户3存款 60 ether
        vm.startPrank(user3);
        (success,) = address(bank).call{value: 60 ether}("");
        require(success, "ETH transfer failed");
        vm.stopPrank();

        // 用户4存款 40 ether
        vm.startPrank(user4);
        (success,) = address(bank).call{value: 40 ether}("");
        require(success, "ETH transfer failed");
        vm.stopPrank();

        // 检查前3名存款用户
        address[3] memory topDepositors = bank.get_top_three_addr();
        assertEq(topDepositors[0], user1, "Top depositor should be user1");
        assertEq(topDepositors[1], user2, "Second depositor should be user2");
        assertEq(topDepositors[2], user3, "Third depositor should be user3");
    }

    function test_MultipleDeposits() public {
        vm.startPrank(user1);
        
        // 第一次存款
        (bool success,) = address(bank).call{value: 50 ether}("");
        require(success, "ETH transfer failed");
        assertEq(bank.balanceOf(user1), 50 ether, "First deposit balance should be 50 ether");
        
        // 第二次存款
        (success,) = address(bank).call{value: 30 ether}("");
        require(success, "ETH transfer failed");
        assertEq(bank.balanceOf(user1), 80 ether, "Total balance after second deposit should be 80 ether");
        
        // 第三次存款
        (success,) = address(bank).call{value: 20 ether}("");
        require(success, "ETH transfer failed");
        assertEq(bank.balanceOf(user1), 100 ether, "Total balance after third deposit should be 100 ether");
        vm.stopPrank();
    }

    function test_WithdrawPermissions() public {
        // 用户1存款
        vm.startPrank(user1);
        (bool success,) = address(bank).call{value: 50 ether}("");
        require(success, "ETH transfer failed");
        vm.stopPrank();

        // 非管理员尝试取款
        vm.startPrank(user2);
        vm.expectRevert("Bank: only admin can withdraw");
        bank.withdraw(user1, 20 ether);
        vm.stopPrank();

        // 管理员取款
        vm.startPrank(admin);
        bank.withdraw(user1, 20 ether);
        assertEq(bank.balanceOf(user1), 30 ether, "User1 balance should be 30 ether after withdrawal");
        vm.stopPrank();
    }

    function test_WithdrawAmount() public {
        // 用户1存款
        vm.startPrank(user1);
        (bool success,) = address(bank).call{value: 50 ether}("");
        require(success, "ETH transfer failed");
        vm.stopPrank();

        // 管理员尝试取款超过余额
        vm.startPrank(admin);
        vm.expectRevert("Bank: insufficient balance");
        bank.withdraw(user1, 60 ether);
        vm.stopPrank();
    }

    function test_DepositWithInsufficientETH() public {
        vm.startPrank(user1);
        vm.expectRevert(); // 预期 ETH 转账失败
        (bool success,) = address(bank).call{value: 2000 ether}(""); // 尝试存入超过余额的 ETH
        require(!success, "ETH transfer should fail");
        vm.stopPrank();
    }

    function test_ContractBalance() public {
        // 用户1存款
        vm.startPrank(user1);
        (bool success,) = address(bank).call{value: 50 ether}("");
        require(success, "ETH transfer failed");
        vm.stopPrank();

        // 检查合约余额
        assertEq(address(bank).balance, 50 ether, "Contract balance should be 50 ether");
    }
}
