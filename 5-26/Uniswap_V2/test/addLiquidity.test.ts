import { expect } from "chai";
import { ethers } from "hardhat";

describe("UniswapV2 AddLiquidity", function () {
  let factory: any;
  let router: any;
  let tokenA: any;
  let tokenB: any;
  let owner: any;
  const WETH = "0x0000000000000000000000000000000000000000"; // 使用零地址作为 WETH

  beforeEach(async function () {
    [owner] = await ethers.getSigners();

    // Deploy Factory
    const Factory = await ethers.getContractFactory("UniswapV2Factory");
    factory = await Factory.deploy(owner.address);

    // Deploy Router
    const Router = await ethers.getContractFactory("UniswapV2Router02");
    router = await Router.deploy(factory.target, WETH);

    // Deploy test tokens
    const Token = await ethers.getContractFactory("MockERC20");
    tokenA = await Token.deploy("Token A", "TKNA", 18);
    tokenB = await Token.deploy("Token B", "TKNB", 18);
  });

  it("should add liquidity", async function () {
    // Mint tokens
    const amount = ethers.parseEther("1000");
    await tokenA.mint(owner.address, amount);
    await tokenB.mint(owner.address, amount);

    // Approve router
    await tokenA.approve(router.target, amount);
    await tokenB.approve(router.target, amount);

    // Add liquidity
    const liquidityAmount = ethers.parseEther("100");
    const tx = await router.addLiquidity(
      tokenA.target,
      tokenB.target,
      liquidityAmount,
      liquidityAmount,
      liquidityAmount,
      liquidityAmount,
      owner.address,
      Math.floor(Date.now() / 1000) + 3600
    );
    await tx.wait();

    // Get pair address
    const pairAddress = await factory.getPair(tokenA.target, tokenB.target);
    const pair = await ethers.getContractAt("IUniswapV2Pair", pairAddress);

    // Check liquidity
    const balance = await pair.balanceOf(owner.address);
    expect(balance).to.be.gt(0);
  });
}); 