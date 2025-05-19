// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "forge-std/console.sol";

contract NFTMarket is ReentrancyGuard, Ownable {
    // NFT 上架信息结构
    struct Listing {
        address seller;        // 卖家地址
        uint256 price;         // 价格（ETH数量）
        bool isActive;         // 是否在售
    }

    // 存储 NFT 上架信息
    // nftContract => tokenId => Listing
    mapping(address => mapping(uint256 => Listing)) private _listings;
    // 存储平台收取的手续费（百分比）
    uint256 public feePercentage = 250; // 2.5%

    // 事件定义
    event NFTListed(address indexed nftContract, uint256 indexed tokenId, address indexed seller, uint256 price);
    event NFTSold(address indexed nftContract, uint256 indexed tokenId, address indexed buyer, uint256 price);
    event NFTUnlisted(address indexed nftContract, uint256 indexed tokenId, address indexed seller);
    event FeesWithdrawn(address indexed to, uint256 amount);
    event FeePercentageUpdated(uint256 oldPercentage, uint256 newPercentage);

    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev 更新手续费百分比
     * @param newFeePercentage 新的手续费百分比（基点，如 250 表示 2.5%）
     */
    function updateFeePercentage(uint256 newFeePercentage) external onlyOwner {
        require(newFeePercentage <= 1000, "NFTMarket: fee percentage too high"); // 最高 10%
        uint256 oldPercentage = feePercentage;
        feePercentage = newFeePercentage;
        emit FeePercentageUpdated(oldPercentage, newFeePercentage);
    }

    /**
     * @dev 上架 NFT
     * @param nftContract NFT合约地址
     * @param tokenId NFT的ID
     * @param price 价格（ETH数量）
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

    function _verificationBuyNFT(address nftContract, uint256 tokenId, uint256 amount, address buyer) internal view {
        Listing storage listing = _listings[nftContract][tokenId];
        require(amount >= listing.price, "NFTMarket: insufficient payment");
        require(listing.isActive, "NFTMarket: NFT not for sale");
        require(listing.seller != buyer, "NFTMarket: cannot buy your own NFT");
    }

    /**
     * @dev 购买 NFT
     * @param nftContract NFT合约地址
     * @param tokenId NFT的ID
     */
    function buyNFT(address nftContract, uint256 tokenId) external payable nonReentrant {
        Listing storage listing = _listings[nftContract][tokenId];
     
        _verificationBuyNFT(nftContract, tokenId, msg.value, msg.sender);
        
        // 计算手续费
        uint256 fee = (listing.price * feePercentage) / 10000;
        uint256 sellerAmount = listing.price - fee;
        
        // 转移 NFT
        IERC721(nftContract).transferFrom(listing.seller, msg.sender, tokenId);

        // 转移 ETH 给卖家
        (bool success, ) = listing.seller.call{value: sellerAmount}("");
        require(success, "NFTMarket: failed to transfer ETH to seller");

        // 如果有多余的 ETH，返还给买家
        if (msg.value > listing.price) {
            (success, ) = msg.sender.call{value: msg.value - listing.price}("");
            require(success, "NFTMarket: failed to refund excess ETH");
        }

        listing.isActive = false;

        emit NFTSold(nftContract, tokenId, msg.sender, listing.price);
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

    /**
     * @dev 提取合约中的手续费
     * @param to 接收地址
     * @param amount 提取数量
     */
    function withdrawFees(address to, uint256 amount) external onlyOwner nonReentrant {
        require(to != address(0), "NFTMarket: invalid address");
        require(amount > 0, "NFTMarket: amount must be greater than 0");
        require(amount <= address(this).balance, "NFTMarket: insufficient balance");
        require(to.code.length == 0, "NFTMarket: recipient cannot be a contract");
        (bool success, ) = to.call{value: amount}("");
        require(success, "NFTMarket: failed to withdraw fees");

        emit FeesWithdrawn(to, amount);
    }

    // 允许合约接收 ETH
    receive() external payable {}
} 