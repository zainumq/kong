# Self-audits — $KONG contracts

These are the security reviews done on the $KONG contracts before and
around deployment. Method: manual review + Foundry proof-of-concept tests
+ live testnet verification, the same process used in bug-bounty auditing.

**Honest scope note:** these are self-audits by the builder's own agent,
not independent third-party audits. They are published so buyers, holders
and reviewers can read the exact findings — including the medium findings
and the accepted trade-offs — instead of taking a "audited" label on trust.
A paid independent audit is planned after the sale graduates, funded from
the treasury share.

| Report | Contract(s) | Date | Verdict |
|---|---|---|---|
| [kong-v3-20261119.md](kong-v3-20261119.md) | KongToken, KongSale, KongMintPass, KongVesting (v3, mainnet) | 19 Nov 2026 | C0 / H0 / M1 / L3 / I8 |
| [kong-market-oracle-20261122.md](kong-market-oracle-20261122.md) | KongMarketOracle (testnet; mainnet deploy after sale opens) | 22 Nov 2026 | C0 / H0 / M1 / L3 / I6 |
| [kong-merkle-distributor-20261123.md](kong-merkle-distributor-20261123.md) | KongMerkleDistributor (mainnet, funded 33M KONG) | 23 Nov 2026 | C0 / H0 / M2 / L2 / I6 |
| [kong-community-vesting-20261123.md](kong-community-vesting-20261123.md) | KongCommunityVesting (mainnet, funded 10M KONG) — design + audit note | 23 Nov 2026 | C0 / H0 / M0 / L3 / I3 |

All five mainnet contracts are verified on BscScan and Sourcify
(exact_match). Contract addresses and verification links are on the
[allocation page](https://zainumq.github.io/kong/allocation.html).

Found something we missed? Open an issue on this repo.
