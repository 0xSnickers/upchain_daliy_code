import { expect } from "chai";
import { ethers } from "hardhat";

describe("MemeFactory", function () {
    let factory: any;
    let router: any;
    let uniswapFactory: any;
    let weth: any;
    let owner: any;
    let user1: any;
    let user2: any;
    let memeToken: string;

    const TOTAL_SUPPLY = ethers.parseEther("1000000"); // 1M tokens
    const PER_MINT = 100; // 100 tokens per mint (整数)
    const PRICE = ethers.parseUnits("0.01", "ether"); // 0.01 ETH per token
    const MINT_COST = PRICE * BigInt(PER_MINT); // 1 ETH per mint

    beforeEach(async function () {
        [owner, user1, user2] = await ethers.getSigners();

        // Deploy Uniswap V2 contracts
        const UniswapV2Factory = await ethers.getContractFactory("UniswapV2Factory");
        uniswapFactory = await UniswapV2Factory.deploy(await owner.getAddress());

        const WETH = await ethers.getContractFactory("MockWETH");
        weth = await WETH.deploy();
        await weth.deposit({ value: ethers.parseEther("100") });

        const UniswapV2Router02 = await ethers.getContractFactory("UniswapV2Router02");
        router = await UniswapV2Router02.deploy(
            await uniswapFactory.getAddress(),
            await weth.getAddress()
        );

        // Deploy MemeFactory
        const MemeFactory = await ethers.getContractFactory("MemeFactory");
        factory = await MemeFactory.deploy(await router.getAddress());
    });

    describe("Deployment", function () {
        it("Should set the correct owner", async function () {
            expect(await factory.owner()).to.equal(await owner.getAddress());
        });

        it("Should set the correct router and factory addresses", async function () {
            expect(await factory.uniswapRouter()).to.equal(await router.getAddress());
            expect(await factory.uniswapFactory()).to.equal(await uniswapFactory.getAddress());
        });

        it("Should deploy implementation contract", async function () {
            const implementation = await factory.implementation();
            expect(implementation).to.not.equal(ethers.ZeroAddress);
        });
    });

    describe("Deploy Inscription", function () {
        it("Should deploy a new meme token", async function () {
            const tx = await factory.deployInscription("MEME", TOTAL_SUPPLY, PER_MINT, PRICE);
            const receipt = await tx.wait();
            
            const event = receipt?.logs.find((log: any) => {
                try {
                    const parsed = factory.interface.parseLog(log);
                    return parsed?.name === "MemeDeployed";
                } catch {
                    return false;
                }
            });
            
            expect(event).to.not.be.undefined;
            const parsedEvent = factory.interface.parseLog(event);
            memeToken = parsedEvent?.args.token;
            
            expect(await factory.isValidToken(memeToken)).to.be.true;
            expect(await factory.tokenToOwner(memeToken)).to.equal(await owner.getAddress());
        });

        it("Should revert with invalid parameters", async function () {
            await expect(
                factory.deployInscription("MEME", 0, PER_MINT, PRICE)
            ).to.be.revertedWith("Total supply must be > 0");

            await expect(
                factory.deployInscription("MEME", TOTAL_SUPPLY, 0, PRICE)
            ).to.be.revertedWith("Invalid perMint amount");

            await expect(
                factory.deployInscription("MEME", TOTAL_SUPPLY, PER_MINT, 0)
            ).to.be.revertedWith("Price must be > 0");
        });
    });

    describe("Mint Inscription", function () {
        beforeEach(async function () {
            const tx = await factory.deployInscription("MEME", TOTAL_SUPPLY, PER_MINT, PRICE);
            const receipt = await tx.wait();
            
            const event = receipt?.logs.find((log: any) => {
                try {
                    const parsed = factory.interface.parseLog(log);
                    return parsed?.name === "MemeDeployed";
                } catch {
                    return false;
                }
            });
            
            const parsedEvent = factory.interface.parseLog(event);
            memeToken = parsedEvent?.args.token;
        });

        it("Should mint tokens and add initial liquidity", async function () {
            const tx = await factory.connect(user1).mintInscription(memeToken, {
                value: MINT_COST
            });
            const receipt = await tx.wait();

            // Check if MemeMinted event was emitted
            const memeMintedEvent = receipt?.logs.find((log: any) => {
                try {
                    const parsed = factory.interface.parseLog(log);
                    return parsed?.name === "MemeMinted";
                } catch {
                    return false;
                }
            });
            expect(memeMintedEvent).to.not.be.undefined;

            // Check if LiquidityAdded event was emitted (first mint should add liquidity)
            const liquidityEvent = receipt?.logs.find((log: any) => {
                try {
                    const parsed = factory.interface.parseLog(log);
                    return parsed?.name === "LiquidityAdded";
                } catch {
                    return false;
                }
            });
            expect(liquidityEvent).to.not.be.undefined;

            // Check that hasLiquidity is now true
            expect(await factory.hasLiquidity(memeToken)).to.be.true;

            // Check user received tokens
            const MemeToken = await ethers.getContractFactory("MemeToken");
            const token: any = MemeToken.attach(memeToken);
            expect(await token.balanceOf(await user1.getAddress())).to.equal(PER_MINT);
        });

        it("Should handle subsequent mints without adding liquidity", async function () {
            // First mint (adds liquidity)
            await factory.connect(user1).mintInscription(memeToken, {
                value: MINT_COST
            });

            // Second mint (should not add liquidity)
            const tx = await factory.connect(user2).mintInscription(memeToken, {
                value: MINT_COST
            });
            const receipt = await tx.wait();

            // Check that no LiquidityAdded event was emitted
            const liquidityEvent = receipt?.logs.find((log: any) => {
                try {
                    const parsed = factory.interface.parseLog(log);
                    return parsed?.name === "LiquidityAdded";
                } catch {
                    return false;
                }
            });
            expect(liquidityEvent).to.be.undefined;
        });

        it("Should revert with incorrect payment", async function () {
            await expect(
                factory.connect(user1).mintInscription(memeToken, {
                    value: MINT_COST / 2n
                })
            ).to.be.revertedWith("Incorrect payment amount");
        });

        it("Should revert with invalid token address", async function () {
            await expect(
                factory.connect(user1).mintInscription(ethers.ZeroAddress, {
                    value: MINT_COST
                })
            ).to.be.revertedWith("Invalid token address");
        });
    });

    describe("Buy Meme", function () {
        beforeEach(async function () {
            // Deploy meme token
            const tx = await factory.deployInscription("MEME", TOTAL_SUPPLY, PER_MINT, PRICE);
            const receipt = await tx.wait();
            
            const event = receipt?.logs.find((log: any) => {
                try {
                    const parsed = factory.interface.parseLog(log);
                    return parsed?.name === "MemeDeployed";
                } catch {
                    return false;
                }
            });
            
            const parsedEvent = factory.interface.parseLog(event);
            memeToken = parsedEvent?.args.token;

            // Add initial liquidity by minting
            await factory.connect(user1).mintInscription(memeToken, {
                value: MINT_COST
            });
        });
        // 购买时，Uniswap价格不优于mint价格
        it("Should revert when no liquidity available", async function () {
            // Deploy a new token without liquidity
            const tx = await factory.deployInscription("MEME2", TOTAL_SUPPLY, PER_MINT, PRICE);
            const receipt = await tx.wait();
            
            const event = receipt?.logs.find((log: any) => {
                try {
                    const parsed = factory.interface.parseLog(log);
                    return parsed?.name === "MemeDeployed";
                } catch {
                    return false;
                }
            });
            
            const parsedEvent = factory.interface.parseLog(event);
            const memeToken2 = parsedEvent?.args.token;

            await expect(
                factory.connect(user2).buyMeme(
                    memeToken2,
                    0,
                    Math.floor(Date.now() / 1000) + 300,
                    { value: ethers.parseEther("0.1") }
                )
            ).to.be.revertedWith("No liquidity available");
        });
        // 购买时，Uniswap价格不优于mint价格
        it("Should revert when Uniswap price is not favorable", async function () {
            // 用户通过 Uniswap 购买代币时，会对比两个价格：
            // - Uniswap 价格：通过 getAmountsOut 获取
            // - Mint 价格：通过 msg.value / token.price() 计算
            // 只有当 Uniswap 价格比 Mint 价格更优惠时，用户才会选择通过 Uniswap 购买
            // 当 Uniswap 价格不优于 Mint 价格时，会抛出错误
            await expect(
                factory.connect(user2).buyMeme(
                    memeToken,
                    0,
                    Math.floor(Date.now() / 1000) + 300,
                    { value: ethers.parseUnits("0.001", "ether") }
                )
            ).to.be.reverted;
        });
        // 购买时，Uniswap价格优于mint价格
        it("Should allow buying when Uniswap price is favorable", async function () {
            // Add more liquidity to make Uniswap price more favorable
            await factory.connect(user1).mintInscription(memeToken, {
                value: MINT_COST
            });
            await factory.connect(user1).mintInscription(memeToken, {
                value: MINT_COST
            });

            // Now try to buy a larger amount
            const buyAmount = ethers.parseEther("2");
            const deadline = Math.floor(Date.now() / 1000) + 300;

            const tx = await factory.connect(user2).buyMeme(
                memeToken,
                0,
                deadline,
                { value: buyAmount }
            );
            const receipt = await tx.wait();

            // Check if MemeBought event was emitted
            const boughtEvent = receipt?.logs.find((log: any) => {
                try {
                    const parsed = factory.interface.parseLog(log);
                    return parsed?.name === "MemeBought";
                } catch {
                    return false;
                }
            });
            expect(boughtEvent).to.not.be.undefined;
        });
        // 购买时，Uniswap价格不优于mint价格
        it("Should revert with invalid token address", async function () {
            await expect(
                factory.connect(user2).buyMeme(
                    ethers.ZeroAddress,
                    0,
                    Math.floor(Date.now() / 1000) + 300,
                    { value: ethers.parseEther("0.1") }
                )
            ).to.be.revertedWith("Invalid token address");
        });
    });
    // 获取Uniswap价格
    describe("Get Uniswap Price", function () {
        beforeEach(async function () {
            const tx = await factory.deployInscription("MEME", TOTAL_SUPPLY, PER_MINT, PRICE);
            const receipt = await tx.wait();
            
            const event = receipt?.logs.find((log: any) => {
                try {
                    const parsed = factory.interface.parseLog(log);
                    return parsed?.name === "MemeDeployed";
                } catch {
                    return false;
                }
            });
            
            const parsedEvent = factory.interface.parseLog(event);
            memeToken = parsedEvent?.args.token;
        });

        it("Should return 0 when no liquidity exists", async function () {
            const price = await factory.getUniswapPrice(memeToken, ethers.parseEther("1"));
            expect(price).to.equal(0);
        });

        it("Should return price when liquidity exists", async function () {
            // Add liquidity
            await factory.connect(user1).mintInscription(memeToken, {
                value: MINT_COST
            });

            const price = await factory.getUniswapPrice(memeToken, ethers.parseEther("1"));
            expect(price).to.be.gt(0);
        });
    });
    // 提现
    describe("Withdraw", function () {
        it("Should allow owner to withdraw", async function () {
            // Send some ETH to the factory
            await owner.sendTransaction({
                to: await factory.getAddress(),
                value: ethers.parseEther("1")
            });

            const initialBalance = await ethers.provider.getBalance(await owner.getAddress());
            
            const tx = await factory.withdraw(await owner.getAddress());
            await tx.wait();

            const finalBalance = await ethers.provider.getBalance(await owner.getAddress());
            expect(finalBalance).to.be.gt(initialBalance - ethers.parseEther("0.1")); // Account for gas
        });

        it("Should revert when non-owner tries to withdraw", async function () {
            await expect(
                factory.connect(user1).withdraw(await user1.getAddress())
            ).to.be.revertedWith("MemeFactory: Not owner");
        });
    });
  
}); 