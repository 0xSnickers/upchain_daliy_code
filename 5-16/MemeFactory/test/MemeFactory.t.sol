// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MemeFactory.sol";
import "../src/MemeLogic.sol";

contract MemeFactoryTest is Test {
    MemeFactory public factory;
    address public projectOwner;
    address public memeOwner;
    address public buyer;

    function setUp() public {
        memeOwner = makeAddr("memeOwner");
        buyer = makeAddr("buyer");

        vm.startPrank(projectOwner);
        factory = new MemeFactory();
        projectOwner = factory.owner();
        vm.stopPrank();

        vm.deal(memeOwner, 100 ether);
        vm.deal(buyer, 100 ether);
    }

    function test_DeployAndMint() public {
        // 发行者部署新 Meme
        vm.startPrank(memeOwner);
        // 发行参数：总量1000000，单次mint 10000，单价0.0001ETH
        address memeToken = factory.deployInscription(
            "PEPE",
            1_000_000,           // totalSupply
            10_000,              // perMint
            0.0001 ether         // price (每个token 0.0001ETH)
        );
        vm.stopPrank();

        MemeLogic token = MemeLogic(memeToken);
        assertEq(token.symbol(), "PEPE");
        assertEq(token.totalSupply_(), 1_000_000);
        assertEq(token.perMint(), 10_000);
        assertEq(token.price(), 0.0001 ether);

        // 购买者mint
        uint256 mintCost = 0.0001 ether * 10_000; // 1 ETH
        uint256 projectOwnerBalanceBefore = projectOwner.balance;
        uint256 memeOwnerBalanceBefore = memeOwner.balance;

        vm.startPrank(buyer);
        factory.mintInscription{value: mintCost}(memeToken);
        vm.stopPrank();

        // 检查余额
        assertEq(token.balanceOf(buyer), 10_000);

        // 检查ETH分配
        uint256 projectFee = mintCost / 100; // 1%
        uint256 ownerFee = mintCost - projectFee;
        assertEq(address(factory).balance - projectOwnerBalanceBefore, projectFee);
        assertEq(memeOwner.balance - memeOwnerBalanceBefore, ownerFee);
    }

    function test_MintFailOnIncorrectPayment() public {
        vm.startPrank(memeOwner);
        address memeToken = factory.deployInscription(
            "PEPE",
            1_000_000,
            10_000,
            0.0001 ether
        );
        vm.stopPrank();

        // 少付
        vm.startPrank(buyer);
        vm.expectRevert();
        factory.mintInscription{value: 0.5 ether}(memeToken);
        vm.stopPrank();

        // 多付
        vm.startPrank(buyer);
        vm.expectRevert();
        factory.mintInscription{value: 2 ether}(memeToken);
        vm.stopPrank();
    }

    function test_CannotExceedTotalSupply() public {
        vm.startPrank(memeOwner);
        address memeToken = factory.deployInscription(
            "PEPE",
            20_000,      // totalSupply
            10_000,      // perMint
            0.0001 ether
        );
        vm.stopPrank();

        vm.startPrank(buyer);
        factory.mintInscription{value: 1 ether}(memeToken); // 第一次
        factory.mintInscription{value: 1 ether}(memeToken); // 第二次
        vm.expectRevert("Exceeds total supply");
        factory.mintInscription{value: 1 ether}(memeToken); // 第三次超额
        vm.stopPrank();
    }
} 