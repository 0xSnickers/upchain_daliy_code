import { ethers } from "hardhat";
// 3-交易机制演示
async function main() {
  const [deployer, user1, user2] = await ethers.getSigners();
  
  console.log("=== 🔄 Uniswap V2 交易演示 ===\n");
  
  // 部署合约
  const Factory = await ethers.getContractFactory("UniswapV2Factory");
  const factory = await Factory.deploy(deployer.address);
  
  const Token = await ethers.getContractFactory("MockERC20");
  const tokenA = await Token.deploy("Token A", "TKNA", 18);
  const tokenB = await Token.deploy("Token B", "TKNB", 18);
  
  // 铸造代币
  const amount = ethers.parseEther("10000");
  await tokenA.mint(user1.address, amount);
  await tokenB.mint(user1.address, amount);
  await tokenA.mint(user2.address, amount);
  await tokenB.mint(user2.address, amount);
  
  // 创建交易对
  await factory.createPair(tokenA.target, tokenB.target);
  const pairAddress = await factory.getPair(tokenA.target, tokenB.target);
  const pair = await ethers.getContractAt("UniswapV2Pair", pairAddress);
  
  // User1 添加初始流动性 (1000:1000)
  console.log("📊 User1 添加初始流动性: 1000 TKNA : 1000 TKNB");
  await tokenA.connect(user1).transfer(pairAddress, ethers.parseEther("1000"));
  await tokenB.connect(user1).transfer(pairAddress, ethers.parseEther("1000"));
  await pair.connect(user1).mint(user1.address);
  
  let reserves = await pair.getReserves();
  console.log(`初始储备量: ${ethers.formatEther(reserves[0])} TKNA, ${ethers.formatEther(reserves[1])} TKNB`);
  console.log(`初始价格: 1 TKNA = ${Number(ethers.formatEther(reserves[1])) / Number(ethers.formatEther(reserves[0]))} TKNB\n`);
  
  // User2 进行小额交易
  console.log("🔄 User2 用 10 TKNA 换 TKNB");
  const swapAmount = ethers.parseEther("10");
  
  // 计算预期输出 (简化版 AMM 公式)
  const reserveA = Number(ethers.formatEther(reserves[0]));
  const reserveB = Number(ethers.formatEther(reserves[1]));
  const amountIn = Number(ethers.formatEther(swapAmount));
  
  // 考虑 0.3% 手续费
  const amountInWithFee = amountIn * 997; // 99.7%
  const numerator = amountInWithFee * reserveB;
  const denominator = reserveA * 1000 + amountInWithFee;
  const amountOut = numerator / denominator;
  
  console.log(`预期输出: ${amountOut.toFixed(6)} TKNB`);
  
  // 执行交易
  await tokenA.connect(user2).transfer(pairAddress, swapAmount);
  await pair.connect(user2).swap(0, ethers.parseEther(amountOut.toString()), user2.address, "0x");
  
  // 检查交易后状态
  reserves = await pair.getReserves();
  const newReserveA = Number(ethers.formatEther(reserves[0]));
  const newReserveB = Number(ethers.formatEther(reserves[1]));
  
  console.log(`交易后储备量: ${newReserveA} TKNA, ${newReserveB} TKNB`);
  console.log(`新价格: 1 TKNA = ${newReserveB / newReserveA} TKNB`);
  console.log(`价格变化: ${((newReserveB / newReserveA) / (reserveB / reserveA) - 1) * 100}%\n`);
  
  // 大额交易演示
  console.log("🔄 User2 用 100 TKNA 换 TKNB (大额交易)");
  const bigSwapAmount = ethers.parseEther("100");
  
  // 重新计算
  const amountInBig = Number(ethers.formatEther(bigSwapAmount));
  const amountInWithFeeBig = amountInBig * 997;
  const numeratorBig = amountInWithFeeBig * newReserveB;
  const denominatorBig = newReserveA * 1000 + amountInWithFeeBig;
  const amountOutBig = numeratorBig / denominatorBig;
  
  console.log(`预期输出: ${amountOutBig.toFixed(6)} TKNB`);
  console.log(`滑点: ${((amountInBig / amountOutBig) / (newReserveA / newReserveB) - 1) * 100}%`);
  
  // 学习要点
  console.log("\n=== 🎓 交易机制学习要点 ===");
  console.log("✅ 恒定乘积公式: (x + Δx) * (y - Δy) = x * y");
  console.log("✅ 每笔交易收取 0.3% 手续费");
  console.log("✅ 大额交易会产生更大的滑点");
  console.log("✅ 价格由供需关系自动调节");
  console.log("✅ 套利者会平衡不同市场的价格差");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 