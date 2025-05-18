// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Test, console} from "forge-std/Test.sol";

import "../src/TokenBankWithERC20Token.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ISignatureTransfer} from "../src/ISignatureTransfer.sol";

// 测试用的 ERC20 代币合约
contract TestToken is ERC20 {
    constructor() ERC20("Test Token", "TEST") {
        _mint(msg.sender, 1000000 * 10**decimals());
    }
}

// 测试用的支持 Permit 的 ERC20 代币合约
contract TestPermitToken is ERC20Permit {
    constructor() ERC20Permit("Test Permit Token") ERC20("Test Permit Token", "TPT") {
        _mint(msg.sender, 1000000 * 10**decimals());
    }
}

// 模拟 Permit2 合约
contract MockPermit2 is ISignatureTransfer {
    mapping(address => mapping(address => uint256)) public allowances;
    mapping(address => mapping(uint256 => uint256)) private _nonceBitmap;
    
    function permitTransferFrom(
        ISignatureTransfer.PermitTransferFrom memory _permit,
        ISignatureTransfer.SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external {
        // 简化实现，直接转移代币
        IERC20(_permit.permitted.token).transferFrom(
            owner,
            transferDetails.to,
            transferDetails.requestedAmount
        );
    }

    function permitTransferFrom(
        ISignatureTransfer.PermitBatchTransferFrom memory _permit,
        ISignatureTransfer.SignatureTransferDetails[] calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external {
        for (uint256 i = 0; i < transferDetails.length; i++) {
            IERC20(_permit.permitted[i].token).transferFrom(
                owner,
                transferDetails[i].to,
                transferDetails[i].requestedAmount
            );
        }
    }

    function permitWitnessTransferFrom(
        ISignatureTransfer.PermitTransferFrom memory _permit,
        ISignatureTransfer.SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes32 witness,
        string calldata witnessTypeString,
        bytes calldata signature
    ) external {
        // 简化实现
        IERC20(_permit.permitted.token).transferFrom(
            owner,
            transferDetails.to,
            transferDetails.requestedAmount
        );
    }

    function permitWitnessTransferFrom(
        ISignatureTransfer.PermitBatchTransferFrom memory _permit,
        ISignatureTransfer.SignatureTransferDetails[] calldata transferDetails,
        address owner,
        bytes32 witness,
        string calldata witnessTypeString,
        bytes calldata signature
    ) external {
        // 简化实现
        for (uint256 i = 0; i < transferDetails.length; i++) {
            IERC20(_permit.permitted[i].token).transferFrom(
                owner,
                transferDetails[i].to,
                transferDetails[i].requestedAmount
            );
        }
    }

    function invalidateUnorderedNonces(uint256 wordPos, uint256 mask) external {
        // 简化实现
        _nonceBitmap[msg.sender][wordPos] |= mask;
    }

    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256("Permit2"),
            keccak256("1"),
            block.chainid,
            address(this)
        ));
    }

    function nonceBitmap(address owner, uint256 wordPos) external view returns (uint256) {
        return _nonceBitmap[owner][wordPos];
    }
}

contract TokenBankWithERC20TokenTest is Test {
    TokenBankWithERC20Token public tokenBank;
    TestToken public testToken;
    TestPermitToken public permitToken;
    MockPermit2 public permit2;
    
    // 使用 Foundry 的第一个测试账户
    address public alice = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
    address public bob = address(0x2);
    uint256 public constant INITIAL_BALANCE = 1000 * 10**18;
    
    function setUp() public {
        // 部署合约
        permit2 = new MockPermit2();
        tokenBank = new TokenBankWithERC20Token(address(permit2));
        testToken = new TestToken();
        permitToken = new TestPermitToken();
        
        // 给测试账户转账
        testToken.transfer(alice, INITIAL_BALANCE);
        testToken.transfer(bob, INITIAL_BALANCE);
        permitToken.transfer(alice, INITIAL_BALANCE);
        permitToken.transfer(bob, INITIAL_BALANCE);
    }
    
    function test_Deposit() public {
        uint256 amount = 100 * 10**18;
        
        // Alice 授权 TokenBank 使用她的代币
        vm.startPrank(alice);
        testToken.approve(address(tokenBank), amount);
        
        // Alice 存款
        tokenBank.deposit(address(testToken), amount);
        vm.stopPrank();
        
        // 验证余额
        assertEq(tokenBank.balanceOf(alice, address(testToken)), amount);
        assertEq(tokenBank.totalDeposits(address(testToken)), amount);
        assertEq(testToken.balanceOf(address(tokenBank)), amount);
    }
    
    function test_Withdraw() public {
        uint256 amount = 100 * 10**18;
        
        // 先存款
        vm.startPrank(alice);
        testToken.approve(address(tokenBank), amount);
        tokenBank.deposit(address(testToken), amount);
        
        // 再提款
        tokenBank.withdraw(address(testToken), amount);
        vm.stopPrank();
        
        // 验证余额
        assertEq(tokenBank.balanceOf(alice, address(testToken)), 0);
        assertEq(tokenBank.totalDeposits(address(testToken)), 0);
        assertEq(testToken.balanceOf(alice), INITIAL_BALANCE);
    }
    
    function test_PermitDeposit() public {
        uint256 amount = 100 * 10**18;
        uint256 deadline = block.timestamp + 1 hours;
        
        // 生成 permit 签名
        (uint8 v, bytes32 r, bytes32 s) = _getPermitSignature(
            permitToken,
            alice,
            address(tokenBank),
            amount,
            deadline
        );
        
        // 使用 permit 存款
        vm.prank(alice);
        tokenBank.permitDeposit(
            address(permitToken),
            amount,
            deadline,
            v,
            r,
            s
        );
        
        // 验证余额
        assertEq(tokenBank.balanceOf(alice, address(permitToken)), amount);
        assertEq(tokenBank.totalDeposits(address(permitToken)), amount);
        assertEq(permitToken.balanceOf(address(tokenBank)), amount);
    }
    
    function test_DepositWithPermit2() public {
        uint256 amount = 100 * 10**18;
        
        // 准备 Permit2 参数
        ISignatureTransfer.PermitTransferFrom memory _permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({
                token: address(testToken),
                amount: amount
            }),
            nonce: 0,
            deadline: block.timestamp + 1 hours
        });
        
        ISignatureTransfer.SignatureTransferDetails memory transferDetails = ISignatureTransfer.SignatureTransferDetails({
            to: address(tokenBank),
            requestedAmount: amount
        });
        
        // 模拟签名
        bytes memory signature = abi.encodePacked(bytes32(0), bytes32(0), uint8(0));
        // 授权
        vm.startPrank(alice);
        testToken.approve(address(permit2), amount);
        
        // 使用 Permit2 存款
        tokenBank.depositWithPermit2(_permit, transferDetails, signature);
        vm.stopPrank();
        
        // 验证余额
        assertEq(tokenBank.balanceOf(alice, address(testToken)), amount);
        assertEq(tokenBank.totalDeposits(address(testToken)), amount);
        assertEq(testToken.balanceOf(address(tokenBank)), amount);
    }
    
    function test_RevertWhen_WithdrawInsufficientBalance() public {
        uint256 amount = 100 * 10**18;
        
        vm.expectRevert("TokenBank: insufficient balance");
        vm.prank(alice);
        tokenBank.withdraw(address(testToken), amount);
    }
    
    function test_RevertWhen_DepositZeroAmount() public {
        vm.startPrank(alice);
        testToken.approve(address(tokenBank), 100 * 10**18);
        
        vm.expectRevert("TokenBank: amount must be greater than 0");
        tokenBank.deposit(address(testToken), 0);
        vm.stopPrank();
    }
    
    // 辅助函数：生成 permit 签名
    function _getPermitSignature(
        TestPermitToken token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline
    ) internal returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                spender,
                value,
                token.nonces(owner),
                deadline
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        
        // 使用 alice 的私钥生成签名
        (v, r, s) = vm.sign(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80, digest);
    }
}
