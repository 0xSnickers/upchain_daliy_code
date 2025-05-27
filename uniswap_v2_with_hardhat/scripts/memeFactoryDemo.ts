import { ethers } from "hardhat";

async function main() {
    console.log("🚀 MemeFactory 演示开始...\n");

    // 获取签名者
    const [deployer, user1, user2] = await ethers.getSigners();
    console.log("👤 部署者地址:", await deployer.getAddress());
    console.log("👤 用户1地址:", await user1.getAddress());
    console.log("👤 用户2地址:", await user2.getAddress());
    console.log();

    // 1. 部署 Uniswap V2 合约
    console.log("📦 部署 Uniswap V2 合约...");
    
    const UniswapV2Factory = await ethers.getContractFactory("UniswapV2Factory");
    const uniswapFactory = await UniswapV2Factory.deploy(await deployer.getAddress());
    console.log("✅ UniswapV2Factory 部署完成:", await uniswapFactory.getAddress());

    const WETH = await ethers.getContractFactory("MockERC20");
    const weth = await WETH.deploy("Wrapped Ether", "WETH", 18);
    await weth.mint(await deployer.getAddress(), ethers.parseEther("1000000"));
    console.log("✅ WETH 部署完成:", await weth.getAddress());

    const UniswapV2Router02 = await ethers.getContractFactory("UniswapV2Router02");
    const router = await UniswapV2Router02.deploy(
        await uniswapFactory.getAddress(),
        await weth.getAddress()
    );
    console.log("✅ UniswapV2Router02 部署完成:", await router.getAddress());
    console.log();

    // 2. 部署 MemeFactory
    console.log("📦 部署 MemeFactory...");
    const MemeFactory = await ethers.getContractFactory("MemeFactory");
    const factory: any = await MemeFactory.deploy(await router.getAddress());
    console.log("✅ MemeFactory 部署完成:", await factory.getAddress());
    console.log();

    // 3. 部署 Meme Token
    console.log("🎯 部署 Meme Token...");
    const TOTAL_SUPPLY = ethers.parseEther("1000000"); // 1M tokens
    const PER_MINT = ethers.parseEther("10"); // 10 tokens per mint
    const PRICE = ethers.parseUnits("0.01", "ether"); // 0.01 ETH per token
    const MINT_COST = PRICE * PER_MINT; // 0.1 ETH per mint

    const tx = await factory.deployInscription("PEPE", TOTAL_SUPPLY, PER_MINT, PRICE);
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
    const memeTokenAddress = parsedEvent?.args.token;
    
    console.log("✅ PEPE Token 部署完成:", memeTokenAddress);
    console.log("📊 总供应量:", ethers.formatEther(TOTAL_SUPPLY), "PEPE");
    console.log("📊 每次铸造:", ethers.formatEther(PER_MINT), "PEPE");
    console.log("📊 铸造价格:", ethers.formatEther(PRICE), "ETH per PEPE");
    console.log("📊 每次铸造成本:", ethers.formatEther(MINT_COST), "ETH");
    console.log("📊 实际计算:", ethers.formatEther(PRICE), "*", ethers.formatEther(PER_MINT), "=", ethers.formatEther(MINT_COST));
    console.log();

    // 4. 第一次铸造（会添加初始流动性）
    console.log("🔨 用户1进行第一次铸造（会添加初始流动性）...");
    const mintTx1 = await factory.connect(user1).mintInscription(memeTokenAddress, {
        value: MINT_COST
    });
    const mintReceipt1 = await mintTx1.wait();
    
    // 检查是否添加了流动性
    const liquidityEvent = mintReceipt1?.logs.find((log: any) => {
        try {
            const parsed = factory.interface.parseLog(log);
            return parsed?.name === "LiquidityAdded";
        } catch {
            return false;
        }
    });
    
    if (liquidityEvent) {
        const liquidityParsed = factory.interface.parseLog(liquidityEvent);
        console.log("✅ 初始流动性已添加!");
        console.log("📊 代币数量:", ethers.formatEther(liquidityParsed?.args.tokenAmount), "PEPE");
        console.log("📊 ETH数量:", ethers.formatEther(liquidityParsed?.args.ethAmount), "ETH");
    }

    // 检查用户1的代币余额
    const MemeToken = await ethers.getContractFactory("MemeToken");
    const token: any = MemeToken.attach(memeTokenAddress);
    const user1Balance = await token.balanceOf(await user1.getAddress());
    console.log("📊 用户1 PEPE 余额:", ethers.formatEther(user1Balance), "PEPE");
    console.log();

    // 5. 第二次铸造（不会添加流动性）
    console.log("🔨 用户2进行第二次铸造（不会添加流动性）...");
    const mintTx2 = await factory.connect(user2).mintInscription(memeTokenAddress, {
        value: MINT_COST
    });
    const mintReceipt2 = await mintTx2.wait();
    
    // 检查是否添加了流动性
    const liquidityEvent2 = mintReceipt2?.logs.find((log: any) => {
        try {
            const parsed = factory.interface.parseLog(log);
            return parsed?.name === "LiquidityAdded";
        } catch {
            return false;
        }
    });
    
    if (!liquidityEvent2) {
        console.log("✅ 第二次铸造没有添加流动性（符合预期）");
    }

    const user2Balance = await token.balanceOf(await user2.getAddress());
    console.log("📊 用户2 PEPE 余额:", ethers.formatEther(user2Balance), "PEPE");
    console.log();

    // 6. 检查 Uniswap 价格
    console.log("💰 检查 Uniswap 价格...");
    const ethAmount = ethers.parseEther("1");
    const uniswapPrice = await factory.getUniswapPrice(memeTokenAddress, ethAmount);
    const mintPrice = ethAmount / PRICE;
    
    console.log("📊 1 ETH 在 Uniswap 能买到:", ethers.formatEther(uniswapPrice), "PEPE");
    console.log("📊 1 ETH 在 Mint 能买到:", ethers.formatEther(mintPrice), "PEPE");
    console.log("📊 Uniswap 价格是否更优:", uniswapPrice > mintPrice ? "是" : "否");
    console.log();

    // 7. 尝试通过 buyMeme 购买（可能会失败，因为价格不够优惠）
    console.log("🛒 尝试通过 buyMeme 购买...");
    try {
        const buyAmount = ethers.parseEther("0.5");
        const deadline = Math.floor(Date.now() / 1000) + 300;
        
        const buyTx = await factory.connect(user2).buyMeme(
            memeTokenAddress,
            0, // amountOutMin
            deadline,
            { value: buyAmount }
        );
        const buyReceipt = await buyTx.wait();
        
        const boughtEvent = buyReceipt?.logs.find((log: any) => {
            try {
                const parsed = factory.interface.parseLog(log);
                return parsed?.name === "MemeBought";
            } catch {
                return false;
            }
        });
        
        if (boughtEvent) {
            const boughtParsed = factory.interface.parseLog(boughtEvent);
            console.log("✅ 通过 Uniswap 购买成功!");
            console.log("📊 花费 ETH:", ethers.formatEther(boughtParsed?.args.amountIn));
            console.log("📊 获得 PEPE:", ethers.formatEther(boughtParsed?.args.amountOut));
        }
    } catch (error: any) {
        console.log("❌ buyMeme 失败:", error.reason || "价格不够优惠");
    }
    console.log();

    // 8. 添加更多流动性使价格更优惠
    console.log("🔨 添加更多流动性使价格更优惠...");
    await factory.connect(user1).mintInscription(memeTokenAddress, {
        value: MINT_COST
    });
    await factory.connect(user1).mintInscription(memeTokenAddress, {
        value: MINT_COST
    });
    console.log("✅ 已添加更多流动性");
    console.log();

    // 9. 再次检查价格
    console.log("💰 再次检查 Uniswap 价格...");
    const newUniswapPrice = await factory.getUniswapPrice(memeTokenAddress, ethAmount);
    console.log("📊 1 ETH 在 Uniswap 能买到:", ethers.formatEther(newUniswapPrice), "PEPE");
    console.log("📊 1 ETH 在 Mint 能买到:", ethers.formatEther(mintPrice), "PEPE");
    console.log("📊 Uniswap 价格是否更优:", newUniswapPrice > mintPrice ? "是" : "否");
    console.log();

    // 10. 再次尝试 buyMeme
    console.log("🛒 再次尝试通过 buyMeme 购买...");
    try {
        const buyAmount = ethers.parseEther("2");
        const deadline = Math.floor(Date.now() / 1000) + 300;
        
        const user2BalanceBefore = await token.balanceOf(await user2.getAddress());
        
        const buyTx = await factory.connect(user2).buyMeme(
            memeTokenAddress,
            0, // amountOutMin
            deadline,
            { value: buyAmount }
        );
        const buyReceipt = await buyTx.wait();
        
        const boughtEvent = buyReceipt?.logs.find((log: any) => {
            try {
                const parsed = factory.interface.parseLog(log);
                return parsed?.name === "MemeBought";
            } catch {
                return false;
            }
        });
        
        if (boughtEvent) {
            const boughtParsed = factory.interface.parseLog(boughtEvent);
            const user2BalanceAfter = await token.balanceOf(await user2.getAddress());
            
            console.log("✅ 通过 Uniswap 购买成功!");
            console.log("📊 花费 ETH:", ethers.formatEther(boughtParsed?.args.amountIn));
            console.log("📊 获得 PEPE:", ethers.formatEther(boughtParsed?.args.amountOut));
            console.log("📊 用户2 PEPE 余额变化:", 
                ethers.formatEther(user2BalanceBefore), "→", 
                ethers.formatEther(user2BalanceAfter));
        }
    } catch (error: any) {
        console.log("❌ buyMeme 失败:", error.reason || "未知错误");
    }
    console.log();

    // 11. 显示最终状态
    console.log("📊 最终状态:");
    console.log("👤 用户1 PEPE 余额:", ethers.formatEther(await token.balanceOf(await user1.getAddress())), "PEPE");
    console.log("👤 用户2 PEPE 余额:", ethers.formatEther(await token.balanceOf(await user2.getAddress())), "PEPE");
    console.log("💰 Factory ETH 余额:", ethers.formatEther(await ethers.provider.getBalance(await factory.getAddress())), "ETH");
    console.log("💰 Token ETH 余额:", ethers.formatEther(await ethers.provider.getBalance(memeTokenAddress)), "ETH");
    
    console.log("\n🎉 MemeFactory 演示完成!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    }); 