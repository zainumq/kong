// KongMarket frontend configuration.
//
// =============================================================================
// STATUS: KONTRAK MARKET BELUM DI-DEPLOY KE MAINNET.
// =============================================================================
// Deploy mainnet ditahan sampai setelah pass pertama ada (sale dibuka
// 1 Desember 2026). Sampai saat itu MARKET_ADDRESS adalah zero address dan
// MARKET_DEPLOY_BLOCK null — halaman menampilkan pesan "Marketplace belum
// dibuka" dengan rapi, bukan error mentah.
//
// YANG HARUS DIISI SAAT DEPLOY MAINNET (hanya file ini yang perlu diubah):
//   1. MARKET_ADDRESS  -> alamat kontrak KongMarket yang ter-deploy.
//   2. MARKET_DEPLOY_BLOCK -> nomor blok saat kontrak di-deploy (mempercepat
//      query event; bila kosong, query BscScan dimulai dari blok 0 dan
//      fallback RPC eth_getLogs TIDAK bisa jalan sama sekali).
//   3. Floor BNB di TIER_FLOORS (bila harga BNB saat deploy membuat angka
//      perkiraan di bawah ini tidak lagi cocok dengan floor kontrak —
//      floor BNB final ditetapkan di constructor kontrak saat deploy).
//   4. (Opsional) BSCSCAN_API_KEY — tanpa key, API Etherscan V2 tetap
//      dicoba, tapi bisa ditolak/rate-limit; halaman lalu jatuh ke
//      fallback eth_getLogs RPC.
//
// =============================================================================
// ABI / EVENT — TERVERIFIKASI TERHADAP KONTRAK FINAL (19 Nov 2026)
// =============================================================================
// ABI di bawah ini dicocokkan persis dengan src/KongMarket.sol final
// (pasca-perbaikan audit M-1). Urutan argumen event PENTING: topic hash
// dihitung dari signature lengkap, jadi urutan yang salah membuat query
// event tidak menemukan apa pun. Bila kontrak berubah lagi, yang perlu
// diubah HANYALAH konstanta KONG_MARKET_ABI di file ini — market.js
// tidak hardcode signature apa pun (topic hash event dihitung dari ABI
// via ethers.Interface).
//
// Fungsi (dari src/KongMarket.sol):
//   list(uint256 tokenId, uint256 price, address paymentToken)
//   updatePrice(uint256 tokenId, uint256 newPrice)
//   cancel(uint256 tokenId)
//   buy(uint256 tokenId, uint256 maxPrice) payable
//     -- maxPrice adalah proteksi front-run harga (temuan audit M-1):
//        pembelian revert PriceAboveMax() bila harga listing sudah naik
//        di atas maxPrice saat transaksi diproses. Frontend selalu
//        mengirim maxPrice = harga listing yang ditampilkan/dverifikasi
//        live. Untuk listing BNB, msg.value tetap tepat == harga.
//   sweepFees(address token)
//   listingOf(uint256 tokenId) view returns (address seller, uint256 price,
//                                           address paymentToken)
//   paymentToken = alamat USDT untuk listing USDT, address(0) untuk BNB.
//
// Bentuk event (dari src/KongMarket.sol — perhatikan URUTAN argumennya):
//   Listed(address indexed seller, uint256 indexed tokenId,
//          uint256 price, address paymentToken)
//   PriceUpdated(uint256 indexed tokenId, uint256 newPrice)
//   Cancelled(uint256 indexed tokenId)
//   Sold(address indexed seller, address indexed buyer,
//        uint256 indexed tokenId, uint256 price, address paymentToken)
//   FeesSwept(address indexed token, uint256 amount)
//
// Custom error di ABI juga ASUMSI nama-namanya (dipakai hanya untuk
// menerjemahkan revert menjadi pesan Indonesia; nama yang salah tidak
// merusak apa pun, pesannya saja jadi generik).

// Alamat kontrak KongMarket di BSC mainnet (chain 56).
// BELUM DI-DEPLOY — jangan isi alamat palsu. Isi setelah deploy mainnet.
export const MARKET_ADDRESS = "0x0000000000000000000000000000000000000000";

// Blok saat kontrak KongMarket di-deploy (untuk query event).
// BELUM ADA — isi setelah deploy mainnet. Bila null, query BscScan dimulai
// dari blok 0 (lambat) dan fallback eth_getLogs RPC tidak bisa dipakai.
export const MARKET_DEPLOY_BLOCK = null;

// Etherscan V2 API (BscScan lama api.bscscan.com/api kini 301 ke endpoint
// ini). API key OPSIONAL: tanpa key tetap dicoba, tapi Etherscan bisa
// menolak (Missing/Invalid API Key) atau membatasi rate — halaman lalu
// jatuh ke fallback eth_getLogs RPC. Key gratis: https://etherscan.io/apis
// (satu key berlaku untuk semua chain yang didukung V2, termasuk BSC 56).
export const BSCSCAN_API_V2 = "https://api.etherscan.io/v2/api";
export const BSCSCAN_API_KEY = "";

// Fee marketplace: 100 bps = 1% (immutable di kontrak, spek §4).
// Dipakai hanya untuk ESTIMASI pembagian di UI; pembagian sebenarnya
// ditegakkan kontrak. Royalti 5% TIDAK di-hardcode — dibaca live dari
// pass.royaltyInfo(tokenId, price) (ERC-2981) setiap kali membeli.
export const MARKET_FEE_BPS = 100;

// Floor harga per tier (spek §4a) — harga listing tidak boleh di bawah ini.
// Floor USDT = harga mint per tier (pasti). Floor BNB = PERKIRAAN memakai
// harga BNB ~$589,89 (19 Nov 2026); angka final ditetapkan saat deploy
// berdasarkan harga BNB saat itu dan immutable di kontrak. Nilai di sini
// dalam desimal manusia (bukan raw); USDT dan BNB sama-sama 18 desimal
// di BSC, jadi parseUnits(value, 18) berlaku untuk keduanya.
export const TIER_FLOORS = {
  1: { usdt: "1", bnb: "0.0017" },
  2: { usdt: "1.5", bnb: "0.00254" },
  3: { usdt: "2", bnb: "0.00339" },
};

// ---------------------------------------------------------------------------
// Kurs IDR — pendekatan & dokumentasi
// ---------------------------------------------------------------------------
// Halaman mint TIDAK menampilkan IDR sama sekali (hanya USDT/KONG), jadi
// tidak ada pola kurs yang bisa diikuti dari sana. Halaman market memakai:
//   1. Kurs LIVE dari CoinGecko (endpoint publik, tanpa API key):
//      simple/price untuk tether + binancecoin dalam IDR dan USD.
//   2. Bila CoinGecko tidak terjangkau, pakai kurs ACUAN TETAP di bawah
//      ini (19 Nov 2026, sama dengan kurs acuan spek §4) dan halaman
//      menampilkan catatan bahwa kursnya adalah kurs acuan, bukan live.
// BNB_IDR acuan = $589,89 x Rp18.265,5 = ~Rp10.774.636.
export const COINGECKO_URL =
  "https://api.coingecko.com/api/v3/simple/price?ids=tether,binancecoin&vs_currencies=idr,usd";
export const USDT_IDR_FALLBACK = 18265.5;
export const BNB_IDR_FALLBACK = 10774636;
export const BNB_USD_FALLBACK = 589.89;

// ABI kontrak KongMarket — lihat catatan asumsi di atas.
export const KONG_MARKET_ABI = [
  // Writes
  "function list(uint256 tokenId, uint256 price, address paymentToken)",
  "function updatePrice(uint256 tokenId, uint256 newPrice)",
  "function cancel(uint256 tokenId)",
  "function buy(uint256 tokenId, uint256 maxPrice) payable",
  "function sweepFees(address token)",
  // View
  "function listingOf(uint256 tokenId) view returns (address seller, uint256 price, address paymentToken)",
  // Events (terverifikasi terhadap src/KongMarket.sol — urutan argumen persis)
  "event Listed(address indexed seller, uint256 indexed tokenId, uint256 price, address paymentToken)",
  "event PriceUpdated(uint256 indexed tokenId, uint256 newPrice)",
  "event Cancelled(uint256 indexed tokenId)",
  "event Sold(address indexed seller, address indexed buyer, uint256 indexed tokenId, uint256 price, address paymentToken)",
  "event FeesSwept(address indexed token, uint256 amount)",
  // Custom errors (persis seperti di src/KongMarket.sol)
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

// ABI KongMintPass yang dibutuhkan halaman market: seperti di config.js
// halaman mint, ditambah getApproved / isApprovedForAll / approve /
// royaltyInfo (ERC-2981) yang tidak dipakai halaman mint. Tanda tangan
// diverifikasi terhadap src/KongMintPass.sol (ERC721 standar + ERC-2981).
export const MARKET_PASS_ABI = [
  "function balanceOf(address owner) view returns (uint256)",
  "function ownerOf(uint256 tokenId) view returns (address)",
  "function tierOf(uint256 tokenId) view returns (uint8)",
  "function claimableOf(uint256 tokenId) view returns (uint256)",
  "function getApproved(uint256 tokenId) view returns (address)",
  "function isApprovedForAll(address owner, address operator) view returns (bool)",
  "function approve(address to, uint256 tokenId)",
  "function royaltyInfo(uint256 tokenId, uint256 salePrice) view returns (address receiver, uint256 royaltyAmount)",
  "event Transfer(address indexed from, address indexed to, uint256 indexed tokenId)",
];
