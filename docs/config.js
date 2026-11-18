// Kong mint-page frontend configuration.
//
// All addresses are the DEPLOYED v3 contracts on BNB Smart Chain mainnet
// (deployed 19 Nov 2026 via Remix; source verified on BscScan + Sourcify).
//
// v3 fixes the v2 USDT decimals bug: BSC USDT (0x55d398…) has 18 decimals
// (verified on-chain 19 Nov 2026), and the v3 sale prices shares at
// 1e18 / 1.5e18 / 2e18 raw units = 1 / 1.5 / 2 USDT (verified on-chain:
// TIER1_PRICE() = 1e18, quote(1) = 1e18). The v2 contracts are abandoned
// and must never be pointed at again (old token 0x6D877542…,
// old sale 0x7255d2Cd…).

export const KONG_TOKEN_ADDRESS = "0x410eAA536d701c5096619be8cBB6D46643796ee4";
export const KONG_SALE_ADDRESS = "0x2F3728AABD454530302B9d2B66e9986f3ac1A3e3";
export const KONG_PASS_ADDRESS = "0x615AAaFF423f1005B7bF51e3dEC6BbF5958Af89B";
export const USDT_ADDRESS = "0x55d398326f99059fF775485246999027B3197955";

// Canonical SPACE ID Agent ID registry on BNB Chain. Never changes.
// Note: it does NOT implement totalSupply() (the call reverts) — never
// call it; eligibility is balanceOf(address) > 0.
export const AGENT_ID_ADDRESS = "0x60b9262456de011f7d15a54cdd8c48baaa8b022f";

// BNB Smart Chain mainnet.
export const CHAIN_ID = 56;
export const CHAIN_ID_HEX = "0x38";
export const CHAIN_NAME = "BNB Smart Chain";

// Parameters used when prompting the wallet to add BSC (error 4902).
export const BSC_CHAIN_PARAMS = {
  chainId: CHAIN_ID_HEX,
  chainName: CHAIN_NAME,
  nativeCurrency: { name: "BNB", symbol: "BNB", decimals: 18 },
  rpcUrls: ["https://bsc-dataseed.bnbchain.org"],
  blockExplorerUrls: ["https://bscscan.com"],
};

// Public read-only BSC RPC endpoints, tried in order until one answers.
// All reads go through these (never through the user's wallet provider),
// so the sale status loads even before a wallet is connected.
export const RPC_URLS = [
  "https://bsc-dataseed.bnbchain.org",
  "https://bsc-dataseed1.bnbchain.org",
  "https://bsc-dataseed2.bnbchain.org",
  "https://bsc-dataseed3.bnbchain.org",
  "https://bsc-dataseed4.bnbchain.org",
  "https://bsc.publicnode.com",
  "https://bsc.meowrpc.com",
];

export const BSCSCAN_BASE = "https://bscscan.com";
export const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

// Sale timing (unix seconds). saleStart is immutable in the contract;
// the deadline (saleStart + 30 days) and refund deadline (+ 14 more days)
// are read live from the contract, but these constants document the plan.
export const SALE_START = 1796058000; // 1 Dec 2026 00:00 WIB (30 Nov 17:00 UTC)
export const SALE_START_LABEL = "1 December 2026, 00:00 WIB";

// Curve constants — immutable in KongSale.sol, mirrored here so the page
// can compute quotes and tier boundaries without extra RPC calls.
// (The USDT total always comes from the contract's quote() view.)
export const MAX_SHARES = 10_000;
export const MAX_PER_WALLET = 10;

// Tier metadata. priceUsdt / tokensPerShare / referralPerShare are DISPLAY
// values in whole USDT / KONG (not raw units). Ranges and artwork match
// KongSale.sol exactly, and the prices match the deployed v3 contract
// (TIER1_PRICE = 1e18 = 1 USDT at 18 decimals, verified on-chain).
export const TIERS = [
  {
    tier: 1,
    name: "Tier 1 — Gold",
    range: "Shares 1–2,500",
    firstShare: 1,
    lastShare: 2500,
    priceUsdt: "1",
    tokensPerShare: 60_000,
    referralPerShare: 1_800,
    image: "https://zainumq.github.io/kong/kong-pass-tier1.jpg",
    color: "#d4af37",
  },
  {
    tier: 2,
    name: "Tier 2 — Silver",
    range: "Shares 2,501–6,000",
    firstShare: 2501,
    lastShare: 6000,
    priceUsdt: "1.5",
    tokensPerShare: 50_000,
    referralPerShare: 1_500,
    image: "https://zainumq.github.io/kong/kong-pass-tier2.jpg",
    color: "#9fb3c8",
  },
  {
    tier: 3,
    name: "Tier 3 — Bronze",
    range: "Shares 6,001–10,000",
    firstShare: 6001,
    lastShare: 10_000,
    priceUsdt: "2",
    tokensPerShare: 40_000,
    referralPerShare: 1_200,
    image: "https://zainumq.github.io/kong/kong-pass-tier3.jpg",
    color: "#cd7f32",
  },
];

// Minimal KongSale ABI — only the functions this frontend uses.
// Signatures verified against src/KongSale.sol (v3, with referral).
// Custom errors are included so ethers v6 can decode revert reasons.
export const KONG_SALE_ABI = [
  // Writes
  "function mintPass(uint256 amount, address referrer)",
  "function graduate()",
  "function claim(uint256 tokenId)",
  "function claimMany(uint256[] tokenIds)",
  "function claimReferral()",
  "function refund(uint256 tokenId)",
  "function refundMany(uint256[] tokenIds)",
  // Sale state views
  "function sharesSold() view returns (uint256)",
  "function totalRaised() view returns (uint256)",
  "function graduated() view returns (bool)",
  "function saleStart() view returns (uint256)",
  "function saleDeadline() view returns (uint256)",
  "function refundDeadline() view returns (uint256)",
  "function saleActive() view returns (bool)",
  "function refundActive() view returns (bool)",
  "function mintedByWallet(address wallet) view returns (uint256)",
  "function paidFor(uint256 tokenId) view returns (uint256)",
  "function referralEarned(address referrer) view returns (uint256)",
  "function referralClaimable(address referrer) view returns (uint256)",
  "function quote(uint256 amount) view returns (uint256)",
  "function priceOfShare(uint256 shareNumber) view returns (uint256)",
  "function tierOfShare(uint256 shareNumber) view returns (uint8)",
  // Wiring views (sanity checks + footer)
  "function pass() view returns (address)",
  "function kong() view returns (address)",
  "function usdt() view returns (address)",
  "function agentId() view returns (address)",
  "function MAX_SHARES() view returns (uint256)",
  "function MAX_PER_WALLET() view returns (uint256)",
  // Events (used to learn the tokenIds of freshly minted passes)
  "event PassMinted(address indexed buyer, uint256 indexed tokenId, uint8 tier, uint256 price)",
  // Custom errors (for human-readable revert messages)
  "error SaleNotStarted()",
  "error SaleEnded()",
  "error SaleSoldOut()",
  "error NotSoldOut()",
  "error InvalidAmount()",
  "error NoAgentId()",
  "error ExceedsWalletCap()",
  "error NotGraduated()",
  "error AlreadyGraduated()",
  "error RefundNotActive()",
  "error RefundWindowClosed()",
  "error AlreadySwept()",
  "error NotPassOwner()",
  "error Underfunded()",
  "error SelfReferral()",
  "error NothingToClaim()",
];

// Minimal KongMintPass ABI — only the functions this frontend uses.
// Signatures verified against src/KongMintPass.sol.
// NOTE: the pass contract has NO totalSupply() and NO enumeration
// (no tokenOfOwnerByIndex). Shares sold comes from KongSale.sharesSold(),
// and a wallet's passes are found via an ownerOf() scan (see app.js).
export const KONG_PASS_ABI = [
  "function balanceOf(address owner) view returns (uint256)",
  "function ownerOf(uint256 tokenId) view returns (address)",
  "function tierOf(uint256 tokenId) view returns (uint8)",
  "function claimableOf(uint256 tokenId) view returns (uint256)",
  "function nextTokenId() view returns (uint256)",
  "function name() view returns (string)",
  "function symbol() view returns (string)",
  "event Transfer(address indexed from, address indexed to, uint256 indexed tokenId)",
];

// Minimal ERC-20 ABI for USDT (allowance / approve flow) and KONG
// (balance display). BSC USDT (0x55d398…) has **18 decimals** (verified
// on-chain 19 Nov 2026 — NOT 6, despite the v2 contract's NatSpec);
// KONG has 18. The app reads decimals() live and falls back to 18.
export const ERC20_ABI = [
  "function balanceOf(address owner) view returns (uint256)",
  "function allowance(address owner, address spender) view returns (uint256)",
  "function approve(address spender, uint256 amount) returns (bool)",
  "function decimals() view returns (uint8)",
  "function symbol() view returns (string)",
];

// The Agent ID registry only ever needs balanceOf.
export const AGENT_ID_ABI = [
  "function balanceOf(address owner) view returns (uint256)",
];

// The pass contract has no token enumeration, so the frontend finds a
// wallet's passes by scanning ownerOf(1..sharesSold). The scan stops as
// soon as it has found as many passes as balanceOf() reports, and it
// never scans past this cap; passes minted by this page are also cached
// in localStorage, so the scan is mainly a fallback for passes bought
// on secondary markets or minted elsewhere.
export const PASS_SCAN_CAP = 3000;

// How often the sale status panel refreshes from the chain (ms).
export const SALE_POLL_MS = 30_000;
