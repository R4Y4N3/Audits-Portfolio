# R4Y4N3 — Web3 Security Research Portfolio

<p align="center">
  <img src="https://sherlock-files.ams3.digitaloceanspaces.com/profile_images/83a46156-be75-4fd7-9cde-fb3e49667207.jpg" width="120" style="border-radius:50%" />
</p>

<p align="center">
  <b>Rayane Boucheraine — R4Y4N3</b><br/>
  Web3 Security Researcher focused on Solidity, Rust, Solana, DeFi, and smart contract security.
</p>

---

## About Me

I am **Rayane Boucheraine**, also known as **R4Y4N3**, a Web3 security researcher focused on finding real-world vulnerabilities in smart contracts and blockchain applications.

My work includes:

- Audit contests
- Bug bounty programs
- Smart contract reviews
- DeFi protocol analysis
- Solana and Rust security research
- Web3 CTF challenge solving and authoring

This repository contains a disclosure-safe overview of my security research, including contest results, bug bounty submissions, duplicates, informative findings, and public writeups.

Some reports are redacted because they were submitted to live programs, private scopes, or platforms with disclosure restrictions.

---

## Highlights

| Category | Result |
|---|---:|
| Immunefi submissions | 11 |
| HackenProof submissions | 17 |
| Sherlock findings | 2 |
| Critical reports submitted | 5+ |
| High reports submitted | 5+ |
| Audit contest resolved findings | Yes |
| Public writeups | Coming soon |

---

## Platforms

| Platform | Profile / Status |
|---|---|
| Immunefi | Active security researcher |
| HackenProof | Active security researcher |
| Sherlock | Contest participant, Top 50 placement |
| GitHub | Public security portfolio |

---

## Security Research Table

| ID | Platform | Program / Contest | Finding | Type | Severity | Status | Date |
|---:|---|---|---|---|---|---|---|
| 31 | Immunefi | ENS | Lack of migration-safe replay protection in `L2ReverseRegistrarWithMigration` allows consumed signatures to overwrite migrated ENS L2 reverse records | Smart Contract | High | Closed | May 2026 |
| 30 | HackenProof | Volo Smart Contracts | ManagerCap Missing Vault Authorization — Cross-Vault Parameter Manipulation and Withdrawal DoS via u64 Overflow | Smart Contract | None | Informative | May 2026 |
| 29 | HackenProof | Hyperbridge Protocol | `pallet-hyper-fungible-token`: Decimal downscaling bug overstates outgoing EVM amounts, enabling over-mint/unlock for low-decimal tokens | Smart Contract / Runtime | None | Duplicate | May 2026 |
| 28 | HackenProof | Hyperbridge Protocol | `MerkleMultiProof.CalculateRoot`: `_ceilLog2` shift overflow collapses `firstLeafPos` to zero, enabling zero-proof root forgery | Smart Contract / Cryptography | None | Duplicate | May 2026 |
| 27 | HackenProof | Hyperbridge Protocol | `PolkadotTrie.VerifyProof`: Unconditional `keyPresent=true` at `BRANCH_WITHOUT_MASK` node enables false-positive membership proofs | Smart Contract / Proof Verification | None | Duplicate | May 2026 |
| 26 | Immunefi | Wildcat Protocol | Borrower can atomically bypass `NoReducingAprBeforeTermEnd` protection in `FixedTermHooks` by reducing the term end time to `block.timestamp` | Smart Contract | High | Closed | May 2026 |
| 25 | Immunefi | MagpieXYZ | Direct receipt-token withdrawal allows permanent freezing of USDC helper WOM rewards | Smart Contract | High | Escalated | May 2026 |
| 24 | Immunefi | OnRe | `delete_all_offer_vectors` bypasses the Ackee W7 time guard, enabling atomic manipulation of pending redemption prices | Smart Contract | Medium | Closed | May 2026 |
| 23 | Immunefi | Obyte | Ghost follow-up state overwrite allows arbitrary repeat minting of FRD rewards | Smart Contract | Critical | Closed | April 2026 |
| 22 | Immunefi | Berachain Web / Apps | Missing server-side authorization in `/batch-claim` paymaster backend allows any EOA to exhaust the gas sponsorship wallet | Web3 Backend | Critical | Closed | April 2026 |
| 21 | Immunefi | OpenZeppelin | Incomplete fix of C-01: `ERC7984._transferAndCall` still allows receiver to steal transferred tokens despite v0.2 patch | Smart Contract | Critical | Closed | April 2026 |
| 20 | Immunefi | Stellar | Blind Soroban authorization entry signing via malicious RPC leads to direct loss of funds | Smart Contract / Wallet Security | Critical | Closed | April 2026 |
| 19 | HackenProof | Calyx Smart Contract | Persistent account lock via panic in withdraw callback | Smart Contract | None | Duplicate | March 2026 |
| 18 | HackenProof | Calyx Smart Contract | Discount phase accounting not reconciled on withdraw, causing state desync | Smart Contract | None | Out of Scope | March 2026 |
| 17 | HackenProof | Calyx Smart Contract | Storage-griefing via `ft_on_transfer` `msg` fan-out | Smart Contract | None | Not Applicable | March 2026 |
| 16 | HackenProof | AlphaSec Web & Smart Contracts | `l1owner` field authorization bypass via ECDSA signer mismatch | Smart Contract / Auth | None | Informative | March 2026 |
| 15 | Immunefi | SNS | Insecure account closure in `delete` instruction leads to permanent domain griefing via revival attack | Solana / Rust | Low | Closed | February 2026 |
| 14 | Immunefi | SNS | Missing SOL balance pre-check in `/api/dash/discounts/register` allows unauthenticated compute amplification | Web3 Backend | Medium | Closed | February 2026 |
| 13 | Immunefi | Pillar | ID collision in pre-existing member initialization leads to direct theft of user funds and protocol insolvency | Smart Contract | Critical | Closed | December 2025 |
| 12 | Sherlock | stNXM by EaseDeFi | `totalAssets` manipulation via Uniswap V3 spot price allowing vault drain through flash loan attack | Smart Contract / DeFi | High | Valid Finding | November 2025 |
| 11 | Sherlock | stNXM by EaseDeFi | Double counting of staked assets via duplicate tranche tracking allows protocol insolvency | Smart Contract / DeFi | Medium | Valid Finding | November 2025 |
| 10 | HackenProof | Rain Smart Contract Audit Contest | Unchecked fee parameters enable permanent pool DoS and fund theft | Smart Contract | None | Not Applicable | November 2025 |
| 9 | HackenProof | Rain Smart Contract Audit Contest | Hardcoded dispute fee cap enables trivial DoS on 18-decimal token pools | Smart Contract | High | Resolved | November 2025 |
| 8 | HackenProof | Rain Smart Contract Audit Contest | CEI pattern violation in `enterLiquidity()` function — defense-in-depth concern in `RainPool` | Smart Contract | None | Not Applicable | November 2025 |
| 7 | HackenProof | Rain Smart Contract Audit Contest | Missing zero-address validation in admin functions allows permanent bricking of `RainDeployer` | Smart Contract | None | Not Applicable | November 2025 |
| 6 | HackenProof | Rain Smart Contract Audit Contest | Incorrect timestamp validation in constructor prevents immediate pool creation | Smart Contract | None | Not Applicable | November 2025 |
| 5 | HackenProof | Rain Smart Contract Audit Contest | Misleading `size()` function in `LinkedListLogic` creates permanent DoS vector via gas exhaustion | Smart Contract | None | Informative | November 2025 |
| 4 | HackenProof | Rain Smart Contract Audit Contest | Double-removal vulnerability in `LinkedListLogic` allows state corruption and potential theft of funds | Smart Contract | None | Not Applicable | November 2025 |
| 3 | HackenProof | Rain Smart Contract Audit Contest | Malicious oracle can stall dispute resolution, leading to permanent freezing of all pool funds | Smart Contract | None | Not Applicable | November 2025 |
| 2 | HackenProof | Rain Smart Contract Audit Contest | Unauthorized cancellation of sell orders leads to griefing and permanent fund freezing | Smart Contract | Critical | Resolved | November 2025 |
| 1 | CTF / Independent | Blockchain Challenges | Authored and solved Web3 security challenges, including blockchain CTF tasks | Web3 CTF | - | Public / Internal | 2025 |

---

## Selected Findings

### Critical — Unauthorized Order Cancellation

**Platform:** HackenProof  
**Program:** Rain Smart Contract Audit Contest  
**Severity:** Critical  
**Status:** Resolved  

Unauthorized cancellation of sell orders could lead to griefing and permanent freezing of funds.

> Disclosure-safe summary only. Full technical details are not published unless allowed by the program.

---

### High — Dispute Fee DoS

**Platform:** HackenProof  
**Program:** Rain Smart Contract Audit Contest  
**Severity:** High  
**Status:** Resolved  

A hardcoded dispute fee cap could allow trivial denial-of-service behavior on pools using 18-decimal tokens.

---

### High — Vault Drain via Spot Price Manipulation

**Platform:** Sherlock  
**Contest:** stNXM by EaseDeFi  
**Severity:** High  
**Status:** Valid Finding  

`totalAssets` could be manipulated through Uniswap V3 spot pricing, creating a possible vault-drain path using flash-loan-style price manipulation.

---

### Medium — Duplicate Tranche Tracking

**Platform:** Sherlock  
**Contest:** stNXM by EaseDeFi  
**Severity:** Medium  
**Status:** Valid Finding  

Duplicate tranche tracking could cause double counting of staked assets, creating insolvency risk.

---

### Solana — Account Revival Attack

**Platform:** Immunefi  
**Program:** SNS  
**Severity:** Low  
**Status:** Closed  

An insecure account closure pattern in a Solana instruction could allow domain griefing through revival-style account behavior.

---

## Disclosure Policy

I do not publish:

- Private exploit code
- Live vulnerabilities
- Undisclosed proof-of-concepts
- Screenshots from private dashboards
- Confidential triage comments
- Full transaction payloads unless disclosure is allowed

For private or closed reports, I only publish:

- Vulnerability class
- Severity
- High-level impact
- Root cause summary
- Recommended mitigation idea
- Disclosure-safe notes

---

## Skills Demonstrated

| Area | Examples |
|---|---|
| DeFi accounting | Vault shares, `totalAssets`, tranche accounting, insolvency bugs |
| Access control | Authorization bypass, signer mismatch, missing ownership checks |
| DoS / griefing | Permanent fund freezing, pool bricking, gas exhaustion |
| Solana security | Account closure, revival attacks, PDA/state handling |
| Cryptographic verification | Merkle proof and trie proof verification bugs |
| Web3 backend | Paymaster authorization, gas sponsorship exhaustion |
| Contest auditing | Sherlock and HackenProof audit contests |
| Bug bounty research | Immunefi, HackenProof |

---

## Contact

- Email: `r_boucheraine@estin.dz`
- Handle: `R4Y4N3`
- GitHub: `Rayane-Boucheraine`
