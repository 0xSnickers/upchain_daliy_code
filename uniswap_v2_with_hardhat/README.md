# Uniswap V2 项目目录结构说明

## 📁 项目概览
这是一个完整的 Uniswap V2 DEX (去中心化交易所) 学习项目，基于 Hardhat 框架构建。

```
Uniswap_V2/
├── 📁 contracts/                    # 智能合约目录
│   ├── 📄 UniswapV2Factory.sol      # 工厂合约 - 创建和管理交易对
│   ├── 📄 UniswapV2Pair.sol         # 交易对合约 - 管理流动性和交易
│   ├── 📄 UniswapV2ERC20.sol        # ERC20基础合约 - LP代币功能
│   ├── 📄 UniswapV2Router02.sol     # 路由合约 - 用户交互入口
│   ├── 📄 MockERC20.sol             # 测试代币合约 - 用于演示
│   │
│   ├── 📁 interfaces/               # 接口定义目录
│   │   ├── 📄 IERC20.sol           # ERC20标准接口
│   │   ├── 📄 IUniswapV2Factory.sol # 工厂合约接口
│   │   ├── 📄 IUniswapV2Pair.sol   # 交易对合约接口
│   │   └── 📄 IUniswapV2Callee.sol # 回调接口 - 闪电贷等功能
│   │
│   └── 📁 libraries/                # 工具库目录
│       ├── 📄 SafeMath.sol         # 安全数学库 (0.5.16版本)
│       ├── 📄 SafeMath6.sol        # 安全数学库 (0.6.6版本)
│       ├── 📄 UQ112x112.sol        # 固定点数学库 - 价格累积
│       ├── 📄 Math.sol             # 数学运算库 - 开方等功能
│       └── 📄 UniswapV2Library.sol # Uniswap工具库 - 地址计算等
│
├── 📁 scripts/                      # 脚本目录
│   ├── 📄 deploy.ts                # 部署脚本 - 部署所有合约
│   ├── 📄 interact.ts              # 交互演示 - 基础功能演示
│   ├── 📄 priceDemo.ts             # 价格机制演示 - AMM定价原理
│   ├── 📄 swapDemo.ts              # 交易演示 - swap功能演示
│   └── 📄 getInitCodeHash.ts       # 获取初始化代码哈希
│
├── 📁 test/                         # 测试目录
│   ├── 📄 UniswapV2.test.ts        # 主要功能测试
│   └── 📄 addLiquidity.test.ts     # 添加流动性测试
│
├── 📁 typechain-types/              # TypeScript类型定义 (自动生成)
├── 📁 artifacts/                    # 编译产物 (自动生成)
├── 📁 cache/                        # 编译缓存 (自动生成)
├── 📁 node_modules/                 # 依赖包 (自动生成)
│
├── 📄 hardhat.config.ts             # Hardhat配置文件
├── 📄 package.json                  # 项目依赖配置
├── 📄 package-lock.json             # 依赖锁定文件
├── 📄 tsconfig.json                 # TypeScript配置
├── 📄 .gitignore                    # Git忽略文件
└── 📄 README.md                     # 项目说明文档
```

## 🔧 核心合约说明

### 1. UniswapV2Factory.sol (工厂合约)
- **作用**: 创建和管理所有交易对
- **主要功能**:
  - `createPair()` - 创建新的交易对
  - `getPair()` - 获取交易对地址
  - `allPairs()` - 获取所有交易对列表
- **Solidity版本**: 0.5.16

### 2. UniswapV2Pair.sol (交易对合约)
- **作用**: 管理特定代币对的流动性和交易
- **主要功能**:
  - `mint()` - 铸造LP代币 (添加流动性)
  - `burn()` - 销毁LP代币 (移除流动性)
  - `swap()` - 执行代币交换
  - `getReserves()` - 获取储备量
- **Solidity版本**: 0.5.16

### 3. UniswapV2Router02.sol (路由合约)
- **作用**: 用户交互的主要入口，提供安全的交易接口
- **主要功能**:
  - `addLiquidity()` - 安全添加流动性
  - `removeLiquidity()` - 安全移除流动性
  - `swapExactTokensForTokens()` - 精确输入交换
  - `swapTokensForExactTokens()` - 精确输出交换
- **Solidity版本**: 0.6.6

### 4. MockERC20.sol (测试代币)
- **作用**: 用于测试的ERC20代币
- **主要功能**:
  - `mint()` - 铸造代币 (仅测试用)
  - 标准ERC20功能 (transfer, approve等)
- **Solidity版本**: 0.6.6

## 📚 工具库说明

### SafeMath.sol / SafeMath6.sol
- **作用**: 防止整数溢出的安全数学运算
- **区别**: 分别适配0.5.16和0.6.6版本

### UQ112x112.sol
- **作用**: 固定点数学库，用于价格累积计算
- **精度**: 112位小数精度

### Math.sol
- **作用**: 基础数学运算
- **功能**: 最小值比较、平方根计算

### UniswapV2Library.sol
- **作用**: Uniswap专用工具函数
- **功能**: 地址计算、储备量查询、价格计算

## 🎯 脚本功能说明

### 1. interact.ts - 基础交互演示
```bash
npx hardhat run scripts/interact.ts
```
- 演示完整的DEX使用流程
- 部署合约 → 铸造代币 → 添加流动性 → 查看结果

### 2. priceDemo.ts - 价格机制演示
```bash
npx hardhat run scripts/priceDemo.ts
```
- 演示AMM自动做市商定价原理
- 展示Router的流动性保护机制
- 理解恒定乘积公式 x * y = k

### 3. swapDemo.ts - 交易演示
```bash
npx hardhat run scripts/swapDemo.ts
```
- 演示代币交换功能
- 展示滑点和价格影响
- 理解手续费机制

### 4. deploy.ts - 部署脚本
```bash
npx hardhat run scripts/deploy.ts
```
- 部署所有核心合约
- 输出合约地址用于后续交互

## 🧪 测试说明

### 运行所有测试
```bash
npx hardhat test
```

### 测试覆盖
- ✅ 交易对创建
- ✅ 流动性添加
- ✅ 基本交易功能
- ✅ 错误处理

## 🔄 开发工作流

### 1. 安装依赖
```bash
npm install
```

### 2. 编译合约
```bash
npx hardhat compile
```

### 3. 运行测试
```bash
npx hardhat test
```

### 4. 运行演示
```bash
npx hardhat run scripts/interact.ts
npx hardhat run scripts/priceDemo.ts
```

### 5. 启动本地网络
```bash
npx hardhat node
```

## 📖 学习路径建议

1. **第一步**: 运行 `interact.ts` 理解基本流程
2. **第二步**: 运行 `priceDemo.ts` 理解定价机制
3. **第三步**: 阅读合约代码，理解实现细节
4. **第四步**: 修改参数，观察结果变化
5. **第五步**: 尝试添加新功能

## 🎓 核心概念

- **AMM (自动做市商)**: 通过算法自动提供流动性
- **恒定乘积公式**: x * y = k，确保价格平衡
- **LP代币**: 流动性提供者代币，代表池子份额
- **滑点**: 大额交易对价格的影响
- **套利**: 利用价格差异获利的机制

## 🚀 扩展方向

- 添加更多Router功能 (removeLiquidity, swap等)
- 实现闪电贷功能
- 集成价格预言机
- 优化gas使用
- 部署到测试网

---

这个项目为学习DeFi和AMM机制提供了完整的实践环境！🎯 