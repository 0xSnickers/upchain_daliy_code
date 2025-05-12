## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

---

MultipleSignture.sol
```
数据结构:
    Transaction 结构体：存储提案信息，包括目标地址、金额、数据、执行状态和确认数
    owners 数组：存储所有多签持有者地址
    isOwner 映射：快速检查地址是否为多签持有者
    threshold：签名门槛
    transactions 数组：存储所有提案
    confirmations 映射：记录每个提案的确认状态

主要功能:
    constructor: 初始化多签持有者和门槛
    submitTransaction: 提交新提案
    confirmTransaction: 确认提案
    executeTransaction: 执行提案
    getTransactionCount: 获取提案数量
    getOwnerCount: 获取多签持有者数量

安全特性:
    使用修饰器确保只有多签持有者可以提交和确认提案
    防止重复确认
    确保提案存在且未执行
    验证门槛设置的有效性
    防止重复执行提案

事件:
    TransactionSubmitted: 提案提交时触发
    TransactionConfirmed: 提案确认时触发
    TransactionExecuted: 提案执行时触发
    其他管理事件（添加/移除持有者、修改门槛等）

使用示例：
    部署合约时，需要提供多签持有者地址数组和门槛值
    多签持有者可以通过 submitTransaction 提交提案
    其他多签持有者通过 confirmTransaction 确认提案
    当确认数达到门槛时，任何人都可以调用 executeTransaction 执行提案
    合约还包含了 receive 函数，允许合约接收 ETH。
```