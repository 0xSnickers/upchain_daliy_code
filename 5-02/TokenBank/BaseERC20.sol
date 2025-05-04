// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
interface IBaseERC20 {
    function transfer(
        address _to,
        uint256 _value
    ) external returns (bool success);

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool success);

    function balanceOf(address _owner) external view returns (uint256 balance);

    function approve(
        address _owner,
        address _spender,
        uint256 _value
    ) external returns (bool success);

    function allowance(
        address _owner,
        address _spender
    ) external view returns (uint256 remaining);
}

contract BaseERC20 {
    string public name; // 币种全名称
    string public symbol; // 币种符号
    uint8 public decimals; // 小数位

    uint256 public totalSupply; // 代币总量

    // 存储各个地址拥有symbol的 Token 余额
    mapping(address => uint256) balances;

    // allowances: 某个地址（授权人）允许另一个地址（被授权人）最多可以花费他多少代币
    // 1. 第一层 address：授权人（token 持有者）
    // 2. 第二层 address：被授权人（spender）
    // 3. uint256：最大可被转走的额度
    mapping(address => mapping(address => uint256)) allowances;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        // write your code here
        // set name,symbol,decimals,totalSupply
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply = 100_000_000 * (10 ** uint256(decimals));

        balances[msg.sender] = totalSupply;
    }

    // 5.允许任何人查看任何地址的 Token 余额（balanceOf）
    function balanceOf(address _owner) external view returns (uint256 balance) {
        // write your code here
        return balances[_owner];
    }

    // 6.允许 Token 的所有者将他们的 Token 发送给任何人（transfer）；
    //   转帐超出余额时抛出异常(require),并显示错误消息 “ERC20: transfer amount exceeds balance”。
    function transfer(
        address _to,
        uint256 _value
    ) external returns (bool success) {
        // write your code here
        require(
            balances[msg.sender] >= _value,
            "ERC20: transfer amount exceeds balance"
        );

        balances[msg.sender] -= _value;

        balances[_to] += _value;

        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    // 7. 允许 Token 的所有者批准某个地址消费他们的一部分Token（approve）
    function approve(
        address _owner,
        address _spender,
        uint256 _value
    ) external returns (bool success) {
        // write your code here
        allowances[_owner][_spender] = _value;
        emit Approval(_owner, _spender, _value);
        return true;
    }
    // 8.允许任何人查看一个地址可以从其它账户中转账的代币数量（allowance）
    function allowance(
        address _owner,
        address _spender
    ) external view returns (uint256 remaining) {
        // write your code here
        return allowances[_owner][_spender];
    }

    // 9.允许被授权的地址消费他们被授权的 Token 数量（transferFrom）；
    // 10.转帐超出余额时抛出异常(require)，异常信息：“ERC20: transfer amount exceeds balance”
    // 11.转帐超出授权数量时抛出异常(require)，异常消息：“ERC20: transfer amount exceeds allowance”。
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool success) {
        // write your code here
        require(
            _value <= balances[_from],
            "ERC20: transfer amount exceeds balance"
        );
        require(
            _value <= allowances[_from][_to],
            "ERC20: transfer amount exceeds allowance"
        );

        balances[_from] -= _value; // 1. 发送者Token减少
        balances[_to] += _value; // 2. 接受者Token增加
        allowances[_from][msg.sender] -= _value; // 3. 同时减掉授权金额

        emit Transfer(_from, _to, _value);
        return true;
    }
}
