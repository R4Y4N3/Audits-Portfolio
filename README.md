# R4Y4N3 — Web3 Security Portfolio

<p align="center">
  <img src="https://sherlock-files.ams3.digitaloceanspaces.com/profile_images/83a46156-be75-4fd7-9cde-fb3e49667207.jpg" width="120" />
</p>

<p align="center">
  <b>R4Y4N3</b><br/>
  Web3 Security Researcher
</p>

---

## Overview

This repository contains my public Web3 security portfolio.

The portfolio is divided into:

- **Audit Contest Findings**
- **Bug Bounty Program Reports**
- **Disclosure-Safe Writeups**

Only meaningful reports are included here. Informative, not applicable, out-of-scope, and invalid reports are intentionally excluded.

---

# Audit Contest Findings

These are findings from audit contests and competitive security reviews.

| ID | Platform | Contest | Finding | Severity | Status | Date |
|---:|---|---|---|---|---|---|
| 4 | HackenProof | Rain Smart Contract Audit Contest | Unauthorized cancellation of sell orders leads to griefing and permanent fund freezing | Critical | Resolved | Nov 2025 |
| 3 | HackenProof | Rain Smart Contract Audit Contest | Hardcoded dispute fee cap enables trivial DoS on 18-decimal token pools | High | Resolved | Nov 2025 |
| 2 | Sherlock | stNXM by EaseDeFi | `totalAssets` manipulation via Uniswap V3 spot price allowing vault drain | High | Valid Finding | Nov 2025 |
| 1 | Sherlock | stNXM by EaseDeFi | Double counting of staked assets via duplicate tranche tracking allows protocol insolvency | Medium | Valid Finding | Nov 2025 |

---

# Bug Bounty Program Reports

These are reports submitted to live bug bounty programs.

Only reports with meaningful outcomes are included.

## Confirmed Duplicates

| ID | Platform | Program | Finding | Severity | Status | Date |
|---:|---|---|---|---|---|---|
| 5 | HackenProof | Hyperbridge Protocol | `pallet-hyper-fungible-token`: Decimal downscaling bug overstates outgoing EVM amounts, enabling over-mint/unlock for low-decimal tokens | - | Duplicate | May 2026 |
| 4 | HackenProof | Hyperbridge Protocol | `MerkleMultiProof.CalculateRoot`: `_ceilLog2` shift overflow collapses `firstLeafPos` to zero, enabling zero-proof root forgery | - | Duplicate | May 2026 |
| 3 | HackenProof | Hyperbridge Protocol | `PolkadotTrie.VerifyProof`: unconditional `keyPresent=true` at `BRANCH_WITHOUT_MASK` node enables false-positive membership proofs | - | Duplicate | May 2026 |
| 2 | HackenProof | Calyx Smart Contract | Persistent account lock via panic in withdraw callback | - | Duplicate | Mar 2026 |
| 1 | Immunefi | MagpieXYZ | Direct receipt-token withdrawal allows permanent freezing of USDC helper WOM rewards | High | Escalated | May 2026 |

---

# Selected Contest Writeups

## Critical — Unauthorized Cancellation of Sell Orders

**Platform:** HackenProof  
**Contest:** Rain Smart Contract Audit Contest  
**Severity:** Critical  
**Status:** Resolved  

Unauthorized cancellation of sell orders could allow griefing and permanent freezing of user funds.

Full technical details are redacted unless disclosure is allowed.

---

## High — Hardcoded Dispute Fee Cap DoS

**Platform:** HackenProof  
**Contest:** Rain Smart Contract Audit Contest  
**Severity:** High  
**Status:** Resolved  

A hardcoded dispute fee cap could make dispute flows vulnerable to denial-of-service behavior on 18-decimal token pools.

---

## High — Vault Drain via Spot Price Manipulation

**Platform:** Sherlock  
**Contest:** stNXM by EaseDeFi  
**Severity:** High  
**Status:** Valid Finding  

The vault’s `totalAssets` logic could be manipulated through Uniswap V3 spot pricing, creating a vault-drain path.

---

## Medium — Duplicate Tranche Tracking

**Platform:** Sherlock  
**Contest:** stNXM by EaseDeFi  
**Severity:** Medium  
**Status:** Valid Finding  

Duplicate tranche tracking could cause assets to be counted more than once, creating protocol insolvency risk.

---

# Disclosure Policy

I do not publish:

- Private exploit code
- Live vulnerability details
- Confidential program screenshots
- Internal triage comments
- Undisclosed proof-of-concept code

For restricted reports, I only publish:

- Finding title
- Platform
- Program or contest name
- Severity
- Status
- High-level impact

---

# Skills Demonstrated

| Area | Examples |
|---|---|
| DeFi security | Vault accounting, `totalAssets`, dispute logic, pool freezing |
| Smart contract auditing | Solidity, EVM, protocol logic review |
| Proof verification | Merkle proof and trie proof validation bugs |
| DoS / griefing | Permanent fund freezing, state lock, callback panic |
| Contest auditing | Sherlock and HackenProof contests |
| Bug bounty research | Immunefi and HackenProof programs |
