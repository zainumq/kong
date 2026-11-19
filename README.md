# $KONG Bonding-Curve Contracts

Foundry project for the Kong Alpha $KONG token sale. **Deployed (v3,
19 Nov 2026)** on BNB Chain — see "Deployed contracts (v3)" below.
Sale opens 1 Dec 2026 00:00 WIB. Mint page:
https://zainumq.github.io/kong/

Design authority: `docs/DESIGN.md` (rising 3-tier curve; the flat-1-USDT
alternative was offered and NOT chosen).

**v3 (current, 19 Nov 2026):** fixes the critical v2 USDT decimals bug —
BSC USDT has **18 decimals**, not 6, so the v2 prices (1e6 raw) were worth
1e-12 USDT/share. The deployed v2 contracts are ABANDONED (immutable;
750M KONG locked in the old sale + 100M in each old vesting cannot be
recovered). v3 is a fresh token + fresh sale with 18-decimal prices
(1e18 / 1.5e18 / 2e18); all other logic, including referral, is
identical. See docs/DESIGN.md §16 and the regression tests
(`KongDecimals.t.sol`, `KongDecimalsFork.t.sol`).

## Deployed contracts (v3, BSC mainnet)

| Contract | Address |
|----------|---------|
| KongToken | `0x410eAA536d701c5096619be8cBB6D46643796ee4` |
| KongSale | `0x2F3728AABD454530302B9d2B66e9986f3ac1A3e3` |
| KongMintPass | `0x615AAaFF423f1005B7bF51e3dEC6BbF5958Af89B` |
| Treasury vesting | `0xd895ca5F431bA80687Bc9bf614EF850472E19f8B` |
| Team vesting | `0x11151065995e0B2B6989038181Dd42902ae28078` |

Deployed 19 Nov 2026 (token tx `0xa0fd4ecf…`, sale tx `0xd23294be…`).
Source verified on BscScan and Sourcify (exact match). Funding complete:
sale 750M KONG, each vesting 100M, deployer holds 50M (community).
Sale starts 1 Dec 2026 00:00 WIB (`saleStart` 1796058000).

## Contracts

| Contract | What it does |
|----------|--------------|
| `KongToken` | ERC-20 "Kong" / "KONG", fixed 1,000,000,000 supply (18 decimals), minted once to the deployer. No mint/burn/owner after deploy. |
| `KongMintPass` | ERC-721 "Kong Mint Pass" / "KONGPASS", max 10,000. 1 pass = 1 share. Freely transferable. Records the tier (1/2/3) per tokenId; each tier has its own artwork (see below). ERC-2981 royalty 5% to treasury. Mint/burn only by KongSale. |
| `KongSale` | The sale + escrow + graduation + refund contract. Holds all USDT escrow and 750M KONG (485M claims + 250M liquidity + 15M referral pool). Deploys its own KongMintPass and both KongVesting contracts in the constructor (factory pattern — no two-step setup, fully immutable after deploy). |
| `KongVesting` | Linear vesting with cliff (one instance for treasury 100M, one for team 100M). Clock starts at graduation only. |
| `interfaces/` | Minimal `IAgentID` (balanceOf only) and `IPancakeRouter02` (addLiquidity only). |

**No owner/admin/pause/withdraw anywhere.** The only fund movements are
the defined graduation split, refunds, claims, referral claims, and
vesting releases.

## How it works

1. **Mint** — Buyer (must hold an Agent ID, max 10 passes/wallet) calls
   `mintPass(amount, referrer)` with USDT approved. Price is per share by
   share number: shares 1–2,500 @ 1 USDT (Tier 1, claims 60,000 KONG),
   2,501–6,000 @ 1.5 USDT (Tier 2, 50,000), 6,001–10,000 @ 2 USDT
   (Tier 3, 40,000). A purchase spanning a tier boundary is priced
   per share. Each pass stores its tier and the exact USDT paid.
   `referrer` is the referrer's address, or `address(0)` for none
   (see Referral below).
2. **Graduation** — Once 10,000 shares sell, anyone may call `graduate()`
   (permissionless; see below). Claims open; pass holders burn their pass
   for the tier's token amount (`claim` / `claimMany`); referrers claim
   accrued rewards via `claimReferral()`.
3. **Refund** — If the 30-day deadline passes without selling out, a
   14-day refund window opens: any pass holder burns their pass for a
   100% USDT refund (`refund` / `refundMany`). After the window closes,
   `sweepUnclaimed()` sends remaining USDT escrow to treasury (disclosed
   upfront in docs/DESIGN.md §6). Only USDT is swept; unclaimed KONG stays
   locked (see "Decisions"). Referral rewards are void on a failed sale.

## Referral (on-chain, added 19 Nov 2026 — v2)

The first deploy attempt was stopped before completion so this feature
could be added. `mintPass` takes a `referrer` parameter:

- **Referrer must hold a Mint Pass** at mint time (`balanceOf > 0` on
  the pass contract). If the referrer holds no pass, the referral is
  silently ignored — the mint succeeds, no reward accrues, no revert.
  (Deliberate: a buyer mistyping or pasting a stale referral link must
  never lose their purchase. Frontends should validate the referrer
  holds a pass before minting.)
- **Self-referral reverts** (`referrer == buyer`).
- **Reward: 3% of the referred buyer's claimable KONG per share** —
  Tier 1: 1,800; Tier 2: 1,500; Tier 3: 1,200 KONG (exact integers, no
  rounding). Accrued at mint time in `referralEarned[referrer]`;
  multi-share purchases spanning tier boundaries accrue per share.
- **Claim:** `claimReferral()` — after graduation only (reverts before
  graduation, reverts on double-claim / zero balance). The referrer
  does NOT need to still hold a pass to claim. Paid from the 15M KONG
  referral pool held by the sale.
- **Funding:** the 15M pool comes from the community allocation, which
  drops 65M → 50M. Max possible payout is 3% of 485M = 14.55M < 15M,
  so the pool always covers it. Any leftover pool stays locked (no
  recovery function — consistent with the no-admin design).
- **Views/events:** `referralEarned(address)` (public mapping),
  `referralClaimable(address)` (0 before graduation),
  `referralOfShare(shareNumber)`; events `ReferralReward(referrer,
  buyer, amount)` and `ReferralClaimed(referrer, amount)`.
- **Graduation funding check:** `graduate()` now requires the sale to
  hold the full 750M KONG (claims + liquidity + referral pool), so
  every post-graduation payout is covered.

## Per-tier artwork (requirement added 19 Nov 00:03 WIB)

Each tier has its own image. The 3 image URIs are constructor parameters
of `KongSale` (passed through to `KongMintPass`), stored with no setter
— immutable in practice. (Solidity does not allow `string immutable`, so
"set once in constructor, no setter" is the pattern.)

**Artwork READY (19 Nov 00:53 WIB)** — hosted on GitHub Pages
(`zainumq/kong`, `docs/`), verified HTTP 200:
- Tier 1 (gold): `https://zainumq.github.io/kong/kong-pass-tier1.jpg`
- Tier 2 (silver): `https://zainumq.github.io/kong/kong-pass-tier2.jpg`
- Tier 3 (bronze): `https://zainumq.github.io/kong/kong-pass-tier3.jpg`
Use these exact URIs as constructor params 9–11 at deploy. Local masters
in `artwork/`.

`tokenURI` returns fully on-chain base64 JSON metadata with the token's
own tier image embedded, plus attributes: Tier, Claimable KONG, Share.
`tokenURI` is a view (free to read). A public `tierImageURI(tier)` view
lets frontends read a tier's artwork without decoding JSON.

Verified: Tier 1/2/3 tokenURIs decode to different images and correct
claimable amounts (60,000 / 50,000 / 40,000).

## Graduation choice: on-chain via PancakeSwap V2

`graduate()` creates the liquidity pool **on-chain** through the
PancakeSwap V2 router:

- `addLiquidity(KONG, USDT, 250M KONG, 80% of raised USDT, 0, 0, DEAD,
  block.timestamp)` — LP tokens go to the dead address
  (`0x000000000000000000000000000000000000dEaD`), permanently locked.
  Nobody — not even the creator — can ever remove the initial liquidity.
  This is the safer option vs. sending LP tokens to treasury (which
  would let the creator pull liquidity later).
- 20% of raised USDT goes to treasury in the same transaction.
- Both vesting clocks start at graduation.
- `amountAMin`/`amountBMin` are 0: this is initial liquidity for a new
  pair, so there is no existing pool price to protect against.
- **Atomic + retryable:** if the router call reverts, the whole
  transaction reverts (including the `graduated` flag) and `graduate()`
  can simply be called again. There is no state in which graduation is
  half-done.

At full sell-out the split is exact: 12,600 USDT + 250M KONG to the pool,
3,150 USDT to treasury (asserted in `test_GraduationSplit`).

## Deploy parameters

Mainnet addresses (BSC):

| Parameter | Value |
|-----------|-------|
| USDT | `0x55d398326f99059fF775485246999027B3197955` |
| Agent ID | `0x60b9262456de011f7d15a54cdd8c48baaa8b022f` |
| PancakeSwap V2 router | `0x10ED43C718714eb63d5aA57B78B54704E256024E` |

### Step 1 — Deploy KongToken
Constructor: none. Deployer receives 1,000,000,000 KONG.

### Step 2 — Deploy KongSale
Constructor (11 params, in order):

| # | Param | Value / note |
|---|-------|--------------|
| 1 | `kong_` | KongToken address from step 1 |
| 2 | `usdt_` | USDT address above |
| 3 | `agentId_` | Agent ID address above |
| 4 | `router_` | PancakeSwap V2 router above |
| 5 | `treasury_` | `0xed1A29F81a61029089Ad8D641670baD47bDced3A` (MetaMask Account 16 — user decision 19 Nov 01:05 WIB) |
| 6 | `team_` | `0xed1A29F81a61029089Ad8D641670baD47bDced3A` (same — user decision 19 Nov 01:05 WIB) |
| 7 | `community_` | `0xed1A29F81a61029089Ad8D641670baD47bDced3A` (same — user decision 19 Nov 01:05 WIB) |
| 8 | `saleStart_` | `1796058000` (= 1 Dec 2026 00:00 WIB / 30 Nov 2026 17:00 UTC — user decision 19 Nov 01:05 WIB) |
| 9 | `tier1Image_` | `https://zainumq.github.io/kong/kong-pass-tier1.jpg` |
| 10 | `tier2Image_` | `https://zainumq.github.io/kong/kong-pass-tier2.jpg` |
| 11 | `tier3Image_` | `https://zainumq.github.io/kong/kong-pass-tier3.jpg` |

The constructor deploys KongMintPass + both KongVesting contracts.
Read their addresses from `sale.pass()`, `sale.treasuryVesting()`,
`sale.teamVesting()`.

### Step 3 — Fund the contracts (deployer transfers KONG)
| Transfer | Amount | To |
|----------|--------|----|
| Claims + liquidity + referral pool | 750,000,000 KONG | KongSale address |
| Treasury vesting | 100,000,000 KONG | `treasuryVesting` address |
| Team vesting | 100,000,000 KONG | `teamVesting` address |
| Community | 50,000,000 KONG | community address |

### Step 4 — Verify before launch
- `sale` KONG balance == 750M; each vesting == 100M; community == 50M.
- `pass.tierImageURI(1/2/3)` return the real artwork URIs.
- `pass.royaltyInfo(1, 100 ether)` returns (treasury, 5 ether).
- `sale.saleActive()` is true at/after `saleStart`.
- `sale.REFERRAL_POOL()` == 15M; `sale.SALE_FUNDING()` == 750M.
- Verify source on BscScan + Sourcify (flattened source, solc 0.8.24,
  optimizer 200 runs, EVM Cancun) — same process as AgentQuest.

## Gas estimates (forge gas report, optimizer 200)

| Action | Gas | ~BNB @ 0.1 gwei | ~IDR @ 0.1 gwei* |
|--------|-----|-----------------|------------------|
| Deploy KongToken | 551,214 | 0.0000551 | ~Rp573 |
| Deploy KongSale (incl. pass + 2 vestings) | 4,581,843 | 0.0004582 | ~Rp4.765 |
| Fund transfers (4× KONG transfer) | ~206,000 | 0.0000206 | ~Rp214 |
| `mintPass(1)` | ~244,000 | 0.0000244 | ~Rp254 |
| `mintPass(1)` with referrer | ~238,000 first accrual / ~204,000 repeat | 0.0000238 / 0.0000204 | ~Rp248 / ~Rp212 |
| `mintPass(10)` | ~853,000 | 0.0000853 | ~Rp887 |
| `claim` (1 pass) | ~80,000 (max 103,552) | 0.0000080 | ~Rp83 |
| `claimMany` (8 passes) | 238,325 | 0.0000238 | ~Rp248 |
| `claimReferral` | ~50,000 (max 78,496) | 0.0000050 | ~Rp52 |
| `refund` (1 pass) | ~52,000 (max 91,196) | 0.0000052 | ~Rp54 |
| `graduate` | ~418,000 | 0.0000418 | ~Rp435 |
| `release` (vesting) | ~59,000 (max 87,254) | 0.0000059 | ~Rp61 |

Total deploy + funding ≈ 5,339,000 gas ≈ 0.0005339 BNB ≈ **Rp5.600**.

\* IDR at 1 BNB ≈ Rp10,4 jt (rate implied by the AgentQuest claimAll
receipt, 18 Nov 2026) and 0.1 gwei gas price. Real cost scales with the
live gas price. BSC gas observed in this project: 0.065–0.128 gwei.

## Tests

```bash
export TMPDIR="$HOME/workspace/.tmp-foundry"   # /tmp is a 512MB tmpfs
forge test
```

**54 tests passed, 0 failed, 1 skipped** (19 Nov 2026, v3 with referral
+ decimals fix). The skipped suite is the fork test, which needs
`BSC_RPC_URL` (see below); with it set, **56 passed, 0 failed**. Suites:

- `KongSale.t.sol` (18): deployment wiring, tier pricing + boundaries
  (2500/2501, 6000/6001, incl. fuzz over all 10,000 shares), mint
  spanning a tier boundary, max-10-per-wallet, Agent ID gate,
  before-start / after-deadline minting, graduation split (exact 80/20:
  12,600 USDT + 250M KONG to pool, 3,150 USDT to treasury), graduation
  after deadline, claim before/after graduation (exact per-tier amounts,
  double-claim, non-owner, transfer-then-claim, batch claim), full refund
  flow (exact per-tier refunds, window close, sweep).
- `KongReferral.t.sol` (14): per-tier referral amounts (1,800 / 1,500 /
  1,200), self-referral reverts, referrer without a pass (mint succeeds,
  no reward — incl. after transferring the pass away), address(0)
  referrer, multi-share + tier-spanning accrual (exact sums), fuzz
  accrual vs the per-share schedule (256 runs), claimReferral before
  graduation reverts, after graduation pays exact amount, double-claim
  reverts, claim after selling the pass, referral void on failed sale
  (even after sweep), max-payout pool accounting (full 10,000-share
  fill, all referred: exactly 14,532,000 earned < 15M pool).
- `KongMintPass.t.sol` (9): tier recording, per-tier tokenURI (pairwise
  different; base64 JSON decoded off-chain and verified: correct image
  + claimable per tier), tier image URIs, 5% royalty + ERC-2981
  interface, burn, transferability, access control.
- `KongVesting.t.sol` (6): cliff (nothing before 90 days), linear
  release (exactly 50% at halfway, 25% at quarter), full release,
  access control, anyone-can-release.
- `KongReentrancy.t.sol` (4): malicious KONG re-entering `claim()`,
  malicious USDT re-entering `refund()`, malicious router re-entering
  `graduate()`, malicious KONG re-entering `claimReferral()` — all four
  attacks revert with state unchanged.
- `KongDecimals.t.sol` (3, v3 regression): the mock USDT's decimals are
  pinned to 18 (the v2 mock returned 6); tier prices are asserted
  against the payment token's OWN `decimals()` (read live, never
  hardcoded) — 1 / 1.5 / 2 USDT and a 15,750 USDT full raise; a
  not-dust sanity check (T1 > 1e12 raw). Proven to FAIL against the
  old 6-decimal code (2 of 3 fail with the mock reverted to 6).
- `KongDecimalsFork.t.sol` (2, v3 regression, fork): reads `decimals()`
  from the REAL mainnet USDT contract
  (0x55d398326f99059fF775485246999027B3197955) on a BSC fork and asserts
  it equals 18 and the mock's decimals, then deploys a fresh sale
  against the real token and asserts its tier prices equal 1 / 1.5 / 2
  USDT at mainnet decimals. Run with
  `BSC_RPC_URL=https://bsc-dataseed2.bnbchain.org forge test
  --match-contract KongDecimalsForkTest`; skipped automatically when
  `BSC_RPC_URL` is unset, so plain `forge test` never needs network.

## Decisions on ambiguous spec points

1. **Vesting duration.** docs/DESIGN.md says "Vesting 12 bulan (cliff 3
   bulan)" — ambiguous between 12 months total vs. 12 months after the
   cliff. The build task states "3-month cliff, then linear over 12
   months", so: cliff 90 days + linear 365 days = fully vested at
   start + 455 days.
2. **Vesting clock starts at graduation**, not at deploy — the sale
   calls `vesting.start()` inside `graduate()`. The clock never runs
   during the sale.
3. **LP tokens to the dead address** (permanently locked), not to
   treasury — see "Graduation choice" above.
4. **Router min amounts 0/0** — initial liquidity for a new pair.
5. **Tier images as 3 explicit constructor URIs** (not a base-URI
   pattern) — most flexible, since artwork may live anywhere.
6. **tokenURI is on-chain base64 JSON** with an external image URI:
   metadata immutable on-chain, only the image file is external.
7. **`saleStart` is a constructor parameter**, not deploy time — the
   sale can be deployed ahead of launch. Must be >= deploy time.
8. **`graduate()` is a separate, permissionless call**, not automatic
   on the 10,000th mint — the last minter should not pay the
   pool-creation gas, and anyone (incl. the creator) can trigger it.
9. **Graduation is allowed after the deadline** — the deadline blocks
   minting, not graduation. A sale that sells out on day 30 still
   graduates.
10. **Failed sale: unclaimed KONG stays locked.** No recovery function
    exists (by design — no admin key). Without graduation there is no
    pool and the tokens have no market.
11. **Community 50M goes directly to the community address** at deploy
    (a plain transfer, not a distributor contract). Distribution is
    decided in `docs/agentquest-kong-benefit-plan.md` (Split 30M:
    10M holder airdrop + 20M buyer bonus for AgentQuest badge holders,
    snapshot at graduation, via a Merkle distributor). (Was 65M in v1;
    15M moved to the referral pool in v2.)
12. **The 10-pass cap counts minting, not holding.** Transfers do not
    free up mint quota.
13. **Claims/refunds follow the current owner** (passes are
    transferable) — the original minter has no special rights.
14. **No on-chain allowlist phase.** docs/DESIGN.md §10 mentions a 48-hour
    allowlist for AgentQuest badge holders before public launch. That is
    a launch-sequencing step, not a contract mechanic in the build spec:
    the sale opens to all Agent ID holders at `saleStart`. If an
    enforced on-chain allowlist is wanted, it is a follow-up change
    (e.g. a second sale phase gated on AgentQuest `balanceOf > 0`).
15. **USDT approval is the buyer's responsibility** (standard
    `approve` + `transferFrom`); the sale never pulls without approval.
16. **`block.timestamp` windows** (sale/refund/vesting) — standard for
    day-scale windows; BSC block-time manipulation is negligible at
    this scale.
17. **Lint warnings reviewed, not fixed:** forge lint flags
    `block.timestamp` comparisons, reverts inside the claim/refund
    loops, and events emitted after the (trusted, own-contract) burn
    call. All are intentional and safe under the reentrancy guard.
18. **Referrer without a pass does NOT revert** (v2): the mint proceeds
    with no reward. A buyer with a mistyped or stale referral link must
    never lose their purchase; frontends should validate the referrer
    holds a pass before minting. Self-referral DOES revert (it is
    always a deliberate attempt to game the reward).
19. **Referral rewards are void on a failed sale** (v2): claimReferral
    requires graduation, same as normal claims. No graduation, no
    referral claims — even after the refund window and sweep.
20. **Referrer need not still hold a pass to claim** (v2): rewards were
    earned at mint time and belong to the referrer regardless of later
    transfers/claims of their own passes.
21. **Leftover referral pool stays locked** (v2): no recovery function,
    consistent with the no-admin design. Max payout 14.55M < 15M pool,
    so at least 450,000 KONG always remains locked in the sale.
22. **graduate() requires the full 750M funding** (v2, strengthened from
    the v1 check of 250M liquidity only): graduation must guarantee
    every post-graduation payout — pass claims (485M) and referral
    claims (≤14.55M) alike. An underfunded sale cannot graduate.
23. **KongToken.sol is byte-identical to v1** (v2): only KongSale
    changed. Its header comment now lists the v2 allocation (15M
    referral pool, 50M community) after a comment-only fix; the
    authoritative allocation is docs/DESIGN.md §4 and this README.
24. **BSC USDT has 18 decimals, NOT 6** (v3 — the critical fix): the v2
    sale priced shares at 1e6 raw units assuming 6 decimals (Ethereum
    USDT). BSC USDT returns `decimals() == 18` (verified on-chain
    19 Nov 2026; totalSupply ~9.18B USDT at 18 decimals), so v2 prices
    were worth 1e-12 USDT/share and the sale would have been
    effectively free. v3 prices are TIER1 = 1e18, TIER2 = 1.5e18,
    TIER3 = 2e18, FULL_RAISE_USDT = 15_750e18. The deployed v2
    contracts are abandoned (immutable); v3 is a fresh token + sale.
    Rule going forward: ALWAYS read `decimals()` live from the real
    token before writing price constants — never assume it from
    another chain's deployment of the "same" token.
25. **Test mocks must match mainnet exactly** (v3): all 51 v2 tests
    passed with the bug because the mock USDT baked in the same wrong
    6-decimal assumption. The mock is now 18 decimals, `KongDecimals`
    pins it to mainnet, and a fork test cross-checks prices against
    the real USDT contract. Any future mock of a mainnet token must
    be verified against the live contract.

## Toolchain

Foundry 1.9.0, solc 0.8.24, OpenZeppelin v5.7.0, optimizer 200 runs,
EVM Cancun — same as the AgentQuest build. `TMPDIR` must point under
home (`~/workspace/.tmp-foundry`) because `/tmp` is a 512 MB tmpfs.
