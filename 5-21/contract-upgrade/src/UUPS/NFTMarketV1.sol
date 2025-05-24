// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

// 无签名上架功能
contract NFTMarketV1 is 
    Initializable, 
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable 
     {
    // 优化：使用 uint96 存储价格，因为 ETH 价格不会超过 2^96
    // 优化：将 isActive 和 price 打包到同一个存储槽中
    struct Listing {
        address seller;        // 卖家地址
        uint96 price;         // 价格（ETH数量）
        bool isActive;        // 是否在售
    }

    // 存储 NFT 上架信息
    // nftContract => tokenId => Listing
    mapping(address => mapping(uint256 => Listing)) private _listings;
    
    // 优化：使用 uint16 存储手续费百分比，因为不会超过 1000 (10%)
    uint16 public feePercentage = 250; // 2.5%

    // 优化：减少事件索引字段数量，只保留最重要的索引
    event NFTListed(address indexed nftContract, uint256 indexed tokenId, address seller, uint96 price);
    event NFTSold(address indexed nftContract, uint256 indexed tokenId, address buyer, uint96 price);
    event NFTUnlisted(address indexed nftContract, uint256 indexed tokenId, address seller);
    event FeesWithdrawn(address to, uint256 amount);
    event FeePercentageUpdated(uint16 oldPercentage, uint16 newPercentage);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        // 使用UUPS代理后，禁止初始化
        _disableInitializers();
    }
    // 初始化
    function initialize() public initializer {
        __ReentrancyGuard_init();
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        feePercentage = 250;
    }

    // 授权升级
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @dev 上架 NFT
     * @param nftContract NFT合约地址
     * @param tokenId NFT的ID
     * @param price 价格（ETH数量）
     */
    function list(address nftContract, uint256 tokenId, uint96 price) external nonReentrant {
        require(price > 0, "NFTMarket: price must be greater than 0");
        
        // 优化：缓存 ownerOf 和 getApproved 的结果
        address owner = IERC721(nftContract).ownerOf(tokenId);
        require(owner == msg.sender, "NFTMarket: not the owner");
        
        address approved = IERC721(nftContract).getApproved(tokenId);
        bool isApprovedForAll = IERC721(nftContract).isApprovedForAll(msg.sender, address(this));
        require(approved == address(this) || isApprovedForAll, "NFTMarket: not approved");

        _listings[nftContract][tokenId] = Listing({
            seller: msg.sender,
            price: price,
            isActive: true
        });

        emit NFTListed(nftContract, tokenId, msg.sender, price);
    }

    function _verificationBuyNFT(
        address nftContract, 
        uint256 tokenId, 
        uint256 amount, 
        address buyer
    ) internal view {
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
        
        // 优化：使用 unchecked 块进行数学计算
        uint256 fee;
        uint256 sellerAmount;
        unchecked {
            fee = (uint256(listing.price) * feePercentage) / 10000;
            sellerAmount = listing.price - fee;
        }
        
        // 优化：先更新状态，再执行外部调用
        listing.isActive = false;
        
        // 转移 NFT
        IERC721(nftContract).transferFrom(listing.seller, msg.sender, tokenId);

        // 转移 ETH 给卖家
        (bool success, ) = listing.seller.call{value: sellerAmount}("");
        require(success, "NFTMarket: failed to transfer ETH to seller");

        // 优化：使用 unchecked 块进行退款计算
        if (msg.value > listing.price) {
            unchecked {
                (success, ) = msg.sender.call{value: msg.value - listing.price}("");
            }
            require(success, "NFTMarket: failed to refund excess ETH");
        }

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
    function getListing(
        address nftContract, 
        uint256 tokenId
    ) external view returns (address seller, uint96 price, bool isActive) {
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