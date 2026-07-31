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

The attack follows this sequence:

1. Alice places a sell order and her votes are moved into escrow.
2. Bob places his own sell order so that he has enough escrowed votes.
3. Bob calls `cancelSellOrders()` using Alice's order ID.
4. Alice's order is removed from the order book.
5. Alice's escrowed votes remain locked.
6. Bob's accounting is incorrectly reduced.

[View the complete Foundry test](./poc/C-01-UnauthorizedSellOrderCancellation.t.sol)

To run it from the original Rain repository:

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

The test creates a pool using an 18-decimal token and shows that a dispute against a pool containing approximately `1,000,000` tokens can be opened by paying only `0.000000001` tokens.

- [View the complete Foundry test](./poc/H-01-DisputeFeeDoS.t.sol)
- [View the supporting mock contracts](./poc/mocks/DisputeMocks.sol)

To run it from the original Rain repository:

```bash
forge test --match-path test/DisputeFeeDoS.t.sol -vv
```

Expected result:

```text
Pool size:         1000000.000000000000000000
Expected fee:      10000.000000000000000000
Actual capped fee: 0.000000001000000000

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

