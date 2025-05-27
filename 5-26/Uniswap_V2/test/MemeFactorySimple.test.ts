import { expect } from "chai";
import { ethers } from "hardhat";

describe("MemeFactory Simple Test", function () {
    let factory: any;
    let router: any;
    let uniswapFactory: any;
    let weth: any;
    let owner: any;
    let user1: any;

    const TOTAL_SUPPLY = ethers.parseEther("1000"); // 1K tokens
    const PER_MINT = 100; // 100 tokens per mint
    const PRICE = ethers.parseUnits("0.01", "ether"); // 0.01 ETH per token
    const MINT_COST = PRICE * BigInt(PER_MINT); // 1 ETH per mint

    beforeEach(async function () {
        [owner, user1] = await ethers.getSigners();

        // Send some ETH to user1 for testing
        await owner.sendTransaction({
            to: await user1.getAddress(),
            value: ethers.parseEther("10.0") // Send 10 ETH to user1
        });

        // Deploy Uniswap V2 contracts
        const UniswapV2Factory = await ethers.getContractFactory("UniswapV2Factory");
        uniswapFactory = await UniswapV2Factory.deploy(await owner.getAddress());

        const WETH = await ethers.getContractFactory("MockWETH");
        weth = await WETH.deploy();
        await weth.deposit({ value: ethers.parseEther("1000") });

        const UniswapV2Router02 = await ethers.getContractFactory("UniswapV2Router02");
        router = await UniswapV2Router02.deploy(
            await uniswapFactory.getAddress(),
            await weth.getAddress()
        );

        // Deploy MemeFactory
        const MemeFactory = await ethers.getContractFactory("MemeFactory");
        factory = await MemeFactory.deploy(await router.getAddress());
    });

    describe("Basic Functionality", function () {
        it("Should deploy and set correct parameters", async function () {
            expect(await factory.owner()).to.equal(await owner.getAddress());
            expect(await factory.uniswapRouter()).to.equal(await router.getAddress());
            expect(await factory.uniswapFactory()).to.equal(await uniswapFactory.getAddress());
        });

        it("Should deploy a new meme token", async function () {
            const tx = await factory.deployInscription("TEST", TOTAL_SUPPLY, PER_MINT, PRICE);
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
            const memeToken = parsedEvent?.args.token;
            
            expect(await factory.isValidToken(memeToken)).to.be.true;
            expect(await factory.tokenToOwner(memeToken)).to.equal(await owner.getAddress());
        });

        it("Should mint tokens successfully", async function () {
            // Deploy token
            const tx = await factory.deployInscription("TEST", TOTAL_SUPPLY, PER_MINT, PRICE);
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
            const memeToken = parsedEvent?.args.token;

            // Mint tokens
            const mintTx = await factory.connect(user1).mintInscription(memeToken, {
                value: MINT_COST
            });
            const mintReceipt = await mintTx.wait();

            // Check if MemeMinted event was emitted
            const memeMintedEvent = mintReceipt?.logs.find((log: any) => {
                try {
                    const parsed = factory.interface.parseLog(log);
                    return parsed?.name === "MemeMinted";
                } catch {
                    return false;
                }
            });
            expect(memeMintedEvent).to.not.be.undefined;

            // Check user received tokens
            const MemeToken = await ethers.getContractFactory("MemeToken");
            const token: any = MemeToken.attach(memeToken);
            expect(await token.balanceOf(await user1.getAddress())).to.equal(PER_MINT);
        });

        it("Should revert with incorrect payment", async function () {
            // Deploy token
            const tx = await factory.deployInscription("TEST", TOTAL_SUPPLY, PER_MINT, PRICE);
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
            const memeToken = parsedEvent?.args.token;

            await expect(
                factory.connect(user1).mintInscription(memeToken, {
                    value: MINT_COST / 2n
                })
            ).to.be.revertedWith("Incorrect payment amount");
        });

        it("Should get Uniswap price", async function () {
            // Deploy token
            const tx = await factory.deployInscription("TEST", TOTAL_SUPPLY, PER_MINT, PRICE);
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
            const memeToken = parsedEvent?.args.token;

            // Should return 0 when no liquidity
            const price = await factory.getUniswapPrice(memeToken, ethers.parseEther("1"));
            expect(price).to.equal(0);
        });
    });
}); 