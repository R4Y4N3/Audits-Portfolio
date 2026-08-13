# M-1: CORRUPTED grace period can expire before the moderator is able to act

The `claimExpired()` function anchors `MODERATOR_CORRUPTED_GRACE` to the pool's fixed `expiry`, even though the pool moderator cannot classify a corruption until the registry actually enters `CORRUPTED`.

The grace-period check is:

```solidity
if (
    block.timestamp <
    expiry + MODERATOR_CORRUPTED_GRACE
) {
    revert AgreementCorruptedAwaitingModerator();
}
```

As a result, the entire grace period can elapse while the Agreement remains `UNDER_ATTACK`.

During this state, the moderator cannot classify the pool as either `SURVIVED` or `CORRUPTED`, because both outcomes require a terminal registry state.

If the Agreement transitions to `CORRUPTED` only after:

```text
expiry + MODERATOR_CORRUPTED_GRACE
```

the moderator's first opportunity to classify the corruption occurs at the same time that the permissionless fallback becomes available.

Any account can then immediately call `claimExpired()`.

The auto-CORRUPTED branch executes:

```solidity
if (
    state == IAttackRegistry.ContractState.CORRUPTED &&
    riskWindowStart != 0
) {
    if (
        block.timestamp <
        expiry + MODERATOR_CORRUPTED_GRACE
    ) {
        revert AgreementCorruptedAwaitingModerator();
    }

    outcome =
        PoolStates.Outcome.CORRUPTED;

    outcomeFlaggedAt =
        riskWindowEnd;

    corruptedReserve =
        snapshotTotalStaked +
        snapshotTotalBonus;

    claimsStarted = true;

    emit OutcomeFlagged(
        address(0),
        PoolStates.Outcome.CORRUPTED,
        false,
        address(0)
    );

    return;
}
```

Because the deadline has already passed, the pool immediately selects the bad-faith `CORRUPTED` outcome and sets `claimsStarted = true`.

The moderator is then permanently prevented from correcting the classification.

## Impact

The permissionless fallback is scope-blind and always resolves the pool as bad-faith `CORRUPTED`.

This can produce the wrong economic outcome in two cases:

1. An out-of-scope corruption should be classified as `SURVIVED`, returning the pool funds to stakers.
2. A good-faith corruption should reserve the pool for the named whitehat.

Instead, the permissionless fallback can classify the pool as bad-faith `CORRUPTED`.

`claimCorrupted()` then transfers the entire staked principal and bonus to the sponsor-selected `recoveryAddress`.

Once `claimsStarted` is set, the moderator cannot repair the incorrect outcome.

The issue therefore allows transaction ordering after a late `CORRUPTED` transition to determine who receives the entire pool balance.

## Proof of Concept

The attack follows this sequence:

1. Alice stakes principal into the pool.
2. Carol contributes bonus funds.
3. The Agreement enters `UNDER_ATTACK`.
4. `riskWindowStart` is recorded.
5. The Agreement remains `UNDER_ATTACK` beyond `expiry + MODERATOR_CORRUPTED_GRACE`.
6. During this period, the moderator cannot select either `SURVIVED` or `CORRUPTED`.
7. The Agreement eventually transitions to `CORRUPTED`.
8. An arbitrary account immediately calls `claimExpired()`.
9. The pool automatically finalizes bad-faith `CORRUPTED`.
10. `claimsStarted` prevents the moderator from correcting the outcome.
11. `claimCorrupted()` transfers the entire pool balance to `recoveryAddress`.

[View the full Foundry PoC](./poc/M-01-CorruptedGracePeriod.t.sol)

The canonical PoC was reproduced against contest commit `58e8ba4ce3f3277866e4926f3140e597f9554a1e` with BattleChain submodule commit `fde1b2abe9e5c27175f5b6f7324bcce6afc3b059`.

The upstream BattleChain contracts compile with Solidity `0.8.34`, while the PoC and in-scope Confidence Pool contracts compile with Solidity `0.8.26`.

Place the PoC in the original contest repository at `test/poc/late_corruption_grace/LateCorruptionPreemptsModerator.t.sol`, then run the upstream build followed by the test.

Reproduction commands:

    git submodule update --init --recursive

    rm -rf out/battlechain-upstream cache/battlechain-upstream

    forge build \
      --root lib/battlechain-safe-harbor-contracts \
      --out "$PWD/out/battlechain-upstream" \
      --cache-path "$PWD/cache/battlechain-upstream" \
      src/AgreementFactory.sol \
      src/AttackRegistry.sol \
      src/BattleChainSafeHarborRegistry.sol

    forge test \
      --match-path test/poc/late_corruption_grace/LateCorruptionPreemptsModerator.t.sol \
      -vvv

Recorded result:

    [PASS] test_LateCorruptionCanFinalizeBeforeModeratorClassificationWindow()
    [PASS] test_ResolvingBeforeLateCorruptionUsesExpiredBranch()

    Suite result: ok. 2 passed; 0 failed; 0 skipped


## Tools Used

Manual review and Foundry

## Recommended Mitigation Steps

The grace period should start when the pool first successfully observes the Agreement in the `CORRUPTED` state rather than from the pool's fixed expiry.

For example, the contract can record the first observation:

```solidity
uint256 public firstCorruptedObservationAt;
```

When `CORRUPTED` is first observed:

```solidity
if (
    state ==
        IAttackRegistry.ContractState.CORRUPTED &&
    firstCorruptedObservationAt == 0
) {
    firstCorruptedObservationAt =
        block.timestamp;
}
```

The fallback should then use:

```solidity
if (
    block.timestamp <
    firstCorruptedObservationAt +
        MODERATOR_CORRUPTED_GRACE
) {
    revert AgreementCorruptedAwaitingModerator();
}
```

If `claimExpired()` itself is the first interaction to observe `CORRUPTED`, that interaction must succeed after recording the timestamp rather than reverting, otherwise the timestamp update would be rolled back.

This guarantees that the moderator receives the full intended grace period only after the state requiring moderator classification actually exists.

---

**Original finding:** [CodeHawks Submission #176](https://codehawks.cyfrin.io/c/2026-07-battlechain-confidence-pools/s/176)
