// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {PermitToken} from "../src/PermitToken.sol";
import {PermitTokenBank} from "../src/PermitTokenBank.sol";

contract PermitTokenBankTest is Test {
    PermitToken public permitToken;
    PermitTokenBank public permitTokenBank;
    
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    uint256 public constant INITIAL_BALANCE = 1000 ether;
    uint256 public constant DEPOSIT_AMOUNT = 100 ether;

    function setUp() public {
        // 部署代币合约
        permitToken = new PermitToken("Permit Token", "PTK");
        // 部署银行合约
        permitTokenBank = new PermitTokenBank(address(permitToken));
        
        // 给测试账户分配代币
        permitToken.mint(alice, INITIAL_BALANCE);
        permitToken.mint(bob, INITIAL_BALANCE);
    }

    function test_InitialSetup() public view {
        assertEq(permitToken.balanceOf(alice), INITIAL_BALANCE);
        assertEq(permitToken.balanceOf(bob), INITIAL_BALANCE);
        assertEq(permitTokenBank.token_address(), address(permitToken));
        assertEq(permitTokenBank.totalDeposits(), 0);
    }

    function test_NormalDeposit() public {
        vm.startPrank(alice);
        // 先授权
        permitToken.approve(address(permitTokenBank), DEPOSIT_AMOUNT);
        // 存款
        permitTokenBank.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();

        assertEq(permitTokenBank.balanceOf(alice), DEPOSIT_AMOUNT);
        assertEq(permitTokenBank.totalDeposits(), DEPOSIT_AMOUNT);
        assertEq(permitToken.balanceOf(address(permitTokenBank)), DEPOSIT_AMOUNT);
    }

    function test_PermitDeposit() public {
        // 准备签名数据
        uint256 privateKey = 0xA11CE;
        address signer = vm.addr(privateKey);
        permitToken.mint(signer, INITIAL_BALANCE);

        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = permitToken.nonces(signer);
        
        bytes32 domainSeparator = permitToken.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                signer,
                address(permitTokenBank),
                DEPOSIT_AMOUNT,
                nonce,
                deadline
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        // 执行签名存款
        vm.prank(signer);
        permitTokenBank.permitDeposit(
            DEPOSIT_AMOUNT,
            deadline,
            v,
            r,
            s
        );

        assertEq(permitTokenBank.balanceOf(signer), DEPOSIT_AMOUNT);
        assertEq(permitTokenBank.totalDeposits(), DEPOSIT_AMOUNT);
        assertEq(permitToken.balanceOf(address(permitTokenBank)), DEPOSIT_AMOUNT);
    }

    function test_Withdraw() public {
        // 先存款
        vm.startPrank(alice);
        permitToken.approve(address(permitTokenBank), DEPOSIT_AMOUNT);
        permitTokenBank.deposit(DEPOSIT_AMOUNT);
        
        // 提款
        permitTokenBank.withdraw(DEPOSIT_AMOUNT);
        vm.stopPrank();

        assertEq(permitTokenBank.balanceOf(alice), 0);
        assertEq(permitTokenBank.totalDeposits(), 0);
        assertEq(permitToken.balanceOf(alice), INITIAL_BALANCE);
    }

    function test_RevertWhen_PermitDepositWithExpiredDeadline() public {
        uint256 privateKey = 0xA11CE;
        address signer = vm.addr(privateKey);
        permitToken.mint(signer, INITIAL_BALANCE);

        // 设置过期的deadline
        uint256 deadline = block.timestamp - 1;
        uint256 nonce = permitToken.nonces(signer);
        
        bytes32 domainSeparator = permitToken.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                signer,
                address(permitTokenBank),
                DEPOSIT_AMOUNT,
                nonce,
                deadline
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        vm.prank(signer);
        vm.expectRevert("TokenBank: permit expired");
        permitTokenBank.permitDeposit(
            DEPOSIT_AMOUNT,
            deadline,
            v,
            r,
            s
        );
    }

    // function test_RevertWhen_DepositWithInsufficientAllowance() public {
    //     vm.startPrank(alice);
    //     vm.expectRevert("ERC20: insufficient allowance");
    //     permitTokenBank.deposit(DEPOSIT_AMOUNT);
    //     vm.stopPrank();
    // }

    function test_RevertWhen_WithdrawWithInsufficientBalance() public {
        vm.startPrank(alice);
        vm.expectRevert("TokenBankV2: insufficient balance");
        permitTokenBank.withdraw(DEPOSIT_AMOUNT);
        vm.stopPrank();
    }
}
