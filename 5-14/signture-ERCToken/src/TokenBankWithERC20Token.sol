// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ISignatureTransfer} from "./ISignatureTransfer.sol";

// 支持存取款任意ERC20代币
contract TokenBankWithERC20Token is ReentrancyGuard {
    using Address for address;
    ISignatureTransfer public immutable permit2;

    // 存储每个用户对每种代币的余额
    mapping(address => mapping(address => uint256)) public _balances;

    // 存储每种代币的总存款量
    mapping(address => uint256) public _totalDeposits;

    // 事件定义
    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdraw(address indexed user, address indexed token, uint256 amount);
    event PermitDeposit(address indexed user, address indexed token, uint256 amount);

    constructor(address permit2_contract_address) {
        permit2 = ISignatureTransfer(permit2_contract_address); 
    }

    function depositWithPermit2(
        ISignatureTransfer.PermitTransferFrom memory permit,
        ISignatureTransfer.SignatureTransferDetails memory transferDetails,
        bytes calldata signature
    ) external nonReentrant {
        require(transferDetails.to == address(this), "TokenBank: invalid recipient");
        require(transferDetails.requestedAmount > 0, "TokenBank: amount must be greater than 0");
        address token = permit.permitted.token;
        require(token != address(0), "TokenBank: invalid token");

        // Transfer tokens using Permit2
        permit2.permitTransferFrom(permit, transferDetails, msg.sender, signature);

        // Update balances
        _balances[msg.sender][token] += transferDetails.requestedAmount;
        _totalDeposits[token] += transferDetails.requestedAmount;

        emit Deposit(msg.sender, token, transferDetails.requestedAmount);
    }

    // 正常情况下，存款需要Approve + 调用transferFrom
    function deposit(address token, uint256 amount) public nonReentrant {
        require(token != address(0), "TokenBank: invalid token");
        require(amount > 0, "TokenBank: amount must be greater than 0");

        // 从用户地址转移代币到合约
        bool success = IERC20(token).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        require(success, "TokenBank: transfer failed");

        // 更新余额
        _balances[msg.sender][token] += amount;
        _totalDeposits[token] += amount;

        emit Deposit(msg.sender, token, amount);
    }

    /**
     * @dev 使用 permit 进行存款，允许用户通过签名授权进行存款
     * @param token 代币地址
     * @param amount 存款金额
     * @param deadline 签名过期时间
     * @param v 签名的 v 值
     * @param r 签名的 r 值
     * @param s 签名的 s 值
     */
    function permitDeposit(
        address token,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public nonReentrant {
        require(token != address(0), "TokenBank: invalid token");
        require(amount > 0, "TokenBank: amount must be greater than 0");
        require(deadline >= block.timestamp, "TokenBank: permit expired");

        // 调用代币合约的 permit 函数
        IERC20Permit(token).permit(
            msg.sender,
            address(this),
            amount,
            deadline,
            v,
            r,
            s
        );

        // 从用户地址转移代币到合约
        bool success = IERC20(token).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        require(success, "TokenBank: transfer failed");

        // 更新余额
        _balances[msg.sender][token] += amount;
        _totalDeposits[token] += amount;

        emit PermitDeposit(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount) public nonReentrant {
        require(token != address(0), "TokenBank: invalid token");
        require(amount > 0, "TokenBank: amount must be greater than 0");
        require(
            _balances[msg.sender][token] >= amount,
            "TokenBank: insufficient balance"
        );

        // 更新余额
        _balances[msg.sender][token] -= amount;
        _totalDeposits[token] -= amount;

        // 转移代币回用户地址
        bool success = IERC20(token).transfer(msg.sender, amount);
        require(success, "TokenBank: transfer failed");

        emit Withdraw(msg.sender, token, amount);
    }

    function balanceOf(address user, address token) public view returns (uint256) {
        return _balances[user][token];
    }

    /**
     * @dev 查询指定代币的总存款量
     * @param token 代币地址
     * @return 总存款量
     */
    function totalDeposits(address token) public view returns (uint256) {
        return _totalDeposits[token];
    }
}
