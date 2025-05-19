// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/NFTMarketGasOptimization.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockNFT is ERC721 {
    constructor() ERC721("MockNFT", "MNFT") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

contract NFTMarketGasOptimizationTest is Test {
    NFTMarketGasOptimization public market;
    MockNFT public nft;
    address public seller = address(1);
    address public buyer = address(2);
    address public owner = makeAddr("0xowner");

    function setUp() public {
        market = new NFTMarketGasOptimization();
        nft = new MockNFT();
        
        // Mint NFT to seller
        nft.mint(seller, 1);
        
        // Setup balances
        vm.deal(seller, 10 ether);
        vm.deal(buyer, 10 ether);
    }

    function test_ListNFT() public {
        vm.startPrank(seller);
        nft.approve(address(market), 1);
        market.list(address(nft), 1, uint96(1 ether));
        vm.stopPrank();
    }

    function test_BuyNFT() public {
        // First list the NFT
        vm.startPrank(seller);
        nft.approve(address(market), 1);
        market.list(address(nft), 1, uint96(1 ether));
        vm.stopPrank();

        // Then buy it
        vm.startPrank(buyer);
        market.buyNFT{value: 1 ether}(address(nft), 1);
        vm.stopPrank();
    }

    function test_UnlistNFT() public {
        vm.startPrank(seller);
        nft.approve(address(market), 1);
        market.list(address(nft), 1, uint96(1 ether));
        market.unlist(address(nft), 1);
        vm.stopPrank();
    }

    function test_UpdateFeePercentage() public {
        market.updateFeePercentage(300); // 3%
    }

    function test_WithdrawFees() public {
        // First list and buy NFT to generate fees
        vm.startPrank(seller);
        nft.approve(address(market), 1);
        market.list(address(nft), 1, uint96(1 ether));
        vm.stopPrank();

        vm.startPrank(buyer);
        market.buyNFT{value: 1 ether}(address(nft), 1);
        vm.stopPrank();

        // Then withdraw fees
        market.withdrawFees(owner, 0.025 ether);
    }

    function test_GetListing() public {
        // First list the NFT
        vm.startPrank(seller);
        nft.approve(address(market), 1);
        market.list(address(nft), 1, uint96(1 ether));
        vm.stopPrank();

        // Get listing info
        (address seller_, uint96 price, bool isActive) = market.getListing(address(nft), 1);
        assertEq(seller_, seller);
        assertEq(price, 1 ether);
        assertTrue(isActive);
    }

    function test_RevertWhen_ListWithInvalidPrice() public {
        vm.startPrank(seller);
        nft.approve(address(market), 1);
        vm.expectRevert("NFTMarket: price must be greater than 0");
        market.list(address(nft), 1, 0); // Should fail with price = 0
        vm.stopPrank();
    }

    function test_RevertWhen_BuyWithInsufficientPayment() public {
        // First list the NFT
        vm.startPrank(seller);
        nft.approve(address(market), 1);
        market.list(address(nft), 1, uint96(1 ether));
        vm.stopPrank();

        // Try to buy with insufficient payment
        vm.startPrank(buyer);
        vm.expectRevert("NFTMarket: insufficient payment");
        market.buyNFT{value: 0.5 ether}(address(nft), 1); // Should fail
        vm.stopPrank();
    }
} 