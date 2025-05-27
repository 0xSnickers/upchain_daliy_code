import { expect } from "chai";
import { ethers } from "hardhat";
import { UniswapV2Factory__factory, UniswapV2Router02__factory, MockERC20__factory } from "../typechain-types";

describe("UniswapV2", function () {
  let factory: any;
  let router: any;
  let tokenA: any;
  let tokenB: any;
  let owner: any;
  let WETH: string;

  beforeEach(async function () {
    [owner] = await ethers.getSigners();
    WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

    // Deploy Factory
    factory = await new UniswapV2Factory__factory(owner).deploy(owner.address);
    await factory.waitForDeployment();

    // Deploy Router
    router = await new UniswapV2Router02__factory(owner).deploy(
      await factory.getAddress(),
      WETH
    );
    await router.waitForDeployment();

    // Deploy test tokens
    tokenA = await new MockERC20__factory(owner).deploy("Token A", "TKNA", 18);
    await tokenA.waitForDeployment();

    tokenB = await new MockERC20__factory(owner).deploy("Token B", "TKNB", 18);
    await tokenB.waitForDeployment();
  });

  it("should create pair", async function () {
    const tx = await factory.createPair(await tokenA.getAddress(), await tokenB.getAddress());
    const receipt = await tx.wait();
    
    const pairAddress = await factory.getPair(await tokenA.getAddress(), await tokenB.getAddress());
    expect(pairAddress).to.not.equal(ethers.ZeroAddress);
  });

  it("should add liquidity", async function () {
    // Create pair
    await factory.createPair(await tokenA.getAddress(), await tokenB.getAddress());

    // Mint tokens
    const amount = ethers.parseEther("1000");
    await tokenA.mint(owner.address, amount);
    await tokenB.mint(owner.address, amount);

    // Approve router
    await tokenA.approve(await router.getAddress(), amount);
    await tokenB.approve(await router.getAddress(), amount);

    // Add liquidity
    const liquidityAmount = ethers.parseEther("100");
    const tx = await router.addLiquidity(
      await tokenA.getAddress(),
      await tokenB.getAddress(),
      liquidityAmount,
      liquidityAmount,
      liquidityAmount,
      liquidityAmount,
      owner.address,
      Math.floor(Date.now() / 1000) + 3600
    );
    const receipt = await tx.wait();

    // Get pair address
    const pairAddress = await factory.getPair(await tokenA.getAddress(), await tokenB.getAddress());
    const pair = await ethers.getContractAt("IUniswapV2Pair", pairAddress);

    // Check liquidity
    const balance = await pair.balanceOf(owner.address);
    expect(balance).to.be.gt(0);
  });
}); 