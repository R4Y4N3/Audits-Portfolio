# C-1: Uniswap V3 spot-price manipulation can inflate the share price and drain the vault

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

The attack follows this sequence:

1. The attacker deposits wNXM and receives stNXM shares.
2. The attacker obtains a larger amount of stNXM.
3. The attacker sells the stNXM into the Uniswap V3 pool.
4. The manipulated price increases the virtual shares reported by `dexBalances()`.
5. The circulating supply returned by `totalSupply()` decreases.
6. The attacker redeems their original shares at the inflated conversion rate.

[View the complete Foundry test](./poc/C-01-TotalAssetsManipulation.t.sol)

To run it from the original stNXM repository:

```bash
forge test --match-contract TotalAssetsManipulationTest -vv
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

The test demonstrates the accounting error using this sequence:

1. The vault stakes `5,000 NXM` in tranche `250`.
2. The owner adds another `1,000 NXM` to the same token and tranche.
3. The tranche ID is added to the tracking array twice.
4. The real staking balance becomes `6,000 NXM`.
5. `stakedNxm()` reads the balance twice and reports `12,000 NXM`.

[View the complete Foundry test](./poc/H-01-DuplicateTrancheTracking.t.sol)

To run it from the original stNXM repository:

```bash
forge test --match-contract DoubleCountingExploitTest -vv
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
