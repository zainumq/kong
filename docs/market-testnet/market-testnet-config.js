// KongMarket TESTNET frontend configuration — self-contained.
//
// Halaman /market-testnet adalah salinan halaman /market yang diarahkan ke
// BSC Testnet (chain 97). TIDAK mengimpor ../config.js (config halaman mint
// mainnet) — semua konstanta yang dipakai market-testnet.js ada di file ini,
// supaya satu file ini cukup untuk mengubah seluruh wiring testnet.
//
// =============================================================================
// STATUS: SEMUA KONTRAK TESTNET SUDAH LIVE (19-20 Nov 2026)
// =============================================================================
//   KongMarket (testnet)  0x60Ef77Fc2961bc3BE20198aE2Fd90751F6a1530b
//   Mock KongMintPass     0xfB10858719919f0eA3149F2c25CBe52086dF9984
//   MockUSDT (mint publik) 0x41de1C38502d5Ae2672470620Ac183Db566dde8A
//   KongTestPassDispenser 0xE09243FA8374b2b40bfC448d4b8F67C777ca7223
//                         (stok tokenId 3-32; klaim 1/wallet)
//   Ketiganya + dispenser: Sourcify exact_match di chain 97.
//   Detail deploy: kong/testnet-deploy-20261119.md §5-6.
//
//   SEMUA TOKEN DI TESTNET TIDAK BERNILAI. Tidak ada sale, graduation,
//   klaim KONG, atau refund di testnet — halaman ini murni demo supaya
//   siapa pun bisa mencoba alur marketplace (list / beli / ubah / batal)
//   tanpa uang sungguhan.

// --- Kontrak testnet (BSC Testnet, chain 97) ---
export const MARKET_ADDRESS = "0x60Ef77Fc2961bc3BE20198aE2Fd90751F6a1530b";
export const KONG_PASS_ADDRESS = "0xfB10858719919f0eA3149F2c25CBe52086dF9984";
export const USDT_ADDRESS = "0x41de1C38502d5Ae2672470620Ac183Db566dde8A";
export const DISPENSER_ADDRESS = "0xE09243FA8374b2b40bfC448d4b8F67C777ca7223";

// Blok deploy KongMarket testnet (tx 0xd49c7f2b…, 19 Nov 2026) — untuk
// query event; tanpa ini fallback eth_getLogs RPC tidak bisa jalan.
export const MARKET_DEPLOY_BLOCK = 143607264;

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

// Floor harga per tier — SAMA dengan mainnet (terverifikasi on-chain
// testnet 19 Nov 2026: floorOf(1, USDT) = 1e18, floorOf(3, BNB) =
// 0,00339 BNB). Nilai dalam desimal manusia; parseUnits(value, 18).
export const TIER_FLOORS = {
  1: { usdt: "1", bnb: "0.0017" },
  2: { usdt: "1.5", bnb: "0.00254" },
  3: { usdt: "2", bnb: "0.00339" },
};

// Angka acuan tBNB dalam USD — HANYA dipakai sebagai proksi pengurutan
// listing campuran USDT/BNB (priceToUsd). BUKAN harga riil dan tidak
// pernah ditampilkan sebagai nilai uang di halaman testnet.
export const SORT_BNB_USD = 589.89;

// Scan ownerOf untuk "Pass saya": tokenId 1..cap. Stok dispenser saat
// ini 30 pass (#3-32); cap 500 memberi ruang untuk dispenser berikutnya
// tanpa membuat scan berat (scan berhenti begitu semua pass ketemu).
export const TESTNET_PASS_SCAN_CAP = 500;

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

// ABI KongMarket — salinan persis dari market-config.js mainnet
// (terverifikasi terhadap src/KongMarket.sol; kontrak testnet adalah
// bytecode yang sama).
export const KONG_MARKET_ABI = [
  "function list(uint256 tokenId, uint256 price, address paymentToken)",
  "function updatePrice(uint256 tokenId, uint256 newPrice)",
  "function cancel(uint256 tokenId)",
  "function buy(uint256 tokenId, uint256 maxPrice) payable",
  "function sweepFees(address token)",
  "function listingOf(uint256 tokenId) view returns (address seller, uint256 price, address paymentToken)",
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
