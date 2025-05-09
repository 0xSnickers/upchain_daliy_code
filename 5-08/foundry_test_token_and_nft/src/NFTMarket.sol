// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./ITokenReceiver.sol";
import "forge-std/console.sol";

contract NFTMarket is ReentrancyGuard, ITokenReceiver {
    // NFT 上架信息结构
    struct Listing {
        address seller;        // 卖家地址
        uint256 price;         // 价格（Token数量）
        bool isActive;         // 是否在售
    }

    // 存储 NFT 上架信息
    // nftContract => tokenId => Listing
    mapping(address => mapping(uint256 => Listing)) private _listings;
    
    // 存储平台收取的手续费（百分比）
    uint256 public feePercentage = 250; // 2.5%
    
    // 存储平台收取的手续费地址
    address public feeCollector;

    // 事件定义
    event NFTListed(address indexed nftContract, uint256 indexed tokenId, address indexed seller, uint256 price);
    event NFTSold(address indexed nftContract, uint256 indexed tokenId, address indexed buyer, uint256 price);
    event NFTUnlisted(address indexed nftContract, uint256 indexed tokenId, address indexed seller);

    constructor(address _feeCollector) {
        feeCollector = _feeCollector;
    }

    /**
     * @dev 上架 NFT
     * @param nftContract NFT合约地址
     * @param tokenId NFT的ID
     * @param price 价格（Token数量）
     */
    function list(address nftContract, uint256 tokenId, uint256 price) external nonReentrant {
        require(price > 0, "NFTMarket: price must be greater than 0");
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "NFTMarket: not the owner");
        require(IERC721(nftContract).getApproved(tokenId) == address(this) || 
                IERC721(nftContract).isApprovedForAll(msg.sender, address(this)), 
                "NFTMarket: not approved");

        // 创建上架信息
        _listings[nftContract][tokenId] = Listing({
            seller: msg.sender,
            price: price,
            isActive: true
        });

        emit NFTListed(nftContract, tokenId, msg.sender, price);
    }

    /**
     * @dev 购买 NFT
     * @param nftContract NFT合约地址
     * @param tokenId NFT的ID
     * @param token ERC20代币地址
     */
    function buyNFT(address nftContract, uint256 tokenId, address token) external nonReentrant {
        Listing storage listing = _listings[nftContract][tokenId];
        require(listing.isActive, "NFTMarket: NFT not for sale");
        require(listing.seller != msg.sender, "NFTMarket: cannot buy your own NFT");

        // 计算手续费
        uint256 fee = (listing.price * feePercentage) / 10000;
        uint256 sellerAmount = listing.price - fee;

        // 转移代币
        require(IERC20(token).transferFrom(msg.sender, address(this), listing.price), "NFTMarket: token transfer failed");
        
        // 转移代币给卖家
        require(IERC20(token).transfer(listing.seller, sellerAmount), "NFTMarket: seller transfer failed");
        
        // 转移手续费给平台
        if (fee > 0) {
            require(IERC20(token).transfer(feeCollector, fee), "NFTMarket: fee transfer failed");
        }

        // 转移 NFT
        IERC721(nftContract).transferFrom(listing.seller, msg.sender, tokenId);
        
        // 更新上架状态
        listing.isActive = false;

        emit NFTSold(nftContract, tokenId, msg.sender, listing.price);
    }

    /**
     * @dev 实现 ITokenReceiver 接口，处理 NFT 购买
     */
    function tokensReceived(
        address sender,
        address token,
        uint256 amount,
        bytes calldata data
    ) external override returns (bool) {
        // 确保只能由代币合约调用
        // console.log("NFTMarket Contract by:", address(this)); 
        // console.log("sender by:", sender); 

        require(msg.sender == token, "NFTMarket: only token contract can call");
      
        // 解码数据
        (address nftContract, uint256 tokenId) = abi.decode(data, (address, uint256));
        
        Listing storage listing = _listings[nftContract][tokenId];
        // console.log("listing.seller: ", listing.seller); 

        require(listing.seller != sender, "NFTMarket: cannot buy your own NFT");

        require(listing.isActive, "NFTMarket: NFT not for sale");
       
        require(amount >= listing.price, "NFTMarket: insufficient payment");

        // 计算手续费
        uint256 fee = (listing.price * feePercentage) / 10000;
        uint256 sellerAmount = listing.price - fee;

        // 转移 NFT
        IERC721(nftContract).transferFrom(listing.seller, sender, tokenId);

        // 转移代币给卖家
        IERC20(token).transfer(listing.seller, sellerAmount);

        // 转移手续费给平台
        if (fee > 0) {
            IERC20(token).transfer(feeCollector, fee);
        }

        // 更新上架状态
        listing.isActive = false;

        emit NFTSold(nftContract, tokenId, sender, listing.price);
        return true;
    }

    /**
     * @dev 取消上架
     * @param nftContract NFT合约地址
     * @param tokenId NFT的ID
     */
    function unlist(address nftContract, uint256 tokenId) external nonReentrant {
        Listing storage listing = _listings[nftContract][tokenId];
        require(listing.seller == msg.sender, "NFTMarket: not the seller");
        require(listing.isActive, "NFTMarket: NFT not for sale");

        listing.isActive = false;
        emit NFTUnlisted(nftContract, tokenId, msg.sender);
    }

    /**
     * @dev 获取 NFT 上架信息
     * @param nftContract NFT合约地址
     * @param tokenId NFT的ID
     * @return seller 卖家地址
     * @return price 价格
     * @return isActive 是否在售
     */
    function getListing(address nftContract, uint256 tokenId) external view returns (
        address seller,
        uint256 price,
        bool isActive
    ) {
        Listing storage listing = _listings[nftContract][tokenId];
        return (listing.seller, listing.price, listing.isActive);
    }
} 