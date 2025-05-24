// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/UUPS/NFTMarketV1.sol";
import "../src/UUPS/NFTMarketV2.sol";
import "../src/UUPS/ERC721WithSignatureV1.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

contract DeployUUPSTest is Test {
    NFTMarketV1 public implementation;
    NFTMarketV1 public proxy;
    ERC721WithSignatureV1 public nft;
    ERC721WithSignatureV1 public nftImplementation;
    address public owner;
    address public seller;
    address public buyer;
    uint256 public sellerPrivateKey;
    
    function setUp() public {
        // 设置测试账户
        owner = address(this);
        (seller, sellerPrivateKey) = makeAddrAndKey("seller");
        buyer = makeAddr("buyer");
        
        // 部署 NFT 实现合约
        nftImplementation = new ERC721WithSignatureV1();
        
        // 编码 NFT 初始化数据
        bytes memory nftInitData = abi.encodeWithSelector(
            ERC721WithSignatureV1.initialize.selector,
            "Test NFT",
            "TNFT",
            "ipfs://test/"
        );
        
        // 部署 NFT 代理合约
        ERC1967Proxy nftProxy = new ERC1967Proxy(
            address(nftImplementation),
            nftInitData
        );
        
        // 将代理合约转换为实现合约接口
        nft = ERC721WithSignatureV1(address(nftProxy));
        
        // 部署市场实现合约
        implementation = new NFTMarketV1();
        
        // 编码市场初始化数据
        bytes memory initData = abi.encodeWithSelector(
            NFTMarketV1.initialize.selector
        );
        
        // 部署市场代理合约
        ERC1967Proxy proxyContract = new ERC1967Proxy(
            address(implementation),
            initData
        );
        
        // 将代理合约转换为实现合约接口
        proxy = NFTMarketV1(payable(address(proxyContract)));
        
        // 设置账户余额
        vm.deal(seller, 10 ether);
        vm.deal(buyer, 10 ether);

        // 验证 NFT 合约初始化
        assertEq(nft.owner(), address(this), "NFT contract owner should be test contract");
    }

    function test_Initialization() public view {
        assertEq(proxy.owner(), address(this));
        assertEq(proxy.feePercentage(), 250); // 默认费率为2.5%
    }

    function test_ListAndBuyNFT() public {
        // 铸造NFT给卖家
        vm.prank(owner);  // 需要用owner权限来铸造
        nft.mint(seller);  // 直接铸造给seller地址
        
        uint96 price = 1 ether;
        
        vm.startPrank(seller);
        // 授权市场合约
        nft.approve(address(proxy), 0);  // 使用 tokenId 0
        // 上架NFT
        proxy.list(address(nft), 0, price);  // 使用 tokenId 0
        vm.stopPrank();
        
        // 验证上架信息
        (address listedSeller, uint96 listedPrice, bool isActive) = proxy.getListing(address(nft), 0);  // 使用 tokenId 0
        assertEq(listedSeller, seller);
        assertEq(listedPrice, price);
        assertTrue(isActive);
        
        // 买家购买NFT
        vm.startPrank(buyer);
        proxy.buyNFT{value: price}(address(nft), 0);  // 使用 tokenId 0
        vm.stopPrank();
        
        // 验证NFT所有权转移
        assertEq(nft.ownerOf(0), buyer);  // 使用 tokenId 0
        
        // 验证上架状态更新
        (, , isActive) = proxy.getListing(address(nft), 0);  // 使用 tokenId 0
        assertFalse(isActive);
    }
    // 测试升级 NFTMarketV1 -> NFTMarketV2
    function test_Upgrade() public {
        // 部署新版本实现
        NFTMarketV2 implementationV2 = new NFTMarketV2();
        
        // 打印当前合约所有者和调用者地址，用于调试
        console.log("Current owner:", proxy.owner());
        console.log("Current caller (this):", address(this));
        console.log("NFT contract owner:", nft.owner());
        
        // 确保使用合约所有者账户进行升级
        vm.prank(owner);
        proxy.upgradeToAndCall(address(implementationV2), "");  // 直接在 proxy 上调用 upgradeToAndCall
        
        // 将代理合约转换为V2接口
        NFTMarketV2 proxyV2 = NFTMarketV2(payable(address(proxy)));
        
        // 测试V2新增的签名上架功能
        uint96 price = 1 ether;
        uint256 deadline = block.timestamp + 1 hours;
        
        // 铸造NFT给卖家
        console.log("Minting NFT to seller:", seller);
        nft.mint(seller);  // 直接铸造给seller地址，因为测试合约就是owner
        
        // 验证NFT已成功铸造
        assertEq(nft.ownerOf(0), seller, "NFT should be minted to seller");  // 使用 tokenId 0
        
        vm.startPrank(seller);
        // 授权市场合约
        nft.setApprovalForAll(address(proxyV2), true);  // 使用 setApprovalForAll 替代 approve
        
        // 获取签名者的 nonce
        uint256 nonce = proxyV2.nonces(seller);
        
        // 构造签名消息
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("List(address nftContract,uint256 tokenId,uint96 price,uint256 nonce,uint256 deadline)"),
                address(nft),
                0,  // 使用 tokenId 0
                price,
                nonce,
                deadline
            )
        );
        
        // 使用 ECDSA 直接签名消息
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                proxyV2.DOMAIN_SEPARATOR(),
                structHash
            )
        );
        
        // 使用卖家的私钥生成签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerPrivateKey, digest);
        
        // 使用签名上架NFT
        proxyV2.listWithSignature(
            address(nft),
            0,  // 使用 tokenId 0
            price,
            deadline,
            v,
            r,
            s
        );
        vm.stopPrank();
        
        // 验证上架信息
        (address listedSeller, uint96 listedPrice, bool isActive) = proxyV2.getListing(address(nft), 0);  // 使用 tokenId 0
        assertEq(listedSeller, seller);
        assertEq(listedPrice, price);
        assertTrue(isActive);
    }
}
