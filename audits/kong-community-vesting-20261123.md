# KongCommunityVesting — design + audit note (23 Nov 2026, rev. 2)

Locks the **vested portion of the community reserve — 10,000,000 KONG**
— so it cannot be dumped at once. This is option C (split) from the
user's 23 Nov decision: of the 17M that remains after the 33M
KongMerkleDistributor funding, 10M is vested here and the other 7M
stays liquid in Account 16 for community programs. After the
distributor takes its 33M and this vesting takes its 10M, the deployer
wallet's 50M community allocation is fully accounted for on-chain:
33M distributor + 10M vesting + 7M liquid.

**Schedule history (same day, 23 Nov 2026):** the contract was first
built with the treasury/team schedule (90-day cliff + 365-day linear,
17M). The user then chose a 1-month full release, and the schedule was
parameterised (cliff 0 + 30 days). The user then refined it once more:
**"kunci ajah 14 hari dulu" — cliff 14 days + linear 16 days = fully
vested at deploy + 30 days.** The contract code is unchanged since the
parameterisation; only the planned deploy values changed. The two
earlier testnet deployments (17M/90+365 and 10M/0+30) are superseded
and recorded in §5 for history only.

## 1. Why KongVesting could NOT be reused (the backdating trap)

`KongVesting.start(uint256)` takes the start timestamp as a **caller-supplied
argument**, and only the immutable `sale` address may call it. `KongSale`
only ever starts its own two vestings (treasury + team) inside `graduate()`.
So a standalone KongVesting has exactly two options, both broken:

- **sale = KongSale** → `start()` is never called for this contract (the sale
  doesn't know it exists) → `startTimestamp` stays 0 forever → the funds are
  **locked forever**, not vested.
- **sale = owner (Account 16)** → the owner can call `start()` with ANY
  timestamp, including a backdated one (e.g. deploy − 455 days) → the whole
  allocation vests **instantly**. The lock would be theatre: one transaction
  undoes it, and nobody could tell from the contract whether the timestamp
  was honest.

`KongCommunityVesting` removes the trap by removing the choice: there is no
`start()` function at all. `startTimestamp` is set to `block.timestamp` in
the constructor, so **the deploy transaction IS the start**. No sale
dependency, no owner/admin, no caller-supplied timestamp, no second
transaction that could be forgotten or abused.

## 2. Contract

`kong/src/KongCommunityVesting.sol` (Solidity 0.8.24, OpenZeppelin v5,
same toolchain as the rest of the $KONG suite: solc 0.8.24, optimizer 200
runs, EVM Cancun).

| Item | Value |
|---|---|
| Token | KongToken `0x410eAA536d701c5096619be8cBB6D46643796ee4` (immutable, constructor arg) |
| Beneficiary | Account 16 `0xed1A29F81a61029089Ad8D641670baD47bDced3A` (immutable, constructor arg) |
| Cliff | 14 days (1,209,600 seconds), zero release — immutable, constructor arg |
| Linear duration | 16 days (1,382,400 seconds) after the cliff — immutable, constructor arg |
| Fully vested | deploy + 30 days |
| Release rate | 625,000 KONG/day after the cliff (at a 10,000,000 allocation) |
| `startTimestamp` | `block.timestamp` at deploy (immutable) |
| `release()` | callable by anyone, sends to the beneficiary only, `nonReentrant`, reverts `NothingToRelease` when 0 |
| Views | `vested()`, `releasable()`, `totalAllocated()` (= balance + released), `released`, `cliff()`, `duration()` |
| Events | `Released(uint256 amount)` |
| Fund-exit paths | `release()` only. NO owner, NO withdraw, NO sweep. |

Constructor: `(token, beneficiary, cliffSeconds, durationSeconds)`.
`durationSeconds` must be > 0 (enforced, `"duration zero"`); `cliffSeconds`
may be 0. The schedule is a deploy-time parameter so the release speed is
a visible, one-time decision — fixed forever once deployed, never
changeable afterwards.

If the beneficiary key is lost, the funds stay locked — the same trust
model as the treasury/team vestings. This is by design, not an oversight.

### Trust trade-off (accepted by the user, 23 Nov 2026)

A 30-day full release — 14-day hard lock, then 16 days linear — is a
**much shorter lock than the treasury/team 455-day schedule**. It prevents
any movement for two weeks and any instant dump thereafter (the fastest
possible extraction is 625,000 KONG/day after the cliff), but it is not
a long-term lock: the full 10M is releasable one month after deploy.
This is a deliberate user decision, stated honestly: the community
reserve exists to fund community programs, and a 15-month lock would
leave it unusable when programs need it. The accounting page must state
the 30-day schedule plainly and must NOT describe this vesting as
equivalent to the treasury/team locks.

## 3. Schedule (concrete dates)

The clock starts at the deploy block. Cliff ends at deploy + 14 days,
fully vested at deploy + 30 days. Assuming a late-Nov-2026 deploy:

| Deploy date | Cliff ends (first release possible) | Fully vested |
|---|---|---|
| Tue 24 Nov 2026 | Tue 8 Dec 2026 | Thu 24 Dec 2026 |
| Wed 25 Nov 2026 | Wed 9 Dec 2026 | Fri 25 Dec 2026 |
| Mon 30 Nov 2026 | Mon 14 Dec 2026 | Wed 30 Dec 2026 |

Mid-schedule example (deploy 24 Nov 2026): at day 22 (Tue 16 Dec 2026,
halfway through the linear period) exactly 5,000,000 KONG is vested;
at day 15 (Wed 9 Dec 2026, one day after the cliff) exactly 625,000.

## 4. Tests — 11/11 pass

`kong/test/KongCommunityVesting.t.sol` (`forge test --match-contract
KongCommunityVestingTest`), main instance mirrors the mainnet plan
(cliff 14 days, duration 16 days, 10,000,000 KONG):

- deploy sets `startTimestamp == block.timestamp`, token/beneficiary/cliff/duration correct
- constructor rejects zero token / zero beneficiary / zero duration
- nothing vested at deploy, at day 13, or at day 14 (end of cliff, elapsed == 0); `release()` reverts `NothingToRelease` at all three points
- 1 second after the cliff, vested equals the exact linear fraction (`ALLOCATION / DURATION`)
- day 15 (1 day into linear): exactly 625,000
- day 18 (quarter through linear): exactly 2,500,000
- day 22 (halfway through linear): exactly 5,000,000 vested + released
- partial (day 22) then full (day 30): beneficiary ends with exactly 10,000,000, vesting balance 0, further `release()` reverts
- far past the end, `vested()` stays capped at the allocation
- `release()` called by a third party still pays the beneficiary only
- `totalAllocated()` stays 10,000,000 across partial and full releases
- parameterisation proof: a second instance (cliff 0, duration 30 days,
  9,000,000 KONG) behaves per ITS schedule — 0 at deploy, 4,500,000 at
  day 15, 9,000,000 at day 30 — while the main instance is unaffected

Full project suite: **185/185 pass** (2 skipped, pre-existing)
across 13 suites, including KongMerkleDistributorTest (20) and
KongVestingTest (6). No existing contract was touched.

## 5. Testnet live test (BSC testnet, chain 97) — 23 Nov 2026

Reused the mock KongToken from the distributor testnet run
(`0xE99938E1f4645E7E98a17a9064805fFdDB4D0CFE`); deployer held 940,133,000
test KONG before this run. Script: `kong/script/DeployCommunityVestingTestnet.s.sol`.

| Item | Value |
|---|---|
| KongCommunityVesting (testnet) | `0xb6f776068c80cd05b686b42ff58cdf805a9d7e80` |
| Deploy tx | `0xa076e1cc7f06ee459c2ee46331f7a80ece71704d3d0f625704547a2f19d9cae4` (block 144392728, gas 453,081, status 1) |
| Funding tx (10,000,000 test KONG) | `0xa87a86b837fdbaa21914ac056be7293d483db016dd3a6e0b337cb51266b7b848` (block 144392728, gas 51,638, status 1) |
| Deploy block timestamp | 1795431406 = Mon 23 Nov 2026 17:56:46 WIB |
| Cliff ends (testnet) | Mon 7 Dec 2026 17:56 WIB |
| Fully vested (testnet) | Wed 23 Dec 2026 17:56 WIB |

Live verification (cast, all confirmed on-chain):
- `startTimestamp()` == 1795431406 == deploy block timestamp
- `beneficiary()` == testnet deployer `0x5951eBe74f43CbA573064a23dE2EAcA18F6a1601`
- `token()` == mock KONG; `cliff()` == 1,209,600 (14 days); `duration()` == 1,382,400 (16 days)
- `balanceOf(vesting)` == `totalAllocated()` == 10,000,000 test KONG
- `vested()` == `releasable()` == `released()` == 0 (inside the 14-day cliff)
- `release()` reverts `NothingToRelease` (selector `0xb10205ed`)

Mainnet deploy cost estimate (from the testnet receipt, 453,081 gas):
~0.0000227 BNB at 0.05 gwei (~Rp243) / ~0.0000453 BNB at 0.1 gwei
(~Rp486); funding transfer ~51,638 gas (~Rp55 at 0.1 gwei). IDR at
~Rp10,7 jt/BNB. Total mainnet cost ≈ Rp300–550.

### Superseded testnet deployments (history only)

- `0x083a3e04380bbc23257c5e79f1aa8fb7ef6d057c` — first build: 17,000,000
  test KONG, 90-day cliff + 365-day linear (deploy tx `0xf86d77d0…`,
  funding tx `0xee423100…`, 23 Nov 2026 ~17:30 WIB). Superseded by the
  user's schedule decision; the contract at this address is the old
  constant-schedule version.
- `0x9C6717CFC494cA00F7CbF6491e74f31e9A90CE18` — interim parameterised
  build: 10,000,000 test KONG, cliff 0 + 30 days (deploy tx
  `0xb9eb1a0c…`, funding tx `0x182babf2…`, 23 Nov 2026 ~17:52 WIB).
  Superseded within the hour by the 14+16 schedule. Note: with cliff 0,
  `vested()`/`releasable()` became non-zero within seconds of deploy
  (linear release from block 0) — expected behaviour for that config,
  and the reason the live `release()`-reverts check only holds at the
  exact deploy block for a cliff-0 instance.

## 6. Self-audit findings

**C0 / H0 / M0 / L3 / I3.** No critical, high, or medium findings.
(The short 30-day schedule is a deliberate user decision, documented
as a trust trade-off in §2 — not a contract vulnerability.)

- **L-1 — Donated tokens vest too.** `totalAllocated()` = balance +
  released, so any KONG sent to the contract after deploy (donation or
  fat-fingered transfer) also vests on the same schedule and becomes
  releasable to the beneficiary. Same behaviour as KongVesting. Impact is
  low: it only ever increases the beneficiary's payout; there is no theft
  vector and no way to extract anything except via `release()` to the
  beneficiary. No fix needed; noted for the accounting page (the 10M
  figure is enforced by the funding step, not by the contract).
- **L-2 — Funding amount is procedural, not enforced.** The contract
  accepts any funding amount; nothing on-chain forces exactly 10,000,000.
  Mitigation is the post-funding verification step in §7
  (`balanceOf(vesting) == 10,000,000` + `totalAllocated() == 10,000,000`)
  before the deploy is declared complete. A hard-coded allocation constant
  was deliberately not added: it would make the contract single-purpose
  without adding security (a wrong transfer is still possible with a
  constant — it would just revert later, at first release, instead of
  being caught at funding).
- **L-3 — Beneficiary key loss locks funds forever.** No recovery path by
  design (same as the treasury/team vestings). Accepted trust model;
  beneficiary is the builder's own Account 16.
- **I-1 — No VestingStarted event.** There is no `start()` to emit from;
  the deploy transaction plus the `startTimestamp()` view serve as the
  record.
- **I-2 — `Released` carries only the amount** (matches KongVesting;
  beneficiary and timestamp are recoverable from the tx/receipt).
- **I-3 — Linear math rounds down** (integer division). The end-of-schedule
  branch returns the full `totalAllocated()`, so rounding dust is fully
  recoverable at the final release; no funds can get stuck. Covered by
  `test_PartialThenFull` (final balance exactly 0).
- **Checked, no issue:** reentrancy (`nonReentrant` + checks-effects-
  interactions + `SafeERC20`; KONG is a plain ERC-20 with no hooks);
  `release()` to the beneficiary only regardless of caller; cliff boundary
  (`<` / `>=` — exactly at the cliff, 0 vested; exactly at the end, full);
  `duration == 0` rejected in the constructor (a zero duration would make
  the linear branch unreachable-but-meaningless); immutables cannot be
  changed post-deploy; no delegatecall, no selfdestruct, no owner.

## 7. Mainnet deploy + fund steps (exact order)

Deploy via the user's MetaMask (Account 16) in the device browser with
Remix. **Do NOT broadcast from this VM** — the deployer key is not here.

**Precondition — distributor first.** Account 16 holds exactly 50,000,000
KONG. The KongMerkleDistributor must already have taken its 33,000,000
before this vesting is funded, leaving exactly 17,000,000. Check
`balanceOf(Account 16) == 17,000,000` before the funding transfer; if it
is still 50,000,000, the distributor funding has not happened yet — stop.

1. **Deploy** (Remix, MetaMask Account 16, BSC mainnet chain 56):
   flattened source `kong/flattened/KongCommunityVesting.flattened.sol`,
   solc 0.8.24, optimizer 200 runs, EVM Cancun. Constructor args:
   token `0x410eAA536d701c5096619be8cBB6D46643796ee4`,
   beneficiary `0xed1A29F81a61029089Ad8D641670baD47bDced3A`,
   cliff `1209600` (14 days), duration `1382400` (16 days)
   (encoded args in `kong/flattened/kong-community-vesting-constructor-args-encoded.txt`).
   **The clock starts the moment this transaction confirms** — deploy only
   when ready to start the 30-day schedule.
2. **Before any retry:** if Remix reports an error, check on-chain first
   whether the first attempt actually confirmed (Remix error messages lie).
   Never deploy twice.
3. **Verify** source on BscScan + Sourcify (same compiler settings).
4. **Verify state** (read-only): `startTimestamp()` == deploy block
   timestamp, `beneficiary()` == Account 16, `token()` == KongToken,
   `cliff()` == 1209600, `duration()` == 1382400, `releasable()` == 0.
5. **Fund:** transfer exactly **10,000,000 KONG** from Account 16 to the
   vesting contract (one transfer). Then verify `balanceOf(vesting) ==
   10,000,000` and `totalAllocated() == 10,000,000`. The remaining
   **7,000,000 KONG stays liquid in Account 16** for community programs.
6. **Record** the contract address + deploy/funding tx hashes here and on
   the accounting page. After this step, Account 16's 50M community
   allocation is fully accounted for: 33M distributor + 10M vesting +
   7M liquid.

Reference-only forge script (chain-56 guard, never broadcast from the VM):
`kong/script/DeployKongCommunityVesting.s.sol`.

## 8. Files

- `kong/src/KongCommunityVesting.sol` — contract (parameterised schedule)
- `kong/test/KongCommunityVesting.t.sol` — 11 forge tests
- `kong/script/DeployCommunityVestingTestnet.s.sol` — testnet deploy + fund
- `kong/script/DeployKongCommunityVesting.s.sol` — mainnet deploy (reference only)
- `kong/flattened/KongCommunityVesting.flattened.sol` — flattened source for Remix + verification (873 lines; compiles standalone with solc 0.8.24 and produces byte-identical creation AND runtime code to the forge build, modulo the metadata hash)
- `kong/flattened/kong-community-vesting-constructor-args-encoded.txt` — encoded mainnet constructor args (token, beneficiary, 1209600, 1382400)
- `kong/broadcast/DeployCommunityVestingTestnet.s.sol/97/run-latest.json` — testnet broadcast record (current: 0xb6f77606… deploy)

## 9. Mainnet record (23 Nov 2026, DEPLOYED + FUNDED)

- **Contract: 0xb43CF1d851d631c935e0FfD8b45016213F58bB82**
- Deploy tx **0x776736a0b08864d1dd562c859b9e53062ca72ff8db153ba2a8e9f17d2da4ca28**,
  block 135277849, Mon 23 Nov 2026 20:19:47 WIB, from Account 16
  (0xed1A29F81a61029089Ad8D641670baD47bDced3A), gas 453,081 @ 0.05 gwei
  (fee 0,00002265405 BNB — exactly the testnet estimate). Deployed via
  app.remix.live in the user's own Chrome (device browser, Injected
  Provider — MetaMask), after a long WalletConnect detour (see lessons).
- On-chain state verified independently (cast, dataseed1): token() =
  KongToken, beneficiary() = Account 16, cliff() = 1209600, duration() =
  1382400, startTimestamp() = 1795439987, releasable() = 0, released() = 0.
- **Cliff ends Mon 7 Dec 2026 20:19:47 WIB; fully vested Wed 23 Dec 2026
  20:19:47 WIB** (625,000 KONG/day linear, days 15–30).
- Sourcify v2: **exact_match** (creation + runtime), verifiedAt
  2026-11-23T13:20:00Z. BscScan: **VERIFIED** (web form; confirmed
  independently via getsourcecode API, `verify-bscscan.py --status`).
  `verify-bscscan.py` now has a "vesting" entry.
- Funding tx **0x527249e16901b2b0a1886d23f3f28b2a7f7948196ad2d9b8db0cce7f8dd65c99**,
  block 135281573, 23 Nov 20:47:44 WIB, gas 51,638 @ 0.05 gwei (fee
  0,0000025819 BNB). Transfer log confirms exactly 10,000,000 KONG
  Account 16 → vesting. Verified on-chain: vesting balance =
  totalAllocated() = 10,000,000; Account 16 KONG = 7,000,000;
  Account 16 BNB = 0,00062231 after deploy + funding. release() never
  called. Community 50M fully accounted: 33M distributor + 10M vesting +
  7M liquid.

### Deploy lessons (23 Nov evening)

- **Device browser outage was the user disabling the Muse extension.**
  All device-browser attempts failed 19:02–20:08 WIB; cause found 20:06
  when the user said he had turned the extension off. After re-enabling,
  the "Let Muse browse for you" toggle (right-click Muse icon, or side
  panel menu) ALSO had to be on, plus sign-in/intro state; availability
  is evaluated per message, so a fresh message is needed after each fix.
  Device browser came back 20:13 WIB and the deploy ran in it.
- **WalletConnect detour (cloud browser, task closed 20:05):** first
  connection landed on Sepolia because the phone MetaMask's active
  network was Sepolia; Remix follows the wallet's network. A stale
  WalletConnect session does NOT pick up a network switch in MetaMask —
  must disconnect + reconnect with a fresh QR. OKX Wallet can hold the
  same address (user connected via OKX; address identical) — the wallet
  app doesn't matter, account + network do.
- **BscScan verify:** the browser's first two web-form attempts failed
  on a stale/wrong flattened source read; the third attempt with the
  correct 873-line source succeeded. Always confirm the submitted source
  matches the deployed bytecode (Sourcify exact_match is ground truth);
  the "DeclarationError: totalAllocated" warning line on the success
  page was leftover from failed attempts, not a real problem.
- **BscScan in the cloud browser:** after the task migrated to the cloud
  browser, BscScan Cloudflare checks looped forever (token → blank →
  fresh challenge, many Ray IDs); verification badge could not be
  re-checked there. Use the getsourcecode API (verify-bscscan.py) or the
  user's own browser instead.
