// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MultiSigntureWallet{
    // 提案结构体
    struct Transaction {
        address to; // 目标地址
        uint256 value; // 转账金额
        bytes data; // 调用数据 (格式：0x54657374)
        bool executed; // 是否已执行
        uint256 confirmations; // 确认数量
    }

    // 状态变量
    address[] public owners; // 多签持有者列表
    mapping(address => bool) public isOwner; // 地址是否为多签持有者
    uint256 public threshold; // 签名门槛 (提案需要多少个持有者通过)
    Transaction[] public transactions; // 所有提案列表
    // txId => 多签持有者地址 => 是否已确认提案状态
    mapping(uint256 => mapping(address => bool)) public confirmations; // 每个提案的确认状态

    // 提交提案触发的事件
    event TransactionSubmitted(uint256 indexed txId, address indexed sender, address to, uint256 value, bytes data);
    // 确认提案触发的事件
    event TransactionConfirmed(uint256 indexed txId, address indexed owner);
    // 执行提案触发的事件
    event TransactionExecuted(uint256 indexed txId, address indexed executor);

    // 必须是多签持有者
    modifier _onlyOwner(){
        require(isOwner[msg.sender], "Not an owner");
        _;
    }
    // 提案必须存在和未执行
    modifier _txExists(uint256 txId){
        require(txId < transactions.length, "Transaction does not exist");
        // 提案未执行
        require(!transactions[txId].executed, "Transaction already executed");
        _;
    }
    // 提案未被当前地址确认
    modifier _notConfirmed(uint256 txId){
        // 提案状态=true：当前持有者已确认提案，抛出异常
        require(!confirmations[txId][msg.sender], "Transaction already confirmed");
        _;
    }
    constructor(address[] memory _owners, uint256 _threshold) {
        // 限制 owner 数量
        require(
            _owners.length > 0 && _owners.length < 10,
            "Owner must > 0 or < 10"
        );
        // 校验签名门槛
        require(
            _threshold > 0 && _owners.length >= _threshold,
            "Invalid threshold"
        );
        // 初始化多签持有者列表
        for (uint256 i; i < _owners.length; i++) {
            require(_owners[i] != address(0), "Invalid owner");
            require(!isOwner[_owners[i]], "Owner not unique");
            isOwner[_owners[i]] = true;
            owners.push(_owners[i]);
        }
        threshold = _threshold;

    }
  
    // * @desc 提交提案（只有签名持有者可以调用）
    // * @param _to 目标地址
    // * @param _value 转账金额
    // * @param _data 调用数据
    // * @return txId 提案Id
    function submitTransaction(address _to, uint256 _value, bytes memory _data) public _onlyOwner returns(uint256 txId){
        // 返回提案ID
        txId = transactions.length;
        // 添加提案到提案列表
        transactions.push(Transaction({
          to: _to, // 目标地址
          value: _value, // 转账金额
          data: _data, // 调用数据
          executed: false,// 是否已执行
          confirmations: 0 // 确认数量
        }));
        emit TransactionSubmitted(txId, msg.sender, _to, _value, _data);
    }
    // * @desc 确认提案（只有 签名持有者+提案必须存在和未执行+提案未被当前地址确认 才可以调用）
    // * @param _txId 提案Id
    function confirmTransaction(uint256 _txId) public _onlyOwner _txExists(_txId) _notConfirmed(_txId){
        // 更新提案列表确认数量
        transactions[_txId].confirmations += 1;
        // 更新每个提案列表里的确认状态
        confirmations[_txId][msg.sender] = true;
        emit TransactionConfirmed(_txId, msg.sender);
    }

    // * @desc 执行提案（提案已通过，只要提案ID存在，谁都可以去执行）
    // * @param _txId 提案Id
    function executeTransaction(uint256 _txId) public _txExists(_txId){
        Transaction storage _transaction = transactions[_txId];
        // 校验持有者通过数量
        require(_transaction.confirmations >= threshold, "Threshold not reached");
        // 提案是否已被执行
        require(!_transaction.executed, "Transaction already executed");
        _transaction.executed = true;

        // 通过 call 与其他合约交互并把 data 带过去
        (bool success, ) = _transaction.to.call{value: _transaction.value}(_transaction.data);
        // call 调用失败（如：当前多签合约余额不足导致转账失败）
        require(success, "Transaction execution failed");
        emit TransactionExecuted(_txId, msg.sender);
    }
     // 获取提案数量
    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }

    // 获取多签持有者数量
    function getOwnerCount() public view returns (uint256) {
        return owners.length;
    }
   
    // 接收ETH
    receive() external payable {
    }
    fallback() external payable { }
}
