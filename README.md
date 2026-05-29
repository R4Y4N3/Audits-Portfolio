# R4Y4N3 — Web3 Security Portfolio

<p align="center">
  <b>R4Y4N3</b><br/>
  Web3 Security Researcher
</p>

---

## Audit Competitions

| Competition | Place | Findings | Tags | Leaderboard |
|---|---:|---|---|---|
| Rain Smart Contract Audit Contest | - | 1C, 1H | `solidity`, `defi`, `dos`, `fund-freeze` | HackenProof |
| stNXM by EaseDeFi | #48 | 1H, 1M | `solidity`, `vault`, `uniswap-v3`, `accounting` | Sherlock |

---

## Bug Bounty Programs

| Program | Findings | Tags | Platform |
|---|---|---|---|
| Hyperbridge Protocol | 3D | `proof-verification`, `merkle`, `trie`, `substrate`, `evm` | HackenProof |
| Calyx Smart Contract | 1D | `near`, `callback`, `withdraw`, `state-lock` | HackenProof |
| MagpieXYZ | 1H Escalated | `defi`, `rewards`, `withdrawal`, `fund-freeze` | Immunefi |

---

## Finding Legend

| Symbol | Meaning |
|---|---|
| C | Critical |
| H | High |
| M | Medium |
| D | Duplicate |

---

## Selected Audit Competition Findings

| Competition | Finding | Severity | Status |
|---|---|---|---|
| Rain Smart Contract Audit Contest | Unauthorized cancellation of sell orders leads to griefing and permanent fund freezing | Critical | Resolved |
| Rain Smart Contract Audit Contest | Hardcoded dispute fee cap enables trivial DoS on 18-decimal token pools | High | Resolved |
| stNXM by EaseDeFi | `totalAssets` manipulation via Uniswap V3 spot price allowing vault drain | High | Valid Finding |
| stNXM by EaseDeFi | Double counting of staked assets via duplicate tranche tracking allows protocol insolvency | Medium | Valid Finding |

---

## Selected Bug Bounty Reports

| Program | Finding | Severity | Status | Platform |
|---|---|---|---|---|
| Hyperbridge Protocol | `pallet-hyper-fungible-token`: decimal downscaling bug overstates outgoing EVM amounts | - | Duplicate | HackenProof |
| Hyperbridge Protocol | `MerkleMultiProof.CalculateRoot`: `_ceilLog2` shift overflow enables zero-proof root forgery | - | Duplicate | HackenProof |
| Hyperbridge Protocol | `PolkadotTrie.VerifyProof`: unconditional `keyPresent=true` enables false-positive membership proofs | - | Duplicate | HackenProof |
| Calyx Smart Contract | Persistent account lock via panic in withdraw callback | - | Duplicate | HackenProof |
| MagpieXYZ | Direct receipt-token withdrawal allows permanent freezing of USDC helper WOM rewards | High | Escalated | Immunefi |

---

## Disclosure Policy

I only publish disclosure-safe information.

I do not publish:

- private proof-of-concept code
- live vulnerability details
- confidential dashboard screenshots
- private triage comments
- undisclosed exploit paths

Reports marked as duplicate or escalated are summarized only at a high level.
