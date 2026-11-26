// KongMarket TESTNET frontend configuration — self-contained.
//
// Halaman /market-testnet adalah salinan halaman /market yang diarahkan ke
// BSC Testnet (chain 97). TIDAK mengimpor ../config.js (config halaman mint
// mainnet) — semua konstanta yang dipakai market-testnet.js ada di file ini,
// supaya satu file ini cukup untuk mengubah seluruh wiring testnet.
//
// =============================================================================
// STATUS: MARKET TESTNET v2 — FEE DISTRIBUTOR TER-WIRE (26 Nov 2026)
// =============================================================================
//   KongMarketOracle (testnet) 0xad8bd4be04983b99020a17e9be31f4e700ff9650
//                         (floor BNB dinamis via Chainlink BNB/USD; deploy 26 Nov 2026,
//                          blok 144829604, tx 0x6a9073e3…; treasury = FeeDistributor
//                          0x418FF609b23Fe3086db9A851E4D3f4521cE193F8, ter-wire
//                          setMarket + setMarketPass 26 Nov ~08:02 WIB)
//   KongMarketPass (testnet) 0x78654735c0035f3b8d37c96e5232e9646e5fc8ed
//                         (deploy 26 Nov 2026, blok 144828628; distributor =
//                          FeeDistributor di atas; DUPLIKAT 0xdd83ba1e… JANGAN dipakai)
//   Oracle LAMA 0x0c537BC6b9b9FD26e6B76683D05FD43C32f33ec2 (deploy 22 Nov 2026)
//                         PENSIUN — treasury-nya deployer testnet (bukan
//                         FeeDistributor), tidak bisa di-wire; halaman ini
//                         sekarang mengarah ke market baru di atas.
//   KongMarket v1 (testnet) 0x60Ef77Fc2961bc3BE20198aE2Fd90751F6a1530b
//                         (DIGANTI Oracle 22 Nov 2026 — kontrak lama tetap live dan
//                         masih memegang listing Pass #5 user @ 40 test USDT)
//   Mock KongMintPass     0xfB10858719919f0eA3149F2c25CBe52086dF9984
//   MockUSDT (mint publik) 0x41de1C38502d5Ae2672470620Ac183Db566dde8A
//   KongTestPassDispenser #2 0xE40421FD8f1b1Bce85c02F3b3FEaF915dffE029A
//                         (stok 1.000 pass, tokenId 33-1032; klaim 1/wallet)
//   Dispenser #1 (0xE09243FA8374b2b40bfC448d4b8F67C777ca7223, stok 30,
//   tokenId 3-32) PENSIUN 20 Nov 2026 — 27 pass-nya tidak terpakai.
//   Ketiganya + dispenser: Sourcify exact_match di chain 97.
//   Detail deploy: kong/testnet-deploy-20261119.md §5-7.
//
//   SEMUA TOKEN DI TESTNET TIDAK BERNILAI. Tidak ada sale, graduation,
//   klaim KONG, atau refund di testnet — halaman ini murni demo supaya
//   siapa pun bisa mencoba alur marketplace (list / beli / ubah / batal)
//   tanpa uang sungguhan.

// --- Kontrak testnet (BSC Testnet, chain 97) ---
export const MARKET_ADDRESS = "0xad8bd4be04983b99020a17e9be31f4e700ff9650";
export const KONG_PASS_ADDRESS = "0xfB10858719919f0eA3149F2c25CBe52086dF9984";
export const USDT_ADDRESS = "0x41de1C38502d5Ae2672470620Ac183Db566dde8A";
export const DISPENSER_ADDRESS = "0xE40421FD8f1b1Bce85c02F3b3FEaF915dffE029A";

// Blok deploy KongMarketOracle testnet BARU (tx 0x6a9073e3…, 26 Nov 2026) —
// untuk query event; tanpa ini fallback eth_getLogs RPC tidak bisa jalan.
export const MARKET_DEPLOY_BLOCK = 144829604;

// Faucet tBNB resmi (butuh saldo mainnet ≥0,002 BNB di alamat yang sama +
// hCaptcha — lihat halaman). Alternatif: faucet QuickNode (syarat sama).
export const FAUCET_URL = "https://www.bnbchain.org/en/testnet-faucet";

// BSC Testnet (chain 97).
export const CHAIN_ID = 97;
export const CHAIN_ID_HEX = "0x61";
export const CHAIN_NAME = "BNB Smart Chain Testnet";

export const BSC_CHAIN_PARAMS = {
  chainId: CHAIN_ID_HEX,
  chainName: CHAIN_NAME,
  nativeCurrency: { name: "tBNB", symbol: "tBNB", decimals: 18 },
  rpcUrls: ["https://bsc-testnet-rpc.publicnode.com"],
  blockExplorerUrls: ["https://testnet.bscscan.com"],
};

// RPC testnet publik, dicoba berurutan. publicnode duluan — dataseed
// bnbchain.org sempat 403 saat deploy 19 Nov 2026 (lihat AGENTS.md).
export const RPC_URLS = [
  "https://bsc-testnet-rpc.publicnode.com",
  "https://bsc-testnet-dataseed.bnbchain.org",
  "https://data-seed-prebsc-1-s1.bnbchain.org:8545",
  "https://data-seed-prebsc-2-s1.bnbchain.org:8545",
  "https://bsc-testnet.meowrpc.com",
];

export const BSCSCAN_BASE = "https://testnet.bscscan.com";
export const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

// Etherscan V2 API — TIDAK DIPAKAI halaman testnet: paket gratis tidak
// mendukung chain 97 ("Free API access is not supported for this chain",
// terverifikasi 20 Nov 2026), dan fallback eth_getLogs tidak praktis
// karena testnet memproduksi ~2,2 blok/detik. Listing dibaca langsung
// dari state kontrak via listingOf() (lihat loadListings di
// market-testnet.js). Konstanta dipertahankan untuk dokumentasi.
export const BSCSCAN_API_V2 = "https://api.etherscan.io/v2/api";
export const BSCSCAN_API_KEY = "";

// Fee marketplace: 100 bps = 1% (immutable di kontrak). Hanya untuk
// estimasi pembagian di UI; pembagian sebenarnya ditegakkan kontrak.
export const MARKET_FEE_BPS = 100;

// Floor harga per tier. USDT tetap (sama dengan mainnet, immutable di
// kontrak). BNB DINAMIS: dibaca live dari floorOf() kontrak oracle
// (Chainlink BNB/USD) — nilai bnb di bawah ini hanya FALLBACK bila
// pembacaan live gagal (nilai per 22 Nov 2026, BNB ~$547,59).
// Nilai dalam desimal manusia; parseUnits(value, 18).
export const TIER_FLOORS = {
  1: { usdt: "1", bnb: "0.001826" },
  2: { usdt: "1.5", bnb: "0.002739" },
  3: { usdt: "2", bnb: "0.003652" },
};

// Angka acuan tBNB dalam USD — HANYA dipakai sebagai proksi pengurutan
// listing campuran USDT/BNB (priceToUsd). BUKAN harga riil dan tidak
// pernah ditampilkan sebagai nilai uang di halaman testnet.
export const SORT_BNB_USD = 547.59; // perkiraan 22 Nov 2026

// Scan ownerOf untuk "Pass saya": tokenId 1..cap. Stok dispenser #2
// 1.000 pass (#33-1032); cap 1200 memberi ruang untuk dispenser
// berikutnya tanpa membuat scan berat (scan berhenti begitu semua pass
// ketemu).
export const TESTNET_PASS_SCAN_CAP = 1200;

// Tier metadata — sama dengan halaman mint mainnet (mock pass memakai
// konstanta tier yang sama; artwork dari hosting yang sama).
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

// ABI KongMarketOracle (terverifikasi terhadap
// src/KongMarketOracle.sol; floorOf + StalePrice adalah tambahan oracle
// yang tidak ada di KongMarket v1).
export const KONG_MARKET_ABI = [
  "function list(uint256 tokenId, uint256 price, address paymentToken)",
  "function updatePrice(uint256 tokenId, uint256 newPrice)",
  "function cancel(uint256 tokenId)",
  "function buy(uint256 tokenId, uint256 maxPrice) payable",
  "function sweepFees(address token)",
  "function listingOf(uint256 tokenId) view returns (address seller, uint256 price, address paymentToken)",
  "function floorOf(uint8 tier, address paymentToken) view returns (uint256)",
  "event Listed(address indexed seller, uint256 indexed tokenId, uint256 price, address paymentToken)",
  "event PriceUpdated(uint256 indexed tokenId, uint256 newPrice)",
  "event Cancelled(uint256 indexed tokenId)",
  "event Sold(address indexed seller, address indexed buyer, uint256 indexed tokenId, uint256 price, address paymentToken)",
  "event FeesSwept(address indexed token, uint256 amount)",
  "error InvalidTier()",
  "error InvalidPaymentToken()",
  "error InvalidPrice()",
  "error InvalidFloor()",
  "error BelowFloor()",
  "error StalePrice()",
  "error NotPassOwner()",
  "error NotSeller()",
  "error NoListing()",
  "error SelfPurchase()",
  "error OwnershipChanged()",
  "error NotApproved()",
  "error IncorrectValue()",
  "error ValueNotAllowed()",
  "error PriceAboveMax()",
  "error InvalidRoyalty()",
  "error NotTreasury()",
  "error NothingToSweep()",
  "error TransferFailed()",
];

// ABI KongMintPass yang dibutuhkan halaman market (sama dengan mainnet).
export const MARKET_PASS_ABI = [
  "function balanceOf(address owner) view returns (uint256)",
  "function ownerOf(uint256 tokenId) view returns (address)",
  "function tierOf(uint256 tokenId) view returns (uint8)",
  "function claimableOf(uint256 tokenId) view returns (uint256)",
  "function getApproved(uint256 tokenId) view returns (address)",
  "function isApprovedForAll(address owner, address operator) view returns (bool)",
  "function approve(address to, uint256 tokenId)",
  "function royaltyInfo(uint256 tokenId, uint256 salePrice) view returns (address receiver, uint256 royaltyAmount)",
  "function nextTokenId() view returns (uint256)",
  "event Transfer(address indexed from, address indexed to, uint256 indexed tokenId)",
];

// ABI ERC20 minimal (baca saldo/allowance/approve/decimals).
export const ERC20_ABI = [
  "function balanceOf(address owner) view returns (uint256)",
  "function allowance(address owner, address spender) view returns (uint256)",
  "function approve(address spender, uint256 amount) returns (bool)",
  "function decimals() view returns (uint8)",
  "function symbol() view returns (string)",
];

// ABI MockUSDT — ERC20 di atas + mint publik (siapa pun boleh mint
// test USDT ke alamat sendiri; 18 desimal seperti USDT BSC asli).
export const MOCK_USDT_ABI = [
  ...ERC20_ABI,
  "function mint(address to, uint256 amount)",
];

// ABI KongTestPassDispenser (src/KongTestPassDispenser.sol).
export const DISPENSER_ABI = [
  "function claim() returns (uint256 tokenId)",
  "function remaining() view returns (uint256)",
  "function nextId() view returns (uint256)",
  "function claimed(address) view returns (bool)",
  "function firstId() view returns (uint256)",
  "function lastId() view returns (uint256)",
  "event Claimed(address indexed claimer, uint256 indexed tokenId)",
  "error AlreadyClaimed()",
  "error OutOfStock()",
];
