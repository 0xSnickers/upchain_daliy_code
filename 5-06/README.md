
> ./TokenBankV2 

扩展 ERC20 合约 ，添加一个有hook 功能的转账函数，如函数名为：transferWithCallback ，在转账时，如果目标地址是合约地址的话，调用目标地址的 tokensReceived() 方法。

继承 TokenBank 编写 TokenBankV2，支持存入扩展的 ERC20 Token，用户可以直接调用 transferWithCallback 将 扩展的 ERC20 Token 存入到 TokenBankV2 中。

（备注：TokenBankV2 需要实现 tokensReceived 来实现存款记录工作）

---

> ./BaseERC721 

编写 ERC721 NFT 合约
  
介绍
ERC721 标准代表了非同质化代币（NFT），它为独一无二的资产提供链上表示。从数字艺术品到虚拟产权，NFT的概念正迅速被世界认可。了解并能够实现 ERC721 标准对区块链开发者至关重要。通过这个挑战，你不仅可以熟悉 Solidity 编程，而且可以了解 ERC721 合约的工作原理。

目标
你的任务是创建一个遵循 ERC721 标准的智能合约，该合约能够用于在以太坊区块链上铸造与交易 NFT。

相关资源
为了帮助完成这项挑战，以下资源可能会有用：
• EIP-721标准
• OpenZeppelin ERC721智能合约库

注意
在编写合约时，需要遵循 ERC721 标准，此外也需要考虑到安全性，确保转账和授权功能在任何时候都能正常运行无误。
代码模板中已包含基础框架，只需要在标记为 /**code*/ 的地方编写你的代码。不要去修改已有内容！
提交前需确保通过所有相关的测试用例


---



编写一个简单的 NFTMarket 合约，使用自己发行的ERC20 扩展 Token 来买卖 NFT， NFTMarket 的函数有：

list() : 实现上架功能，NFT 持有者可以设定一个价格（需要多少个 Token 购买该 NFT）并上架 NFT 到 NFTMarket，上架之后，其他人才可以购买。

buyNFT() : 普通的购买 NFT 功能，用户转入所定价的 token 数量，获得对应的 NFT。

实现ERC20 扩展 Token 所要求的接收者方法 tokensReceived  ，在 tokensReceived 中实现NFT 购买功能(注意扩展的转账需要添加一个额外数据参数)。

贴出你代码库链接。

---

