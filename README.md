# R4Y4N3's Audit Portfolio 💼

**Find me at:**

- **GitHub**: [Rayane-Boucheraine](https://github.com/Rayane-Boucheraine)
- **X**: [R4Y4N3](https://x.com/R4Y4N3___)
- **Email**: r_boucheraine@estin.dz
- **Handle**: R4Y4N3

## Summary

I'm a Web3 security researcher focused on smart contract security, DeFi protocols, Solana/Rust security, and blockchain application security.

I started my Web3 security journey through CTFs, bug bounty programs, and protocol reviews. My current work focuses on audit contests, Immunefi/HackenProof bug bounty programs, and public security research.

This portfolio only includes meaningful results such as resolved contest findings, valid contest findings, duplicates, and escalated reports. Informative, not applicable, out-of-scope, and invalid reports are intentionally excluded.

<h3>Public Contests 🏆:</h3>

<table>
  <thead>
    <tr>
      <th>Date</th>
      <th>Contest / Project</th>
      <th>Platform</th>
      <th>Findings</th>
      <th>Payout</th>
      <th>Rank</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Nov 2025</td>
      <td>Rain Smart Contract Audit Contest</td>
      <td>HackenProof</td>
      <td>1 Critical, 1 High</td>
      <td>$0.75</td>
      <td>-</td>
    </tr>
    <tr>
      <td>Nov 2025</td>
      <td>stNXM by EaseDeFi</td>
      <td>Sherlock</td>
      <td>1 High, 1 Medium</td>
      <td>0.53 USDC</td>
      <td>#48</td>
    </tr>
  </tbody>
</table>

<h3>Bug Bounty Programs 🐞:</h3>

<table>
  <thead>
    <tr>
      <th>Date</th>
      <th>Program</th>
      <th>Platform</th>
      <th>Findings</th>
      <th>Status</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>May 2026</td>
      <td>Hyperbridge Protocol</td>
      <td>HackenProof</td>
      <td>3 Duplicates</td>
      <td>Duplicate</td>
    </tr>
    <tr>
      <td>Mar 2026</td>
      <td>Calyx Smart Contract</td>
      <td>HackenProof</td>
      <td>1 Duplicate</td>
      <td>Duplicate</td>
    </tr>
    <tr>
      <td>May 2026</td>
      <td>MagpieXYZ</td>
      <td>Immunefi</td>
      <td>1 High</td>
      <td>Escalated</td>
    </tr>
  </tbody>
</table>

<h3>Selected Contest Findings:</h3>

<table>
  <thead>
    <tr>
      <th>Contest</th>
      <th>Finding</th>
      <th>Severity</th>
      <th>Status</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Rain Smart Contract Audit Contest</td>
      <td>Unauthorized cancellation of sell orders leads to griefing and permanent fund freezing</td>
      <td>Critical</td>
      <td>Resolved</td>
    </tr>
    <tr>
      <td>Rain Smart Contract Audit Contest</td>
      <td>Hardcoded dispute fee cap enables trivial DoS on 18-decimal token pools</td>
      <td>High</td>
      <td>Resolved</td>
    </tr>
    <tr>
      <td>stNXM by EaseDeFi</td>
      <td><code>totalAssets</code> manipulation via Uniswap V3 spot price allowing vault drain</td>
      <td>High</td>
      <td>Valid Finding</td>
    </tr>
    <tr>
      <td>stNXM by EaseDeFi</td>
      <td>Double counting of staked assets via duplicate tranche tracking allows protocol insolvency</td>
      <td>Medium</td>
      <td>Valid Finding</td>
    </tr>
  </tbody>
</table>

<h3>Selected Bug Bounty Reports:</h3>

<table>
  <thead>
    <tr>
      <th>Program</th>
      <th>Bug Type</th>
      <th>Severity</th>
      <th>Date</th>
      <th>Status</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Hyperbridge Protocol</td>
      <td>Decimal downscaling bug in outgoing EVM amount calculation</td>
      <td>-</td>
      <td>May 2026</td>
      <td>Duplicate</td>
    </tr>
    <tr>
      <td>Hyperbridge Protocol</td>
      <td>Merkle multiproof root forgery via shift overflow</td>
      <td>-</td>
      <td>May 2026</td>
      <td>Duplicate</td>
    </tr>
    <tr>
      <td>Hyperbridge Protocol</td>
      <td>False-positive trie membership proof verification</td>
      <td>-</td>
      <td>May 2026</td>
      <td>Duplicate</td>
    </tr>
    <tr>
      <td>Calyx Smart Contract</td>
      <td>Persistent account lock via panic in withdraw callback</td>
      <td>-</td>
      <td>Mar 2026</td>
      <td>Duplicate</td>
    </tr>
    <tr>
      <td>MagpieXYZ</td>
      <td>Direct receipt-token withdrawal causes permanent freezing of helper rewards</td>
      <td>High</td>
      <td>May 2026</td>
      <td>Escalated</td>
    </tr>
  </tbody>
</table>

<h3>Security Focus Areas:</h3>

<table>
  <thead>
    <tr>
      <th>Area</th>
      <th>Experience</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>DeFi Security</td>
      <td>Vault accounting, pool logic, dispute flows, reward systems, insolvency bugs</td>
    </tr>
    <tr>
      <td>Smart Contract Auditing</td>
      <td>Solidity, EVM logic, access control, DoS, accounting bugs</td>
    </tr>
    <tr>
      <td>Solana / Rust</td>
      <td>Account lifecycle, account closure, revival attacks, PDA/state handling</td>
    </tr>
    <tr>
      <td>Proof Verification</td>
      <td>Merkle proof validation, trie proof verification, cryptographic edge cases</td>
    </tr>
    <tr>
      <td>Web3 Backend</td>
      <td>Paymaster authorization, gas sponsorship abuse, API abuse paths</td>
    </tr>
  </tbody>
</table>

<h3>Disclosure Policy:</h3>

I do not publish private exploit code, live vulnerability details, confidential screenshots, internal triage comments, or undisclosed proof-of-concept details.

For restricted reports, I only publish disclosure-safe information such as the platform, program name, severity, status, and high-level bug class.
