// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PermitTokenBank.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// 创建一个测试用的 ERC20 代币
contract TestToken is ERC20 {
    constructor() ERC20("Test Token", "TEST") {
        _mint(msg.sender, 10000000 * 10 ** 18); // 增加初始铸造量
    }

    // 添加铸造函数供测试使用
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract PermitTokenBankTest is Test {
    struct TopDepositor {
        address user;
        uint256 amount;
    }
    PermitTokenBank public bank;
    TestToken public token;
    address[] public users;
    uint256 public constant INITIAL_BALANCE = 2000 * 10 ** 18;
    address public deployer;

    function setUp() public {
        deployer = msg.sender;
        // 部署测试代币
        token = new TestToken();
        // 部署银行合约
        bank = new PermitTokenBank(address(token));

        // 创建测试用户
        for (uint i = 0; i < 20; i++) {
            address user = address(
                uint160(uint256(keccak256(abi.encodePacked(i))))
            );
            users.push(user);
            // 给每个用户转一些代币
            token.transfer(user, INITIAL_BALANCE);
        }

        // 确保测试账户有足够的代币
        token.mint(deployer, 10000000 * 10 ** 18);
    }
    // 测试 gas 消耗
    function testGasConsumption() public {
        uint256 N = 10000; // 测试次数
        uint256 interval = 1000; // 每间隔 1000 次调用打印一次 Gas 消耗
        console.log("\nGas Consumption Report (every %d iterations)", interval);
        console.log("=========================================");
        console.log("Operation | Iteration | Gas Used");
        console.log("----------|-----------|----------");

        // 测试存款操作
        for (uint i = 0; i < N; i++) {
            address user = users[i % users.length];
            vm.startPrank(user);

            // 确保用户有足够的余额
            if (token.balanceOf(user) < 100 * 10 ** 18) {
                vm.stopPrank();
                vm.startPrank(deployer);
                token.transfer(user, INITIAL_BALANCE);
                vm.stopPrank();
                vm.startPrank(user);
            }

            token.approve(address(bank), INITIAL_BALANCE);
            uint256 gasBefore = gasleft();
            bank.deposit(100 * 10 ** 18);
            uint256 gasAfter = gasleft();
            vm.stopPrank();

            if ((i + 1) % interval == 0 || i == 0) {
                console.log(
                    "Deposit   | %d        | %d",
                    i + 1,
                    gasBefore - gasAfter
                );
            }
        }

        // 测试提现操作
        for (uint i = 0; i < N; i++) {
            address user = users[i % users.length];
            vm.startPrank(user);

            // 确保用户在银行中有足够的余额
            if (bank.balanceOf(user) < 50 * 10 ** 18) {
                // 如果余额不足，先存入一些代币
                if (token.balanceOf(user) < 100 * 10 ** 18) {
                    vm.stopPrank();
                    vm.startPrank(deployer);
                    token.transfer(user, INITIAL_BALANCE);
                    vm.stopPrank();
                    vm.startPrank(user);
                }
                token.approve(address(bank), INITIAL_BALANCE);
                bank.deposit(100 * 10 ** 18);
            }

            uint256 gasBefore = gasleft();
            bank.withdraw(50 * 10 ** 18);
            uint256 gasAfter = gasleft();
            vm.stopPrank();

            if ((i + 1) % interval == 0 || i == 0) {
                console.log(
                    "Withdraw  | %d        | %d",
                    i + 1,
                    gasBefore - gasAfter
                );
            }
        }

        // 测试排名更新
        for (uint i = 0; i < N; i++) {
            address user = users[i % users.length];
            vm.startPrank(user);

            // 确保用户有足够的余额
            if (token.balanceOf(user) < 200 * 10 ** 18) {
                vm.stopPrank();
                vm.startPrank(deployer);
                token.transfer(user, INITIAL_BALANCE);
                vm.stopPrank();
                vm.startPrank(user);
            }

            token.approve(address(bank), INITIAL_BALANCE);
            uint256 gasBefore = gasleft();
            bank.deposit(200 * 10 ** 18);
            uint256 gasAfter = gasleft();
            vm.stopPrank();

            if ((i + 1) % interval == 0 || i == 0) {
                console.log(
                    "UpdateRank| %d        | %d",
                    i + 1,
                    gasBefore - gasAfter
                );
            }
        }
    }

    // 测试前 10 名用户的排名变化
    function testTopDepositors() public {
        // 让前 15 个用户进行存款，测试排名变化
        for (uint i = 0; i < 15; i++) {
            vm.startPrank(users[i]);
            token.approve(address(bank), INITIAL_BALANCE);
            bank.deposit((i + 1) * 100 * 10 ** 18);
            vm.stopPrank();
        }
        
        // 验证前 10 名用户
        console.log("\nTop 10 Depositors");
        console.log("=================");
        for (uint i = 0; i < 10; i++) {
            (address user, uint256 amount) = bank.getTopDepositor(i);
            console.log("Rank %d: %s - %d", i + 1, user, amount);
        }

    }
}
