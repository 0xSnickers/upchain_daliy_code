// SPDX-License-Identifier: MIT
pragma solidity =0.6.6;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./MemeToken.sol";
import "../interfaces/IUniswapV2Router02.sol";
import "../interfaces/IUniswapV2Factory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// MemeFactory部署后，核心函数：
// implementation	模板合约地址（MemeToken 实例）
// projectOwner	平台方地址，收取 1% 铸造手续费
// tokenToOwner	每个 clone 合约对应的代币发行人
// isValidToken	校验地址是否为合法 clone
// deployInscription(...)	克隆模板合约并初始化（部署新的 Meme Token）
// mintInscription(...)	允许用户铸造指定 Meme Token，并自动完成收益分配
// buyMeme(...)	允许用户通过Uniswap购买Meme Token
contract MemeFactory {
    using Clones for address;
    
    address public immutable implementation; // 模板合约地址
    address public immutable owner; // 平台方地址
    IUniswapV2Router02 public immutable uniswapRouter; // 获取Uniswap router地址
    IUniswapV2Factory public immutable uniswapFactory; // 获取Uniswap工厂地址
    
    // 费用会自动分配：5%用于添加流动性，95%给代币发行者
    uint256 public constant LIQUIDITY_FEE_PERCENTAGE = 5;  // 锻造手续费
    
    mapping(address => address) public tokenToOwner; // 记录每个clone合约对应的代币发行人
    mapping(address => bool) public isValidToken; // 校验地址是否为合法 clone
    mapping(address => bool) public hasLiquidity; // 记录是否已添加流动性
    
    // MemeDeployed：每次部署一个 Meme 会发出该事件，便于前端监听。
    event MemeDeployed(address indexed token, address indexed owner, string symbol, uint256 totalSupply, uint256 perMint, uint256 price);
    // MemeMinted：每次用户 mint 会触发该事件，记录地址/金额/数量。
    event MemeMinted(address indexed token, address indexed minter, uint256 amount, uint256 cost);
    // LiquidityAdded：添加流动性事件
    event LiquidityAdded(address indexed token, uint256 tokenAmount, uint256 ethAmount, uint256 liquidity);
    // MemeBought：通过Uniswap购买事件
    event MemeBought(address indexed token, address indexed buyer, uint256 amountIn, uint256 amountOut);
    
    // Custom errors replaced with require statements for 0.6.6 compatibility
    
    modifier OnlyOwner(){
        require(msg.sender == owner, "MemeFactory: Not owner");
        _;
    }

    constructor(address _uniswapRouter) public {
        // 部署后，MemeFactory 自动内部部署了一个 MemeToken 逻辑合约实例，用作所有 meme clone 的逻辑源头
        implementation = address(new MemeToken()); // 部署模板
        owner = msg.sender;
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        uniswapFactory = IUniswapV2Factory(IUniswapV2Router02(_uniswapRouter).factory());
    }
    
    // @notice 发行代币
    // @param  symbol 代币符号
    // @param uint256 totalSupply 总供应量 如：1000000000
    // @param uint256 perMint 每次锻造的数量 如：10000
    // @param uint256 price 铸造价格 如：100000000000000 wei = 0.0001ETH
    // 每次 mintInscription Mint 成本 = 0.0001ETH * 10000 = 1ETH
    function deployInscription(
        string calldata symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    ) external returns (address) {
        require(totalSupply > 0, "Total supply must be > 0");
        require(perMint > 0 && perMint <= totalSupply, "Invalid perMint amount");
        require(price > 0, "Price must be > 0");
        
        // clone 一个新的 MemeToken 合约
        address clone = implementation.clone();
        // 初始化它（通过 initialize()）
        // MemeToken 因为拥有 receive 功能，则需要加上 payable 类型转换
        MemeToken(payable(clone)).initialize(msg.sender, symbol, totalSupply, perMint, price);
        // 把发行人地址和合约地址映射记录
        tokenToOwner[clone] = msg.sender;
        isValidToken[clone] = true;

        emit MemeDeployed(clone, msg.sender, symbol, totalSupply, perMint, price);
        // 返回新的合约地址
        return clone;
    }
    
    // @notice 购买者铸造代币（任何用户都可以通过调用 mintInscription(tokenAddr) 来 mint 某个 Meme。）
    // @param address tokenAddr 代币地址
    function mintInscription(address tokenAddr) external payable {
        require(isValidToken[tokenAddr], "Invalid token address");
        
        MemeToken token = MemeToken(payable(tokenAddr));
        uint256 mintCost = token.price() * token.perMint(); 

        require(msg.value == mintCost, "Incorrect payment amount");

        // 计算费用分配
        uint256 liquidityFee = (mintCost * LIQUIDITY_FEE_PERCENTAGE) / 100;
        uint256 ownerFee = mintCost - liquidityFee;

        // 先mint代币给用户
        token.mint{value: 0}(msg.sender);

        // 如果还没有添加过流动性，则添加初始流动性
        if (!hasLiquidity[tokenAddr]) {
            _addInitialLiquidity(tokenAddr, liquidityFee);
            hasLiquidity[tokenAddr] = true;
        } else {
            // 如果已有流动性，将liquidityFee发送给项目方
            payable(address(this)).transfer(liquidityFee);
        }

        // 发送owner费用到代币合约
        payable(tokenAddr).transfer(ownerFee);

        emit MemeMinted(tokenAddr, msg.sender, token.perMint(), mintCost);
    }
    
    // @notice 通过Uniswap购买Meme代币
    // @param tokenAddr 代币地址
    // @param amountOutMin 最小输出代币数量
    // @param deadline 交易截止时间
    function buyMeme(
        address tokenAddr,
        uint256 amountOutMin,
        uint256 deadline
    ) external payable {
        require(isValidToken[tokenAddr], "Invalid token address");
        require(hasLiquidity[tokenAddr], "No liquidity available");
        require(msg.value > 0, "Must send ETH");
        
        MemeToken token = MemeToken(payable(tokenAddr));
        
        // 检查Uniswap价格是否优于mint价格
        address pair = uniswapFactory.getPair(tokenAddr, uniswapRouter.WETH());
        require(pair != address(0), "Pair does not exist");
        
        // 获取当前Uniswap价格并与mint价格比较
        address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH();
        path[1] = tokenAddr;
        
        uint256[] memory amountsOut = uniswapRouter.getAmountsOut(msg.value, path);
        uint256 uniswapTokensOut = amountsOut[1];
        
        // 计算mint价格下能得到的代币数量
        uint256 mintTokensOut = msg.value / token.price();
        
        // 只有当Uniswap价格更优时才允许购买
        require(uniswapTokensOut > mintTokensOut && mintTokensOut > 0, "Price not favorable");
        
        // 通过Uniswap购买代币
        uint256[] memory amounts = uniswapRouter.swapExactETHForTokens{value: msg.value}(
            amountOutMin,
            path,
            msg.sender,
            deadline
        );
        
        emit MemeBought(tokenAddr, msg.sender, msg.value, amounts[1]);
    }
    
    // @notice 添加初始流动性
    // @param tokenAddr 代币地址
    // @param ethAmount ETH数量
    function _addInitialLiquidity(address tokenAddr, uint256 ethAmount) internal {
        MemeToken token = MemeToken(payable(tokenAddr));
        
        // 根据mint价格计算应该添加的代币数量
        uint256 tokenAmount = ethAmount / token.price();
        
        // 确保有足够的代币可以添加流动性
        require(tokenAmount > 0, "Insufficient token amount");
        
        // mint代币给factory用于添加流动性
        token.mint{value: 0}(address(this));
        
        // 批准router使用代币
        IERC20(tokenAddr).approve(address(uniswapRouter), tokenAmount);
        
        // 添加流动性
        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = uniswapRouter.addLiquidityETH{value: ethAmount}(
            tokenAddr,
            tokenAmount,
            0, // amountTokenMin
            0, // amountETHMin
            address(this), // LP代币发送给factory
            block.timestamp + 300 // deadline
        );
        
        emit LiquidityAdded(tokenAddr, amountToken, amountETH, liquidity);
    }
    
    // @notice 获取代币的Uniswap价格
    // @param tokenAddr 代币地址
    // @param ethAmount ETH数量
    // @return 能够获得的代币数量
    function getUniswapPrice(address tokenAddr, uint256 ethAmount) external view returns (uint256) {
        require(isValidToken[tokenAddr], "Invalid token address");
        
        address pair = uniswapFactory.getPair(tokenAddr, uniswapRouter.WETH());
        if (pair == address(0)) {
            return 0; // 没有流动性
        }
        
        address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH();
        path[1] = tokenAddr;
        
        try uniswapRouter.getAmountsOut(ethAmount, path) returns (uint256[] memory amounts) {
            return amounts[1];
        } catch {
            return 0;
        }
    }
    
    receive() external payable { }

    function withdraw(address _to) public OnlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0,"Insufficient balance");
        // 将余额转到项目方
        (bool success, ) = payable(_to).call{value: balance}("");
        require(success, "Withdraw failed");
    }
}
