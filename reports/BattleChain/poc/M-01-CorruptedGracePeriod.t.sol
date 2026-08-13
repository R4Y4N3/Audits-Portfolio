function test_corruptionFirstReportedAfterGraceCanBeAutoResolvedImmediately() external {
    uint256 principal = 100 * ONE;
    uint256 bonus = 50 * ONE;
​
    _stake(alice, principal);
    _contributeBonus(carol, bonus);
​
    attackRegistry.setAgreementState(IAttackRegistry.ContractState.UNDER_ATTACK);
    pool.pokeRiskWindow();
​
    vm.warp(pool.expiry() + pool.MODERATOR_CORRUPTED_GRACE() + 1);
​
    // The moderator was available, but neither classification was valid before corruption.
    vm.prank(moderator);
    vm.expectRevert(IConfidencePool.InvalidOutcome.selector);
    pool.flagOutcome(PoolStates.Outcome.SURVIVED, false, address(0));
​
    vm.prank(moderator);
    vm.expectRevert(IConfidencePool.InvalidOutcome.selector);
    pool.flagOutcome(PoolStates.Outcome.CORRUPTED, true, attacker);
​
    // A legitimate late terminal transition occurs. An arbitrary account backruns it.
    attackRegistry.setAgreementState(IAttackRegistry.ContractState.CORRUPTED);
​
    vm.prank(dave);
    pool.claimExpired();
​
    assertEq(uint256(pool.outcome()), uint256(PoolStates.Outcome.CORRUPTED));
    assertEq(pool.corruptedReserve(), principal + bonus);
​
    // The pool moderator now has no correction path.
    vm.prank(moderator);
    vm.expectRevert(IConfidencePool.OutcomeAlreadySet.selector);
    pool.flagOutcome(PoolStates.Outcome.SURVIVED, false, address(0));
​
    uint256 recoveryBefore = token.balanceOf(recovery);
    pool.claimCorrupted();
​
    assertEq(token.balanceOf(recovery) - recoveryBefore, principal + bonus);
    assertEq(token.balanceOf(alice), 0);
}
