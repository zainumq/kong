# Self-Audit: KongMarketOracle (Chainlink dynamic BNB floor)

**Date:** 22 Nov 2026
**Auditor:** JINUUU (self-audit, same process as the v3 KONG audit 19 Nov 2026)
**Scope:** `src/KongMarketOracle.sol` (new), `script/DeployKongMarketOracle.s.sol` (new),
`test/KongMarketOracle.t.sol` (new, 26 tests). `src/KongMarket.sol` (v1) was NOT
modified and is out of scope except where code was carried over verbatim.
**Method:** manual review + Foundry tests (26/26 pass, incl. 256-run fuzz on the
floor math) + live feed verification on both chains + testnet deployment e2e
(see §5).

## Verdict

| Severity | Count |
|---|---|
| Critical | 0 |
| High | 0 |
| Medium | 1 (mitigated in the deploy script — see M-1) |
| Low | 3 |
| Info | 6 |

**No finding blocks the testnet deployment.** For mainnet, M-1's residual risk is
a deployer footgun that the script guards against; the remaining Lows are
accepted design trade-offs, documented in the contract NatSpec.

## 1. What changed vs v1 (KongMarket)

Only the BNB floor mechanism. Everything else — listing, buying, split
(royalty 5% live + fee 1%), sweep, reentrancy guard, stale-listing checks,
no-owner/no-admin/no-pause — is carried over verbatim from the audited v1.

- USDT floors: still immutable per tier (1 / 1.5 / 2 USDT, 18 decimals).
- BNB floors: derived live, `floorBnb(tier) = floorUsdt(tier) * 1e8 / bnbUsdPrice`,
  where `bnbUsdPrice` is the Chainlink BNB/USD answer (8 decimals).
- The feed address and `maxStaleness` are constructor-set immutables.
- Fail-closed: a BNB floor read reverts (`StalePrice()`) when the answer is
  <= 0, `updatedAt` is 0 or in the future, the answer is older than
  `maxStaleness`, or the round is incomplete (`answeredInRound < roundId`).
  USDT flows never touch the oracle; `cancel` never touches the oracle.

## 2. Findings

### M-1 (Medium): `maxStaleness` is a per-chain footgun — MITIGATED
The same feed has very different heartbeats per chain, measured live 22 Nov 2026:
BSC mainnet BNB/USD updates every ~30s (60s heartbeat); BSC testnet updates
~hourly (3600s heartbeat, gaps of exactly 3600s in round history). A single
hardcoded threshold cannot serve both chains, so `maxStaleness` is a
constructor parameter: 120s on mainnet, 7200s on testnet. A deployer who
mixes them up either bricks BNB listings (120s on testnet) or silently
accepts 2-hour-old prices (7200s on mainnet). The second direction is the
dangerous one: the market would look healthy while pricing floors off stale
data.

Mitigations in place:
- `DeployKongMarketOracle.s.sol` enforces per-chain bounds: mainnet
  `maxStaleness <= 3600`, testnet `maxStaleness >= 3600`. A 7200s mainnet
  deploy is refused by the script.
- The same script refuses to deploy against a feed that is ALREADY stale
  relative to `maxStaleness` at deploy time, which catches the too-tight
  direction (a 120s testnet deploy almost always fails this check, since
  the testnet feed age at a random moment is 0–3600s).
- The correct values are documented in the contract NatSpec, the script
  NatSpec, and this audit.

Residual risk: a deployer who bypasses the script (e.g. deploys via raw
`cast send` with wrong parameters) can still misconfigure the threshold.
Out of scope for the contract — the deployment procedure is the control.
**Status: mitigated; residual Low.**

### L-1 (Low): USDT ≈ USD assumption
The BNB floor converts the USDT floor through the BNB/USD price, i.e. it
assumes 1 USDT = $1. If USDT depegs, the BNB floor misprices by the same
percentage (USDT below $1 → BNB floor too high in real terms, sellers cannot
list at the true mint-equivalent price; USDT above $1 → floor too low,
sellers could underprice). The USDT floor itself is unaffected (it is
denominated in USDT), and no funds can be stolen through this — the floor
is a seller-protection guardrail, not a pricing oracle for settlement.
A second feed (USDT/USD) would remove the assumption at the cost of a
second failure mode; not worth it for a floor guardrail.
**Status: accepted, documented in NatSpec.**

### L-2 (Low): `buy` does not re-check the floor
The floor is enforced at `list` / `updatePrice` time, not at `buy` time
(same as v1). If BNB falls after a listing is created, the listed BNB price
can drift below the live floor, and the buy still executes at the agreed
price. This is the correct marketplace semantic — a listing is a firm offer
— and the seller can always `cancel` or `updatePrice`. Re-checking at buy
time would let a falling BNB price brick in-flight purchases and would
hand sellers a griefing vector (list, wait for a dip, buyer cannot buy).
**Status: accepted by design, documented in NatSpec.**

### L-3 (Low): BNB repricing unavailable during a feed outage
`updatePrice` on a BNB listing reverts with `StalePrice()` while the feed
is down (it re-reads the live floor). The seller can still `cancel` at any
time and re-list when the feed recovers, and USDT listings are unaffected.
Fail-closed by design; the alternative (repricing against a stale floor)
would defeat the floor's purpose.
**Status: accepted by design, documented in NatSpec.**

### I-1 (Info): Floor division rounds down
`floorUsdt * 1e8 / price` uses integer division, so the BNB floor is at
most 1 wei below the exact USDT-equivalent value. Negligible (1 wei of BNB
≈ $0.0000000000000005) and in the seller's favor is impossible to
distinguish from exact at these magnitudes. Rounding UP instead would make
a listing at the UI-displayed floor revert; rounding down is the right
choice for a minimum.
**Status: no action.**

### I-2 (Info): Floor can round to 0 only at an absurd price
`floorBnb` is 0 only if BNB/USD exceeds $1e18 (T1) — i.e. the price would
have to be ~1e15 times the current price. The feed's `minAnswer` /
`maxAnswer` bounds could not be read on-chain (both proxies revert on
those selectors — the current OCR feeds do not expose them), so no
on-chain upper bound could be verified; the claim rests on market reality
instead. Even in that impossible case, `list` still requires `price > 0`,
so the worst outcome is a 1-wei listing, not a free pass.
**Status: no action.**

### I-3 (Info): The market trusts the feed contract's code
`latestRoundData()` is called during `list` / `updatePrice` (state-changing
transactions). A malicious feed contract could attempt reentrancy from
inside that call. This is a deployment-time trust assumption, identical in
kind to the market's trust in the pass contract (`tierOf` /
`royaltyInfo` are called the same way): the deployer points the market at
the real Chainlink proxy, and the address is immutable afterwards. The
deploy script validates the feed (has code, 8 decimals, live positive
answer, complete round) before broadcast.
**Status: no action.**

### I-4 (Info): No L2 sequencer-uptime check
Chainlink's sequencer-uptime pattern applies to L2s (Arbitrum/Optimism),
where a sequenced outage can freeze feed updates. BSC is an L1 with no
sequencer; the pattern does not apply. The staleness check is the correct
control here.
**Status: no action (considered, N/A).**

### I-5 (Info): Feed decimals enforced only at deploy
The constructor requires `decimals() == 8`. If Chainlink ever changed a
feed's decimals (they do not — decimals are fixed per feed; a new feed
would be a new proxy address), the market would misprice BNB floors until
redeployed. Accepted: the feed address itself is immutable, and a decimals
change would be a new feed, not an in-place change.
**Status: no action.**

### I-6 (Info): `latestBnbPrice()` is a view helper
It exposes the validated (price, updatedAt) pair for frontends. It reads
the feed once via `_latestPrice()`; no state, no additional trust.
Frontends may also call the feed directly. No risk.
**Status: no action.**

## 3. Checks that passed (no finding)

- **Overflow:** `floorUsdt * 1e8` max = 2e18 * 1e8 = 2e26, far below 2^256.
  Verified by reasoning + the fuzz test (256 runs, prices $1–$10,000).
- **Underflow on `block.timestamp - updatedAt`:** guarded by the explicit
  `updatedAt > block.timestamp` check before the subtraction (Solidity 0.8
  would otherwise panic-revert — fail-closed either way, but the named
  error is cleaner).
- **Division by zero:** impossible — `answer <= 0` reverts before the
  division, and the divisor is the validated positive price.
- **USDT flows isolated from the oracle:** `floorOf` returns the USDT
  immutable without any feed call; verified by test (USDT list + buy
  succeed with a dead feed).
- **Reentrancy:** `buy` is `nonReentrant` with checks-effects-interactions,
  carried over verbatim from v1 (which has dedicated reentrancy tests).
  Oracle reads are view-only.
- **Ascending floors:** USDT floors are constructor-checked ascending; BNB
  floors derived from them with a common divisor are automatically
  ascending.
- **Constructor validation:** zero feed, feed without code, feed decimals
  != 8, zero maxStaleness, zero/non-ascending USDT floors — all revert
  (6 dedicated tests).

## 4. Assumptions not yet tested on mainnet

- The mainnet feed address (0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE)
  and the 120s threshold have been verified READ-ONLY (live
  `latestRoundData`, round-history cadence ~30s) but not exercised by a
  deployment — mainnet deploy is a separate, later step.
- The testnet deployment below exercises the real testnet feed end to end
  (live floor reads + a real BNB listing), which validates the
  proxy/round semantics (phase-encoded roundIds, `answeredInRound`)
  against a genuine Chainlink feed, not just the mock.

## 5. Testnet deployment (22 Nov 2026, ~06:30–06:45 WIB)

- **Contract (chain 97): 0x0c537BC6b9b9FD26e6B76683D05FD43C32f33ec2**
- Deploy tx: 0xe6120ab14bb9b18fcff3dad1231e439b9d0ba72334a91e07eedaf42b3f70f071
  (block 144109508, nonce 1050, status 1)
- Deploy gas: **1,477,147 gas @ 0.1 gwei = 0.0001477147 tBNB**
  (reconciles exactly with the deployer balance delta)
- Constructor params: pass 0xfB10858719919f0eA3149F2c25CBe52086dF9984 (mock pass),
  USDT 0x41de1C38502d5Ae2672470620Ac183Db566dde8A (MockUSDT),
  treasury 0x5951eBe74f43CbA573064a23dE2EAcA18F6a1601 (deployer, same as v1),
  USDT floors 1 / 1.5 / 2 ether,
  feed 0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526,
  maxStaleness 7200s. All read back on-chain and verified.
- Verification: **Sourcify v2 exact_match** (creation + runtime);
  **BscScan testnet verified** (SourceCode present, ContractName
  KongMarketOracle). Note: the Etherscan V2 `checkverifysourcecode`
  endpoint returns "Free API access is not supported for this chain" for
  chain 97 — the submission itself succeeded and `getsourcecode`
  confirms the source is live; only the poll endpoint is gated.
- BscScan: https://testnet.bscscan.com/address/0x0c537BC6b9b9FD26e6B76683D05FD43C32f33ec2

### Live e2e results (real Chainlink feed, price $547.58653840)
- `floorOf` BNB vs manual computation (`floorUsdt * 1e8 / price`):
  T1 1826195367990441 wei (0.001826195367990441 BNB) — MATCH;
  T2 2739293051985662 wei (0.002739293051985662 BNB) — MATCH;
  T3 3652390735980882 wei (0.003652390735980882 BNB) — MATCH.
- `latestBnbPrice()` returns (54758653840, 1795300529) — MATCH.
- Below-floor list (staticCall): reverts `BelowFloor` — PROVEN, no tx sent.
- At-floor list (staticCall): succeeds — PROVEN.
- Real list: pass #4 (tier 2, deployer-owned) @ floor+1% =
  2766685982505518 wei, tx 0x208f2f9869f96d963ac462215bd1cdd902304e79dbc53f51ef183ac48b9e026a
  (98,891 gas, status 1); `listingOf(4)` confirmed on-chain.
- Cancel: tx 0x434d34659bbf3b41a07a0ebd5801da754a515ad0fb4930a35c3326adc9e859ca
  (28,247 gas, status 1); `listingOf(4)` empty afterwards — no listing left stuck.
- Total session spend: 1,604,285 gas = 0.0001604285 tBNB
  (deploy + list + cancel); deployer balance 0.03183544028 → 0.03167501178 tBNB.

### Mainnet deploy parameters (for later — NOT deployed)
- Feed (mainnet): 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE
  (verified live 22 Nov 2026: 8 decimals, "BNB / USD", $547.85630063,
  round history cadence ~30s, deviation 0.1% per data.chain.link)
- maxStaleness: **120s** (2x the 60s mainnet heartbeat)
- Pass: 0x615AAaFF423f1005B7bF51e3dEC6BbF5958Af89B (real KongMintPass)
- USDT: 0x55d398326f99059fF775485246999027B3197955 (18 decimals)
- Treasury: 0xed1A29F81a61029089Ad8D641670baD47bDced3A (Account 16, same as v1 plan)
- USDT floors: 1 / 1.5 / 2 ether
- Estimated deploy gas: ~1,477,147 gas (same bytecode size class as testnet);
  at mainnet gas price 0.05 gwei (live 22 Nov 2026) ≈ **0.00007386 BNB**
  (~$0.04 at BNB $547.59). Deploy via the same script with
  EXPECTED_CHAIN_ID=56 — the script refuses a mainnet deploy with
  maxStaleness > 3600 (audit M-1 guard).
