// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/NFTMarket/NFTMarket.sol";
import "../src/NFTMarket/MyERC721Enumerable.sol";
// import "../src/NFTMarket/BaseERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTMarketTest is Test {
    NFTMarket public market;
    // BaseERC721 public nft;
    MyERC721Enumerable public nft;
    
    address public owner;
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public treasury = makeAddr("treasury"); // 添加一个接收手续费的地址
    
    uint256 public constant NFT_PRICE = 1 ether;
    
    event NFTListed(address indexed nftContract, uint256 indexed tokenId, address indexed seller, uint256 price);
    event NFTSold(address indexed nftContract, uint256 indexed tokenId, address indexed buyer, uint256 price);
    event NFTUnlisted(address indexed nftContract, uint256 indexed tokenId, address indexed seller);
    event FeesWithdrawn(address indexed to, uint256 amount);
    event FeePercentageUpdated(uint256 oldPercentage, uint256 newPercentage);
    
    
    function setUp() public {
        // 设置合约部署者为当前测试合约地址
        owner = address(this);
        
        // 部署合约
        nft = new MyERC721Enumerable("Test NFT", "TNFT", "ipfs://test/");
        market = new NFTMarket();
        
        // 给测试账户分配 ETH
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(treasury, 10 ether); // 给 treasury 也分配一些 ETH
        
        // 给测试账户铸造 NFT
        nft.mint(alice);
        nft.mint(alice);
        nft.mint(bob);
        
        // 切换到 Alice
        vm.startPrank(alice);
        // 授权 NFT 给市场合约
        nft.setApprovalForAll(address(market), true);
        // 切换到 Bob
        vm.stopPrank();
        vm.startPrank(bob);
        nft.setApprovalForAll(address(market), true);
        vm.stopPrank();
    }
    
    function testWithdrawFees() public {
        // 先进行一笔交易以产生手续费
        vm.startPrank(alice);
        market.list(address(nft), 0, NFT_PRICE);
        vm.stopPrank();
        
        vm.startPrank(bob);
        market.buyNFT{value: NFT_PRICE}(address(nft), 0);
        vm.stopPrank();
        
        uint256 fee = (NFT_PRICE * market.feePercentage()) / 10000;
        uint256 treasuryInitialBalance = treasury.balance;
        
        console.log("testWithdrawFees: fee => ", fee);
        console.log("testWithdrawFees: treasuryInitialBalance => ", treasuryInitialBalance);
        console.log("testWithdrawFees: market balance => ", address(market).balance);
        console.log("testWithdrawFees: totalFees => ", address(market).balance);
        
        // 提取手续费到 treasury 地址
        market.withdrawFees(treasury, fee);
        
        // 验证余额变化
        assertEq(treasury.balance - treasuryInitialBalance, fee);
        assertEq(address(market).balance, 0);
        assertEq(address(market).balance, 0);
    }
    
    // BaseERC721 测试
    function testNFTMint() public view {
        assertEq(nft.ownerOf(0), alice);
        assertEq(nft.ownerOf(1), alice);
        assertEq(nft.ownerOf(2), bob);
    }
    
    function testNFTURI() public view {
        assertEq(nft.tokenURI(0), "ipfs://test/0");
        assertEq(nft.tokenURI(1), "ipfs://test/1");
    }
    
    function testSetBaseURI() public {
        string memory newURI = "ipfs://new/";
        nft.setBaseURI(newURI);
        assertEq(nft.tokenURI(0), "ipfs://new/0");
    }
    
    // NFTMarket 测试
    function testListNFT() public {
        vm.startPrank(alice);
        
        // 上架 NFT
        market.list(address(nft), 0, NFT_PRICE);
        
        // 验证上架信息
        (address seller, uint256 price, bool isActive) = market.getListing(address(nft), 0);
        assertEq(seller, alice);
        assertEq(price, NFT_PRICE);
        assertTrue(isActive);
        
        vm.stopPrank();
    }
    
    function testBuyNFT() public {
        vm.startPrank(alice);
        // 上架 NFT
        market.list(address(nft), 0, NFT_PRICE);
        vm.stopPrank();
        
        vm.startPrank(bob);
        // 记录初始余额
        uint256 aliceInitialBalance = alice.balance;
        uint256 marketInitialBalance = address(market).balance;
        uint256 bobInitialBalance = bob.balance;
        
        // 购买 NFT
        market.buyNFT{value: NFT_PRICE}(address(nft), 0);
        
        // 验证 NFT 所有权已转移
        assertEq(nft.ownerOf(0), bob);
        
        // 验证 ETH 余额变化
        uint256 fee = (NFT_PRICE * market.feePercentage()) / 10000;
        uint256 sellerAmount = NFT_PRICE - fee;
        
        // 验证卖家收到的 ETH
        assertEq(alice.balance - aliceInitialBalance, sellerAmount);
        // 验证市场合约收到的 ETH
        assertEq(address(market).balance - marketInitialBalance, fee);
        // 验证买家支付的 ETH
        assertEq(bobInitialBalance - bob.balance, NFT_PRICE);
        // 验证累计手续费
        assertEq(address(market).balance, fee);
        
        vm.stopPrank();
    }
    
    function testBuyNFTWithExcessETH() public {
        vm.startPrank(alice);
        // 上架 NFT
        market.list(address(nft), 0, NFT_PRICE);
        vm.stopPrank();
        
        vm.startPrank(bob);
        // 记录初始余额
        uint256 aliceInitialBalance = alice.balance;
        uint256 marketInitialBalance = address(market).balance;
        uint256 bobInitialBalance = bob.balance;
        
        // 使用超过价格的 ETH 购买
        uint256 excessAmount = 0.1 ether;
        market.buyNFT{value: NFT_PRICE + excessAmount}(address(nft), 0);
        
        // 验证 NFT 所有权已转移
        assertEq(nft.ownerOf(0), bob);
        
        // 验证 ETH 余额变化
        uint256 fee = (NFT_PRICE * market.feePercentage()) / 10000;
        uint256 sellerAmount = NFT_PRICE - fee;
        
        // 验证卖家收到的 ETH
        assertEq(alice.balance - aliceInitialBalance, sellerAmount);
        // 验证市场合约收到的 ETH
        assertEq(address(market).balance - marketInitialBalance, fee);
        // 验证买家支付的 ETH（包括返还的 excess）
        assertEq(bobInitialBalance - bob.balance, NFT_PRICE);
        // 验证累计手续费
        assertEq(address(market).balance, fee);
        
        vm.stopPrank();
    }
    
    function testUnlistNFT() public {
        vm.startPrank(alice);
        // 上架 NFT
        market.list(address(nft), 0, NFT_PRICE);
        // 取消上架
        market.unlist(address(nft), 0);
        
        // 验证上架状态
        (,, bool isActive) = market.getListing(address(nft), 0);
        assertFalse(isActive);
        
        vm.stopPrank();
    }
    
   
    
    function testUpdateFeePercentage() public {
        uint256 newFeePercentage = 300; // 3%
        
        // 更新手续费百分比（当前合约是 owner，不需要 prank）
        market.updateFeePercentage(newFeePercentage);
        assertEq(market.feePercentage(), newFeePercentage);
        
        // 测试更新失败情况
        vm.expectRevert("NFTMarket: fee percentage too high");
        market.updateFeePercentage(1001); // 超过 10%
    }
    
    function test_RevertWhen_BuyingOwnNFT() public {
        vm.startPrank(alice);
        // 上架 NFT
        market.list(address(nft), 0, NFT_PRICE);
        // 尝试购买自己的 NFT
        vm.expectRevert("NFTMarket: cannot buy your own NFT");
        market.buyNFT{value: NFT_PRICE}(address(nft), 0);
        vm.stopPrank();
    }
    
    function test_RevertWhen_BuyingInactiveNFT() public {
        vm.startPrank(alice);
        // 上架 NFT
        market.list(address(nft), 0, NFT_PRICE);
        // 取消上架
        market.unlist(address(nft), 0);
        vm.stopPrank();
        
        vm.startPrank(bob);
        // 尝试购买已取消上架的 NFT
        vm.expectRevert("NFTMarket: NFT not for sale");
        market.buyNFT{value: NFT_PRICE}(address(nft), 0);
        vm.stopPrank();
    }
    
    function test_RevertWhen_BuyingWithInsufficientPayment() public {
        vm.startPrank(alice);
        // 上架 NFT
        market.list(address(nft), 0, NFT_PRICE);
        vm.stopPrank();
        
        vm.startPrank(bob);
        // 尝试用不足的 ETH 购买
        vm.expectRevert("NFTMarket: insufficient payment");
        market.buyNFT{value: NFT_PRICE - 0.1 ether}(address(nft), 0);
        vm.stopPrank();
    }
    
    function test_RevertWhen_UnlistingOthersNFT() public {
        vm.startPrank(alice);
        // 上架 NFT
        market.list(address(nft), 0, NFT_PRICE);
        vm.stopPrank();
        
        vm.startPrank(bob);
        // 尝试取消他人的 NFT 上架
        vm.expectRevert("NFTMarket: not the seller");
        market.unlist(address(nft), 0);
        vm.stopPrank();
    }

    function test_RevertWhen_WithdrawingFeesNotOwner() public {
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        market.withdrawFees(treasury, 1 ether);
        vm.stopPrank();
    }
    
    function test_RevertWhen_WithdrawingInsufficientFees() public {
        // 当前合约是 owner，不需要 prank
        vm.expectRevert("NFTMarket: insufficient balance");
        market.withdrawFees(treasury, 1 ether);
    }
} 