// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Multicall.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

contract AirdopMerkleNFTMarket is ReentrancyGuard, Ownable, Multicall {
    struct Listing {
        address seller;        // 卖家地址
        uint96 price;         // 价格（ETH数量）
        bool isActive;        // 是否在售
    }

    // 存储 NFT 上架信息
    // nftContract => tokenId => Listing
    mapping(address => mapping(uint256 => Listing)) private _listings;
    
    // Merkle 树根
    bytes32 public merkleRoot;
    
    // ERC20 Permit Token
    address public immutable permitToken;
    
    // 白名单用户支付代币数量
    uint256 public whitelistTokenAmount;
    
    uint16 public feePercentage = 250; // 2.5%

    // 优化：减少事件索引字段数量，只保留最重要的索引
    event NFTListed(address indexed nftContract, uint256 indexed tokenId, address seller, uint96 price);
    event NFTSold(address indexed nftContract, uint256 indexed tokenId, address buyer, uint96 price);
    event NFTUnlisted(address indexed nftContract, uint256 indexed tokenId, address seller);
    event FeesWithdrawn(address to, uint256 amount);
    event FeePercentageUpdated(uint16 oldPercentage, uint16 newPercentage);
    event MerkleRootUpdated(bytes32 newRoot);
    event PermitTokenUpdated(address indexed oldToken, address indexed newToken);
    event WhitelistTokenAmountUpdated(uint256 oldAmount, uint256 newAmount);

    constructor(
        address _permitToken,
        uint256 _whitelistTokenAmount
    ) Ownable(msg.sender) {
        permitToken = _permitToken;
        whitelistTokenAmount = _whitelistTokenAmount;
    }

    /**
     * @dev 设置 Merkle 树根
     * @param _merkleRoot 新的 Merkle 树根
     */
    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
        emit MerkleRootUpdated(_merkleRoot);
    }

    /**
     * @dev 更新白名单用户支付代币数量
     * @param _amount 新的代币数量
     */
    function setWhitelistTokenAmount(uint256 _amount) external onlyOwner {
        uint256 oldAmount = whitelistTokenAmount;
        whitelistTokenAmount = _amount;
        emit WhitelistTokenAmountUpdated(oldAmount, _amount);
    }

    /**
     * @dev 验证地址是否在白名单中
     * @param account 要验证的地址
     * @param proof Merkle 证明
     */
    function isWhitelisted(address account, bytes32[] calldata proof) public view returns (bool) {
        bytes32 node = keccak256(abi.encodePacked(account));
        return MerkleProof.verify(proof, merkleRoot, node);
    }

    /**
     * @dev 使用 Permit 进行代币授权和转账
     * @param owner 代币所有者
     * @param spender 被授权地址
     * @param value 授权数量
     * @param deadline 过期时间
     * @param v 签名 v 值
     * @param r 签名 r 值
     * @param s 签名 s 值
     */
    function permitPrePay(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // 1. 执行 Permit 授权
        IERC20Permit(permitToken).permit(owner, spender, value, deadline, v, r, s);
        
        // 2. 转移代币到合约
        require(
            IERC20(permitToken).transferFrom(owner, address(this), whitelistTokenAmount),
            "Token transfer failed"
        );
    }

    /**
     * @dev 白名单用户购买 NFT（只需要支付50%的ETH + 白名单用户支付的Permit Token）
     * @param nftContract NFT合约地址
     * @param tokenId NFT的ID
     * @param proof Merkle 证明
     */
    function claimNFT(
        address nftContract,
        uint256 tokenId,
        bytes32[] calldata proof
    ) external payable nonReentrant {
        // 1. 验证白名单
        require(isWhitelisted(msg.sender, proof), "Not in whitelist");
        
        // 2. 验证 NFT 状态
        Listing storage listing = _listings[nftContract][tokenId];
        require(listing.isActive, "NFT not for sale");
        require(listing.seller != msg.sender, "Cannot buy your own NFT");

        // 3. 验证 ETH 支付
        uint256 discountedPrice = uint256(listing.price) / 2;
        require(msg.value >= discountedPrice, "Insufficient ETH payment");

        // 4. 计算手续费和卖家收入
        uint256 fee;
        uint256 sellerAmount;
        unchecked {
            fee = (discountedPrice * feePercentage) / 10000;
            sellerAmount = discountedPrice - fee;
        }

        // 5. 更新状态
        listing.isActive = false;

        // 6. 转移 NFT
        IERC721(nftContract).transferFrom(listing.seller, msg.sender, tokenId);

        // 7. 转移 ETH 给卖家
        (bool success, ) = listing.seller.call{value: sellerAmount}("");
        require(success, "Failed to transfer ETH to seller");

        // 8. 退还多余的 ETH
        if (msg.value > discountedPrice) {
            unchecked {
                (success, ) = msg.sender.call{value: msg.value - discountedPrice}("");
            }
            require(success, "Failed to refund excess ETH");
        }

        emit NFTSold(nftContract, tokenId, msg.sender, uint96(discountedPrice));
    }

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

    /**
     * @dev 提取合约中的代币
     */
    function withdrawTokens() external onlyOwner {
        uint256 balance = IERC20(permitToken).balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        require(IERC20(permitToken).transfer(owner(), balance), "Token transfer failed");
    }

    // 允许合约接收 ETH
    receive() external payable {}
} 