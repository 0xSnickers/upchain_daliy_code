// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {NFTMarket} from "../src/NFTMarket.sol";
import {BaseERC721} from "../src/BaseERC721.sol";
import {MyToken} from "../src/MyToken.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract NFTMarketTest is Test {
    NFTMarket public market;
    BaseERC721 public nft;
    MyToken public token;
    address public feeCollector;
    address public seller;
    address public buyer;
    uint256 public constant PRICE = 100 * 10 ** 18; // 100 tokens

    event NFTListed(
        address indexed nftContract,
        uint256 indexed tokenId,
        address indexed seller,
        uint256 price
    );
    event NFTSold(
        address indexed nftContract,
        uint256 indexed tokenId,
        address indexed buyer,
        uint256 price
    );

    function setUp() public {
        string memory privateKey = vm.envString("PRIVATE_KEY_LOCAL");
        string memory rpcUrl = vm.rpcUrl("local");
        console.log("privateKey => %s", privateKey);
        console.log("rpcUrl => %s", rpcUrl);
        feeCollector = makeAddr("feeCollector");
        seller = makeAddr("seller");
        buyer = makeAddr("buyer");

        // 部署合约
        nft = new BaseERC721("APizzaNFT","APZNFT","");
        token = new MyToken("APizza","APZ");
        market = new NFTMarket(feeCollector);
 

        // 给测试账户分配代币
        token.transfer(seller, 1000 * 10 ** 18);
        token.transfer(buyer, 1000 * 10 ** 18);

        // 给卖家铸造 NFT
        nft.mint(seller, 1);
    }
    // 测试成功上架，验证事件和状态
    function test_ListNFT_Success() public {
        console.logString(unicode"测试成功上架，验证事件和状态 => ");
        vm.startPrank(seller);
        nft.approve(address(market), 1);

        vm.expectEmit(true, true, true, true);
        emit NFTListed(address(nft), 1, seller, PRICE);

        market.list(address(nft), 1, PRICE);

        (address listingSeller, uint256 listingPrice, bool isActive) = market
            .getListing(address(nft), 1);
        assertEq(listingSeller, seller);
        assertEq(listingPrice, PRICE);
        assertTrue(isActive);
        vm.stopPrank();
    }

    // 测试失败上架，验证错误信息
    function test_ListNFT_Fail_NotOwner() public {
        console.logString(unicode"测试失败上架，验证错误信息 => ");

        vm.startPrank(buyer);
        vm.expectRevert("NFTMarket: not the owner");
        market.list(address(nft), 1, PRICE);
        vm.stopPrank();
    }
    //  测试未授权上架失败
    function test_ListNFT_Fail_NotApproved() public {
        console.log(unicode"测试未授权上架失败 => ");

        vm.startPrank(seller);
        vm.expectRevert("NFTMarket: not approved");
        market.list(address(nft), 1, PRICE);
        vm.stopPrank();
    }

    // 测试价格为0上架失败
    function test_ListNFT_Fail_ZeroPrice() public {
        console.log(unicode"测试价格为0上架失败 => ");

        vm.startPrank(seller);
        nft.approve(address(market), 1);
        vm.expectRevert("NFTMarket: price must be greater than 0");
        market.list(address(nft), 1, 0);
        vm.stopPrank();
    }

    // 测试成功购买，验证事件和状态
    function test_BuyNFT_Success() public {
        console.log(unicode"测试成功购买，验证事件和状态 => ");

        // 先上架 NFT
        vm.startPrank(seller);
        nft.approve(address(market), 1);
        market.list(address(nft), 1, PRICE);
        vm.stopPrank();

        // 买家购买
        vm.startPrank(buyer);
        token.approve(address(market), PRICE);

        vm.expectEmit(true, true, true, true);
        emit NFTSold(address(nft), 1, buyer, PRICE);

        token.transferWithCallback(
            address(market),
            PRICE,
            abi.encode(address(nft), 1)
        );

        assertEq(nft.ownerOf(1), buyer);
        (, , bool isActive) = market.getListing(address(nft), 1);
        assertFalse(isActive);
        vm.stopPrank();
    }
    // 测试购买自己的NFT失败
    function test_BuyNFT_Fail_BuyOwnNFT() public {
        console.log(unicode"测试购买自己的NFT失败 => ");

        vm.startPrank(seller);
        nft.approve(address(market), 1);
        market.list(address(nft), 1, PRICE);

        token.approve(address(market), PRICE);
        vm.expectRevert("NFTMarket: cannot buy your own NFT");
        // vm.expectRevert(NFTMarket.CallbackFailed.selector);
        token.transferWithCallback(
            address(market),
            PRICE,
            abi.encode(address(nft), 1)
        );
        vm.stopPrank();
    }
    
    // 测试支付不足失败
    function test_BuyNFT_Fail_InsufficientPayment() public {
        console.log(unicode"测试支付不足失败 => ");

        // 先上架 NFT
        vm.startPrank(seller);
        nft.approve(address(market), 1);
        market.list(address(nft), 1, PRICE);
        vm.stopPrank();

        // 买家支付不足
        vm.startPrank(buyer);
        token.approve(address(market), PRICE - 1);
        vm.expectRevert("NFTMarket: insufficient payment");

        token.transferWithCallback(
            address(market),
            PRICE - 1,
            abi.encode(address(nft), 1)
        );
        vm.stopPrank();
    }
    // 测试NFT已售出失败
    function test_BuyNFT_Fail_AlreadySold() public {
        console.log(unicode"测试NFT已售出失败 => ");

        // 先上架 NFT
        vm.startPrank(seller);
        nft.approve(address(market), 1);
        market.list(address(nft), 1, PRICE);
        vm.stopPrank();

        // 第一个买家购买
        vm.startPrank(buyer);
        token.approve(address(market), PRICE);
        token.transferWithCallback(
            address(market),
            PRICE,
            abi.encode(address(nft), 1)
        );
        vm.stopPrank();

        // 第二个买家尝试购买
        address buyer2 = makeAddr("buyer2");
        token.transfer(buyer2, PRICE);
        vm.startPrank(buyer2);
        token.approve(address(market), PRICE);
        vm.expectRevert("NFTMarket: NFT not for sale");

        token.transferWithCallback(
            address(market),
            PRICE,
            abi.encode(address(nft), 1)
        );
        vm.stopPrank();
    }
    // 测试支付超额成功
    function test_BuyNFT_Success_ExcessPayment() public {
        console.log(unicode"测试支付超额成功 => ");
        
        // 先上架 NFT
        vm.startPrank(seller);
        nft.approve(address(market), 1);
        market.list(address(nft), 1, PRICE);
        vm.stopPrank();

        // 买家支付超额
        vm.startPrank(buyer);
        token.approve(address(market), PRICE * 2);
        token.transferWithCallback(
            address(market),
            PRICE * 2,
            abi.encode(address(nft), 1)
        );

        assertEq(nft.ownerOf(1), buyer);
        (, , bool isActive) = market.getListing(address(nft), 1);
        assertFalse(isActive);
        vm.stopPrank();
    }
}
