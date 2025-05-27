// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "src/Vesting.sol";

contract ERC20Mock {
    string public name = "MockToken";
    string public symbol = "MTK";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "balance");
        require(allowance[from][msg.sender] >= amount, "allowance");
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }
}

contract VestingTest is Test {
    Vesting public vesting;
    ERC20Mock public token;
    address public beneficiary = address(0xBEEF);
    uint256 public constant TOTAL = 1_000_000 ether;
    uint256 public constant CLIFF = 365 days; // 12个月
    uint256 public constant DURATION = 730 days; // 24个月
    uint256 public constant MONTH = 30 days;

    function setUp() public {
        token = new ERC20Mock();
        token.mint(address(this), TOTAL);
        vesting = new Vesting(beneficiary, address(token), CLIFF, DURATION, TOTAL);
        token.transfer(address(vesting), TOTAL);
    }
    // 测试在锁仓期前无法释放
    function testCannotReleaseBeforeCliff() public {
        vm.warp(block.timestamp + CLIFF - 1);
        vm.prank(beneficiary);
        vm.expectRevert("No tokens to release");
        vesting.release();
    }
    // 测试在锁仓期后可以释放
    function testReleaseAfterCliff() public {
        vm.warp(block.timestamp + CLIFF + MONTH);
        vm.prank(beneficiary);
        vesting.release();
        // 第一个月可领取 1/24
        uint256 expected = TOTAL / 24;
        assertEq(token.balanceOf(beneficiary), expected);
    }
    // 测试线性释放
    function testLinearReleaseEachMonth() public {
        uint256 lastBalance = 0;
        uint256 expectedMonthly = TOTAL / 24;
        
        // 先等待 cliff 期结束
        vm.warp(block.timestamp + CLIFF);
        
        for (uint256 i = 1; i <= 24; i++) {
            // 每次前进一个月
            vm.warp(block.timestamp + MONTH);
            vm.prank(beneficiary);
            vesting.release();
            
            uint256 currentBalance = token.balanceOf(beneficiary);
            uint256 monthlyRelease = currentBalance - lastBalance;
            
            // 验证每月释放量是否正确（允许1个wei的误差）
            assertApproxEqAbs(monthlyRelease, expectedMonthly, 1, "Monthly release amount incorrect");
            lastBalance = currentBalance;
        }
        
        // 验证最终释放总量是否正确
        assertEq(token.balanceOf(beneficiary), TOTAL, "Total release amount incorrect");
    }
    // 测试在锁仓期结束后可以释放所有
    function testReleaseAllAfterDuration() public {
        vm.warp(block.timestamp + CLIFF + DURATION);
        vm.prank(beneficiary);
        vesting.release();
        assertEq(token.balanceOf(beneficiary), TOTAL);
    }
} 