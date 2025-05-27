import { ethers } from "hardhat";
// 2-价格机制演示
async function main() {
  const [deployer, user1] = await ethers.getSigners();
  
  console.log("=== 🎯 AMM 价格机制演示 ===\n");
  
  // 部署合约
  const Factory = await ethers.getContractFactory("UniswapV2Factory");
  const factory = await Factory.deploy(deployer.address);
  
  const Router = await ethers.getContractFactory("UniswapV2Router02");
  const router = await Router.deploy(factory.target, ethers.ZeroAddress);
  
  const Token = await ethers.getContractFactory("MockERC20");
  const tokenA = await Token.deploy("Token A", "TKNA", 18);
  const tokenB = await Token.deploy("Token B", "TKNB", 18);
  
  // 铸造和授权
  const amount = ethers.parseEther("10000");
  await tokenA.mint(user1.address, amount);
  await tokenB.mint(user1.address, amount);
  await tokenA.connect(user1).approve(router.target, amount);
  await tokenB.connect(user1).approve(router.target, amount);
  
  const deadline = Math.floor(Date.now() / 1000) + 3600;
  
  // 场景1：1:1 比例添加流动性
  console.log("📊 场景1：添加 1000 TKNA : 1000 TKNB");
  await router.connect(user1).addLiquidity(
    tokenA.target,
    tokenB.target,
    ethers.parseEther("1000"),
    ethers.parseEther("1000"),
    ethers.parseEther("1000"),
    ethers.parseEther("1000"),
    user1.address,
    deadline
  );
  
  const pairAddress = await factory.getPair(tokenA.target, tokenB.target);
  const pair = await ethers.getContractAt("IUniswapV2Pair", pairAddress);
  
  let reserves = await pair.getReserves();
  let reserveA = ethers.formatEther(reserves[0]);
  let reserveB = ethers.formatEther(reserves[1]);
  
  console.log(`储备量: ${reserveA} TKNA, ${reserveB} TKNB`);
  console.log(`价格: 1 TKNA = ${Number(reserveB) / Number(reserveA)} TKNB`);
  console.log(`价格: 1 TKNB = ${Number(reserveA) / Number(reserveB)} TKNA`);
  console.log(`恒定乘积 K = ${Number(reserveA) * Number(reserveB)}\n`);
  
  // 场景2：按当前比例添加流动性
  console.log("📊 场景2：按当前比例添加 500 TKNA : 500 TKNB");
  await router.connect(user1).addLiquidity(
    tokenA.target,
    tokenB.target,
    ethers.parseEther("500"),
    ethers.parseEther("500"),
    ethers.parseEther("400"),
    ethers.parseEther("400"),
    user1.address,
    deadline
  );
  
  reserves = await pair.getReserves();
  reserveA = ethers.formatEther(reserves[0]);
  reserveB = ethers.formatEther(reserves[1]);
  
  console.log(`储备量: ${reserveA} TKNA, ${reserveB} TKNB`);
  console.log(`价格: 1 TKNA = ${Number(reserveB) / Number(reserveA)} TKNB`);
  console.log(`价格: 1 TKNB = ${Number(reserveA) / Number(reserveB)} TKNA`);
  console.log(`恒定乘积 K = ${Number(reserveA) * Number(reserveB)}\n`);
  
  // 场景3：演示为什么不能不平衡添加
  console.log("📊 场景3：尝试不平衡添加 (会失败)");
  console.log("当前比例是 1:1，如果我们想添加 100 TKNA : 200 TKNB...");
  console.log("Router 会计算：");
  console.log("- 按 100 TKNA 计算，需要 100 TKNB");
  console.log("- 按 200 TKNB 计算，需要 200 TKNA");
  console.log("- Router 选择较小的组合：100 TKNA : 100 TKNB");
  console.log("- 多余的 100 TKNB 会退还给用户\n");
  
  // 实际演示
  const balanceBefore = await tokenB.balanceOf(user1.address);
  await router.connect(user1).addLiquidity(
    tokenA.target,
    tokenB.target,
    ethers.parseEther("100"),
    ethers.parseEther("200"),
    ethers.parseEther("90"),
    ethers.parseEther("90"),
    user1.address,
    deadline
  );
  const balanceAfter = await tokenB.balanceOf(user1.address);
  
  reserves = await pair.getReserves();
  reserveA = ethers.formatEther(reserves[0]);
  reserveB = ethers.formatEther(reserves[1]);
  
  console.log(`实际添加后储备量: ${reserveA} TKNA, ${reserveB} TKNB`);
  console.log(`TKNB 余额变化: ${ethers.formatEther(balanceBefore - balanceAfter)} (应该是 100，不是 200)`);
  
  // 学习要点
  console.log("\n=== 🎓 AMM 核心原理 ===");
  console.log("✅ 价格 = 对方储备量 / 本方储备量");
  console.log("✅ Router 强制按当前比例添加流动性");
  console.log("✅ 多余的代币会退还给用户");
  console.log("✅ 这保护了流动性提供者不被套利");
  console.log("✅ 恒定乘积公式: x * y = k");
  console.log("✅ 只有交易才能改变价格比例！");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 