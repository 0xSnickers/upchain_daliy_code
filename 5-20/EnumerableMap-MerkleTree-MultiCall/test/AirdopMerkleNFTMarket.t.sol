// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/AirdopMerkleNFTMarket.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

// 测试用 ERC721 合约
contract TestNFT is ERC721 {
    constructor() ERC721("Test NFT", "TNFT") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

// 测试用 ERC20 Permit Token 合约
contract TestPermitToken is ERC20, IERC20Permit {
    bytes32 public constant PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    mapping(address => uint256) public nonces;

    constructor() ERC20("Test Token", "TT") {
        _mint(msg.sender, 1000000 * 10**18);
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual override {
        require(deadline >= block.timestamp, "Permit expired");

        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline));
        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), structHash));

        address signer = ecrecover(hash, v, r, s);
        require(signer == owner, "Invalid signature");

        _approve(owner, spender, value);
    }

    function DOMAIN_SEPARATOR() public view override returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name())),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }
}

contract AirdopMerkleNFTMarketTest is Test {
    AirdopMerkleNFTMarket public market;
    TestNFT public nft;
    TestPermitToken public permitToken;
    
    address public owner;
    address public seller;
    address public buyer;
    address public whitelistedUser;
    uint256 public whitelistedUserPrivateKey;
    address public signer;
    uint256 public constant WHITELIST_TOKEN_AMOUNT = 100 * 10**18;
    uint256 public constant NFT_PRICE = 1 ether;
    
    bytes32 public merkleRoot;
    bytes32[] public whitelistedUserProof;
    bytes32[] public signerProof;

    event NFTListed(address indexed nftContract, uint256 indexed tokenId, address seller, uint96 price);
    event NFTSold(address indexed nftContract, uint256 indexed tokenId, address buyer, uint96 price);
    event NFTUnlisted(address indexed nftContract, uint256 indexed tokenId, address seller);

    function setUp() public {
        // 设置测试账户
        owner = makeAddr("owner");
        seller = makeAddr("seller");
        buyer = makeAddr("buyer");
        whitelistedUserPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        whitelistedUser = vm.addr(whitelistedUserPrivateKey);
        signer = vm.addr(0xA11CE);
        
        // 部署合约
        vm.startPrank(owner);
        permitToken = new TestPermitToken();
        market = new AirdopMerkleNFTMarket(address(permitToken), WHITELIST_TOKEN_AMOUNT);
        nft = new TestNFT();
        vm.stopPrank();
        
        // 修改 Merkle 树构建方式
        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = keccak256(abi.encodePacked(whitelistedUser));
        leaves[1] = keccak256(abi.encodePacked(signer));
        
        // 正确构建 Merkle 树
        bytes32 leaf0 = leaves[0];
        bytes32 leaf1 = leaves[1];
        
        // 确保叶子节点排序（这很重要！）
        if (uint256(leaf0) > uint256(leaf1)) {
            (leaf0, leaf1) = (leaf1, leaf0);
        }
        
        // 计算 Merkle 根
        merkleRoot = keccak256(abi.encodePacked(leaf0, leaf1));
        
        // 生成证明 - 为 whitelistedUser 生成证明
        whitelistedUserProof = new bytes32[](1);
        whitelistedUserProof[0] = leaves[1];  // signer 的哈希作为证明
        
        // 为 signer 生成证明
        signerProof = new bytes32[](1);
        signerProof[0] = leaves[0];  // whitelistedUser 的哈希作为证明
        
    
        
        // 设置 Merkle 树根
        vm.prank(owner);
        market.setMerkleRoot(merkleRoot);
        
        // 铸造 NFT 给卖家
        vm.prank(owner);
        nft.mint(seller, 1);
        
        // 给买家一些 ETH
        vm.deal(buyer, 10 ether);
        vm.deal(whitelistedUser, 10 ether);
        
        // 给买家一些代币
        vm.prank(owner);
        permitToken.transfer(buyer, WHITELIST_TOKEN_AMOUNT);
        vm.prank(owner);
        permitToken.transfer(whitelistedUser, WHITELIST_TOKEN_AMOUNT);
    }

    function test_ListNFT() public {
        vm.startPrank(seller);
        nft.approve(address(market), 1);
        
        vm.expectEmit(true, true, true, true);
        emit NFTListed(address(nft), 1, seller, uint96(NFT_PRICE));
        
        market.list(address(nft), 1, uint96(NFT_PRICE));
        
        (address listingSeller, uint96 price, bool isActive) = market.getListing(address(nft), 1);
        assertEq(listingSeller, seller);
        assertEq(price, NFT_PRICE);
        assertTrue(isActive);
        vm.stopPrank();
    }

    function test_WhitelistedUserBuyNFT() public {
        // 卖家上架 NFT
        vm.startPrank(seller);
        nft.approve(address(market), 1);
        market.list(address(nft), 1, uint96(NFT_PRICE));
        vm.stopPrank();
        
        // 白名单用户购买 NFT
        vm.startPrank(whitelistedUser);
        
        // 1. 准备 Permit 签名
        uint256 deadline = block.timestamp + 1 hours;
        bytes32 domainSeparator = permitToken.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            whitelistedUser,
            address(market),
            WHITELIST_TOKEN_AMOUNT,
            permitToken.nonces(whitelistedUser),
            deadline
        ));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(whitelistedUserPrivateKey, digest);
        
        // 2. 执行 Permit
        market.permitPrePay(
            whitelistedUser,
            address(market),
            WHITELIST_TOKEN_AMOUNT,
            deadline,
            v,
            r,
            s
        );
        
        // 3. 购买 NFT
        vm.expectEmit(true, true, false, false);
        emit NFTSold(address(nft), 1, whitelistedUser, uint96(NFT_PRICE / 2));
        market.claimNFT{value: NFT_PRICE / 2}(address(nft), 1, whitelistedUserProof);
        assertEq(nft.ownerOf(1), whitelistedUser);
        vm.stopPrank();
    }

    function test_PermitAndBuyNFT() public {
        // 卖家上架 NFT
        vm.startPrank(seller);
        nft.approve(address(market), 1);
        market.list(address(nft), 1, uint96(NFT_PRICE));
        vm.stopPrank();
        // 准备 Permit 签名
        uint256 privateKey = 0xA11CE;
        address _signer = signer;
        vm.deal(_signer, 10 ether);
        vm.prank(owner);
        permitToken.transfer(_signer, WHITELIST_TOKEN_AMOUNT);
        uint256 deadline = block.timestamp + 1 hours;
        bytes32 domainSeparator = permitToken.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            _signer,
            address(market),
            WHITELIST_TOKEN_AMOUNT,
            permitToken.nonces(_signer),
            deadline
        ));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        // 执行 Permit 和购买 NFT
        vm.startPrank(_signer);
        // 1. 执行 Permit
        market.permitPrePay(
            _signer,
            address(market),
            WHITELIST_TOKEN_AMOUNT,
            deadline,
            v,
            r,
            s
        );
        // 2. 购买 NFT
        vm.expectEmit(true, true, false, false);
        emit NFTSold(address(nft), 1, _signer, uint96(NFT_PRICE / 2));
        market.claimNFT{value: NFT_PRICE / 2}(address(nft), 1, signerProof);
        assertEq(nft.ownerOf(1), _signer);
        vm.stopPrank();
    }

    function test_RevertWhen_NonWhitelistedUserBuyNFT() public {
        // 卖家上架 NFT
        vm.startPrank(seller);
        nft.approve(address(market), 1);
        market.list(address(nft), 1, uint96(NFT_PRICE));
        vm.stopPrank();
        
        // 非白名单用户尝试购买 NFT
        vm.startPrank(buyer);
        permitToken.approve(address(market), WHITELIST_TOKEN_AMOUNT);
        
        vm.expectRevert("Not in whitelist");
        market.claimNFT{value: NFT_PRICE / 2}(address(nft), 1, signerProof);
        vm.stopPrank();
    }

    function test_WithdrawTokens() public {
        // 卖家上架 NFT
        vm.startPrank(seller);
        nft.approve(address(market), 1);
        market.list(address(nft), 1, uint96(NFT_PRICE));
        vm.stopPrank();
        // 白名单用户购买 NFT
        vm.startPrank(whitelistedUser);
        // 1. 准备 Permit 签名
        uint256 deadline = block.timestamp + 1 hours;
        bytes32 domainSeparator = permitToken.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            whitelistedUser,
            address(market),
            WHITELIST_TOKEN_AMOUNT,
            permitToken.nonces(whitelistedUser),
            deadline
        ));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(whitelistedUserPrivateKey, digest);
        // 2. 执行 Permit
        market.permitPrePay(
            whitelistedUser,
            address(market),
            WHITELIST_TOKEN_AMOUNT,
            deadline,
            v,
            r,
            s
        );
        // 3. 购买 NFT
        vm.expectEmit(true, true, false, false);
        emit NFTSold(address(nft), 1, whitelistedUser, uint96(NFT_PRICE / 2));
        market.claimNFT{value: NFT_PRICE / 2}(address(nft), 1, whitelistedUserProof);
        vm.stopPrank();
        // console2.log("permitToken.balanceOf(address(market))===>");
        // console2.log(permitToken.balanceOf(address(market)));
        // 验证代币已转移到市场合约
        assertEq(permitToken.balanceOf(address(market)), WHITELIST_TOKEN_AMOUNT);
        // 提取代币
        uint256 balanceBefore = permitToken.balanceOf(owner);
        vm.prank(owner);
        market.withdrawTokens();
        uint256 balanceAfter = permitToken.balanceOf(owner);
        assertEq(balanceAfter - balanceBefore, WHITELIST_TOKEN_AMOUNT);
    }
}