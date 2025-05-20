// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract PermitTokenBank is ReentrancyGuard {
    using Address for address;
    using EnumerableSet for EnumerableSet.AddressSet;

    address public immutable token_address;
    // 存储每个用户对每种代币的余额
    mapping(address => uint256) public _balances;

    // 存储总存款量
    uint256 public _totalDeposits;

    // 存储前 10 名存款用户的数据结构
    struct TopDepositor {
        address user;
        uint256 amount;
    }
    
    // 存储前 10 名存款用户
    TopDepositor[] private _topDepositors;
    uint256 private constant MAX_TOP_DEPOSITORS = 10;
    
    // 用于快速查找用户是否在前 10 名中
    mapping(address => uint256) private _userToIndex;

    // 事件定义
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event PermitDeposit(address indexed user, uint256 amount);
    event TopDepositorUpdated(address indexed user, uint256 amount);

    constructor(address token_address_) {
        token_address = token_address_;
    }

    function _updateTopDepositors(address user, uint256 amount) private {
        uint256 currentIndex = _userToIndex[user];
        
        // 如果用户已经在列表中
        if (currentIndex > 0) {
            // 更新用户余额
            _topDepositors[currentIndex - 1].amount = amount;
            
            // 如果余额变小，需要向下移动
            while (currentIndex < _topDepositors.length && 
                   _topDepositors[currentIndex - 1].amount < _topDepositors[currentIndex].amount) {
                // 交换位置
                TopDepositor memory temp = _topDepositors[currentIndex - 1];
                _topDepositors[currentIndex - 1] = _topDepositors[currentIndex];
                _topDepositors[currentIndex] = temp;
                
                // 更新索引映射
                _userToIndex[_topDepositors[currentIndex - 1].user] = currentIndex;
                _userToIndex[_topDepositors[currentIndex].user] = currentIndex + 1;
                
                currentIndex++;
            }
            
            // 如果余额变大，需要向上移动
            while (currentIndex > 1 && 
                   _topDepositors[currentIndex - 1].amount > _topDepositors[currentIndex - 2].amount) {
                // 交换位置
                TopDepositor memory temp = _topDepositors[currentIndex - 1];
                _topDepositors[currentIndex - 1] = _topDepositors[currentIndex - 2];
                _topDepositors[currentIndex - 2] = temp;
                
                // 更新索引映射
                _userToIndex[_topDepositors[currentIndex - 1].user] = currentIndex;
                _userToIndex[_topDepositors[currentIndex - 2].user] = currentIndex - 1;
                
                currentIndex--;
            }
            
            emit TopDepositorUpdated(user, amount);
            return;
        }
        
        // 如果列表未满，直接添加
        if (_topDepositors.length < MAX_TOP_DEPOSITORS) {
            _topDepositors.push(TopDepositor(user, amount));
            _userToIndex[user] = _topDepositors.length;
            emit TopDepositorUpdated(user, amount);
            return;
        }
        
        // 如果新金额大于最小金额，替换最小金额的用户
        if (amount > _topDepositors[_topDepositors.length - 1].amount) {
            // 移除最小金额用户的索引
            delete _userToIndex[_topDepositors[_topDepositors.length - 1].user];
            
            // 更新最小金额用户的信息
            _topDepositors[_topDepositors.length - 1] = TopDepositor(user, amount);
            _userToIndex[user] = _topDepositors.length;
            
            // 向上移动新添加的用户到正确位置
            uint256 newIndex = _topDepositors.length;
            while (newIndex > 1 && 
                   _topDepositors[newIndex - 1].amount > _topDepositors[newIndex - 2].amount) {
                // 交换位置
                TopDepositor memory temp = _topDepositors[newIndex - 1];
                _topDepositors[newIndex - 1] = _topDepositors[newIndex - 2];
                _topDepositors[newIndex - 2] = temp;
                
                // 更新索引映射
                _userToIndex[_topDepositors[newIndex - 1].user] = newIndex;
                _userToIndex[_topDepositors[newIndex - 2].user] = newIndex - 1;
                
                newIndex--;
            }
            
            emit TopDepositorUpdated(user, amount);
        }
    }

    function deposit(uint256 amount) public nonReentrant {
        require(amount > 0, "TokenBank: amount must be greater than 0");

        // 从用户地址转移代币到合约
        bool success = IERC20(token_address).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        require(success, "TokenBank: transfer failed");

        // 更新余额
        _balances[msg.sender] += amount;
        _totalDeposits += amount;
        
        // 更新前 10 名存款用户
        _updateTopDepositors(msg.sender, _balances[msg.sender]);

        emit Deposit(msg.sender, amount);
    }

    /**
     * @dev 使用 permit 进行存款，允许用户通过签名授权进行存款
     * @param amount 存款金额
     * @param deadline 签名过期时间
     * @param v 签名的 v 值
     * @param r 签名的 r 值
     * @param s 签名的 s 值
     */
    function permitDeposit(
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public nonReentrant {
        require(amount > 0, "TokenBank: amount must be greater than 0");
        require(deadline >= block.timestamp, "TokenBank: permit expired");

        // 调用代币合约的 permit 函数
        IERC20Permit(token_address).permit(
            msg.sender,
            address(this),
            amount,
            deadline,
            v,
            r,
            s
        );

        // 从用户地址转移代币到合约
        bool success = IERC20(token_address).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        require(success, "TokenBank: transfer failed");

        // 更新余额
        _balances[msg.sender] += amount;
        _totalDeposits += amount;
        
        // 更新前 10 名存款用户
        _updateTopDepositors(msg.sender, _balances[msg.sender]);

        emit PermitDeposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) public nonReentrant {
        require(amount > 0, "TokenBank: amount must be greater than 0");
        require(
            _balances[msg.sender] >= amount,
            "TokenBankV2: insufficient balance"
        );

        // 更新余额
        _balances[msg.sender] -= amount;
        _totalDeposits -= amount;
        
        // 更新前 10 名存款用户
        _updateTopDepositors(msg.sender, _balances[msg.sender]);

        // 转移代币回用户地址
        bool success = IERC20(token_address).transfer(msg.sender, amount);
        require(success, "TokenBank: transfer failed");

        emit Withdraw(msg.sender, amount);
    }

    function balanceOf(address user) public view returns (uint256) {
        return _balances[user];
    }

    /**
     * @dev 查询总存款量
     * @return 总存款量
     */
    function totalDeposits() public view returns (uint256) {
        return _totalDeposits;
    }

    // 获取前 10 名存款用户的数量
    function getTopDepositorsCount() public view returns (uint256) {
        return _topDepositors.length;
    }

    // 获取指定索引的存款用户信息
    function getTopDepositor(uint256 index) public view returns (address user, uint256 amount) {
        require(index < _topDepositors.length, "Index out of bounds");
        TopDepositor memory depositor = _topDepositors[index];
        return (depositor.user, depositor.amount);
    }
    // 获取前 10 名的存款用户
    function getTopDepositorWithNumber() public view returns (TopDepositor[] memory) {
        return _topDepositors;
    }

    // 获取指定用户的排名（如果在前 10 名中）
    function getDepositorRank(address user) public view returns (uint256) {
        uint256 index = _userToIndex[user];
        return index > 0 ? index : 0;
    }
}
