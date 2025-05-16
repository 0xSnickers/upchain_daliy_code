// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ERC721WithSignature} from "../src/ERC721WithSignature.sol";

contract ERC721WithSignatureTest is Test {
    ERC721WithSignature public nft;
    address public owner;
    address public user;
    uint256 public ownerPrivateKey;
    uint256 public userPrivateKey;

    function setUp() public {
        // 设置测试账户
        (owner, ownerPrivateKey) = makeAddrAndKey("owner");
        (user, userPrivateKey) = makeAddrAndKey("user");

        // 部署合约，owner 作为合约拥有者
        vm.prank(owner);
        nft = new ERC721WithSignature("Test NFT", "TNFT", "http://example.com/");
    }

    function test_MintWithSignature() public {
        // 1. Owner 离线签名
        uint256 tokenId = 1;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = nft.nonces(user);

        // 构造签名数据
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Mint(address to,uint256 tokenId,uint256 nonce,uint256 deadline)"),
                user,  // 接收者地址
                tokenId,
                nonce,
                deadline
            )
        );

        // 使用 owner 的私钥签名
        bytes32 digest = nft.hashTypedDataV4Public(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // 2. User 使用签名铸造 NFT
        vm.prank(user);
        nft.mintWithSignature(user, tokenId, deadline, signature);

        // 验证结果
        assertEq(nft.ownerOf(tokenId), user);
        assertEq(nft.nonces(user), nonce + 1);
    }

    function test_RevertWhen_MintWithExpiredSignature() public {
        uint256 tokenId = 1;
        uint256 deadline = block.timestamp - 1; // 已过期的deadline
        uint256 nonce = nft.nonces(user);

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Mint(address to,uint256 tokenId,uint256 nonce,uint256 deadline)"),
                user,
                tokenId,
                nonce,
                deadline
            )
        );

        bytes32 digest = nft.hashTypedDataV4Public(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(user);
        vm.expectRevert("PermitERC721: permit expired");
        nft.mintWithSignature(user, tokenId, deadline, signature);
    }

    function test_RevertWhen_MintWithInvalidCaller() public {
        uint256 tokenId = 1;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = nft.nonces(user);

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Mint(address to,uint256 tokenId,uint256 nonce,uint256 deadline)"),
                user,
                tokenId,
                nonce,
                deadline
            )
        );

        bytes32 digest = nft.hashTypedDataV4Public(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // 使用错误的调用者
        address wrongCaller = makeAddr("wrongCaller");
        vm.prank(wrongCaller);
        vm.expectRevert("PermitERC721: invalid caller");
        nft.mintWithSignature(user, tokenId, deadline, signature);
    }

    function test_RevertWhen_MintWithMaxSupplyReached() public {
        uint256 tokenId = 11; // 超过最大供应量 (MAX_SUPPLY = 10)
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = nft.nonces(user);

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Mint(address to,uint256 tokenId,uint256 nonce,uint256 deadline)"),
                user,
                tokenId,
                nonce,
                deadline
            )
        );

        bytes32 digest = nft.hashTypedDataV4Public(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(user);
        vm.expectRevert("PermitERC721: max supply reached");
        nft.mintWithSignature(user, tokenId, deadline, signature);
    }

    function test_RevertWhen_MintWithInvalidSignature() public {
        uint256 tokenId = 1;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = nft.nonces(user);

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Mint(address to,uint256 tokenId,uint256 nonce,uint256 deadline)"),
                user,
                tokenId,
                nonce,
                deadline
            )
        );

        bytes32 digest = nft.hashTypedDataV4Public(structHash);
        // 使用错误的签名者（user 而不是 owner）
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(user);
        vm.expectRevert("PermitERC721: invalid signature");
        nft.mintWithSignature(user, tokenId, deadline, signature);
    }
}
