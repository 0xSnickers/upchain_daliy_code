import { ethers } from "hardhat";
// 1-交互 UniswapV2Factory 和 UniswapV2Router02 合约
async function main() {
  const [deployer, user1, user2] = await ethers.getSigners();
  
  console.log("=== Uniswap V2 学习演示 ===\n");
  
  // 1. 部署合约
  console.log("1. 部署合约...");
  const Factory = await ethers.getContractFactory("UniswapV2Factory");
  const factory = await Factory.deploy(deployer.address);
  
  const Router = await ethers.getContractFactory("UniswapV2Router02");
  const router = await Router.deploy(factory.target, ethers.ZeroAddress);
  
  const Token = await ethers.getContractFactory("MockERC20");
  const tokenA = await Token.deploy("Token A", "TKNA", 18);
  const tokenB = await Token.deploy("Token B", "TKNB", 18);
  
  console.log(`Factory: ${factory.target}`);
  console.log(`Router: ${router.target}`);
  console.log(`Token A: ${tokenA.target}`);
  console.log(`Token B: ${tokenB.target}\n`);
  
  // 2. 铸造代币
  console.log("2. 铸造代币...");
  const amount = ethers.parseEther("10000");
  await tokenA.mint(user1.address, amount);
  await tokenB.mint(user1.address, amount);
  
  console.log(`User1 Token A 余额: ${ethers.formatEther(await tokenA.balanceOf(user1.address))}`);
  console.log(`User1 Token B 余额: ${ethers.formatEther(await tokenB.balanceOf(user1.address))}\n`);
  
  // 3. 授权 Router
  console.log("3. 授权 Router...");
  await tokenA.connect(user1).approve(router.target, amount);
  await tokenB.connect(user1).approve(router.target, amount);
  console.log("授权完成\n");
  
  // 4. 添加流动性
  console.log("4. 添加流动性...");
  const liquidityAmount = ethers.parseEther("1000");
  const deadline = Math.floor(Date.now() / 1000) + 3600;
  
  const tx = await router.connect(user1).addLiquidity(
    tokenA.target,
    tokenB.target,
    liquidityAmount,
    liquidityAmount,
    liquidityAmount,
    liquidityAmount,
    user1.address,
    deadline
  );
  
  const receipt = await tx.wait();
  console.log(`添加流动性交易哈希: ${receipt?.hash}`);
  
  // 5. 检查交易对
  const pairAddress = await factory.getPair(tokenA.target, tokenB.target);
  const pair = await ethers.getContractAt("IUniswapV2Pair", pairAddress);
  
  console.log(`交易对地址: ${pairAddress}`);
  console.log(`User1 LP 代币余额: ${ethers.formatEther(await pair.balanceOf(user1.address))}`);
  
  const reserves = await pair.getReserves();
  console.log(`储备量 - Token A: ${ethers.formatEther(reserves[0])}`);
  console.log(`储备量 - Token B: ${ethers.formatEther(reserves[1])}\n`);
  
  // 6. 显示学习要点
  console.log("=== 🎓 学习要点 ===");
  console.log("✅ Factory 创建了交易对");
  console.log("✅ Router 帮助用户安全地添加流动性");
  console.log("✅ LP 代币代表你在池子中的份额");
  console.log("✅ 储备量决定了代币的相对价格");
  console.log("✅ 恒定乘积公式: x * y = k");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 