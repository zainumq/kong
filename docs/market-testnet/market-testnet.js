// Marketplace $KONG — TESTNET DEMO (halaman /market-testnet).
//
// Salinan halaman /market mainnet yang diarahkan ke BSC Testnet (chain 97).
// Semua kontrak di sini adalah kontrak TESTNET (KongMarket + mock pass +
// MockUSDT + dispenser test pass) — token test TIDAK BERNILAI. Tidak ada
// sale, graduation, klaim KONG, atau refund di testnet.
//
// Logika inti (list/beli/ubah/batal, verifikasi live listing, proteksi
// maxPrice) SAMA PERSIS dengan halaman mainnet — hanya wiring-nya yang
// berbeda: impor dari ./market-testnet-config.js, chain 97, tanpa panel
// sale (diganti panel token test), tanpa nilai rupiah di mana pun.
//
// Bahasa antarmuka: id/en/zh (lihat ./i18n.js) — pemilih bahasa di header,
// preferensi tersimpan di localStorage. Semua string UI lewat t("kunci");
// nama tier ("Tier 1 — Gold") sengaja tidak diterjemahkan.

import { ethers } from "https://cdn.jsdelivr.net/npm/ethers@6.13.5/+esm";
import {
  KONG_PASS_ADDRESS,
  USDT_ADDRESS,
  CHAIN_ID,
  CHAIN_ID_HEX,
  BSC_CHAIN_PARAMS,
  RPC_URLS,
  BSCSCAN_BASE,
  ZERO_ADDRESS,
  TIERS,
  ERC20_ABI,
  MARKET_ADDRESS,
  MARKET_DEPLOY_BLOCK,
  KONG_MARKET_ABI,
  MARKET_PASS_ABI,
  TIER_FLOORS,
  MARKET_FEE_BPS,
  DISPENSER_ADDRESS,
  DISPENSER_ABI,
  MOCK_USDT_ABI,
  FAUCET_URL,
  SORT_BNB_USD,
  TESTNET_PASS_SCAN_CAP,
} from "./market-testnet-config.js";
import { t, setLang, initLang, applyStaticI18n, numLocale } from "./i18n.js";

const $ = (id) => document.getElementById(id);
const shortAddress = (a) => `${a.slice(0, 6)}…${a.slice(-4)}`;
const bscscanTx = (hash) => `${BSCSCAN_BASE}/tx/${hash}`;
const bscscanAddress = (addr) => `${BSCSCAN_BASE}/address/${addr}`;
const bscscanToken = (tokenId) =>
  `${BSCSCAN_BASE}/token/${KONG_PASS_ADDRESS}?a=${tokenId}`;

// Market dianggap ter-deploy hanya bila MARKET_ADDRESS sudah diisi dengan
// alamat nyata (bukan zero address). Semua pemanggilan kontrak market
// dijaga oleh flag ini.
const MARKET_DEPLOYED =
  !!MARKET_ADDRESS && MARKET_ADDRESS.toLowerCase() !== ZERO_ADDRESS;

const isUsdt = (paymentToken) =>
  paymentToken && paymentToken.toLowerCase() === USDT_ADDRESS.toLowerCase();
const isBnb = (paymentToken) =>
  paymentToken && paymentToken.toLowerCase() === ZERO_ADDRESS;
const isKnownCurrency = (paymentToken) =>
  isUsdt(paymentToken) || isBnb(paymentToken);

// ---------------------------------------------------------------------------
// Format angka mengikuti bahasa aktif (id-ID: koma desimal;
// en-US/zh-CN: titik desimal).
// ---------------------------------------------------------------------------

const fmtInt = (n) => Number(n).toLocaleString(numLocale());
const fmtKong = (value) =>
  `${Number(ethers.formatUnits(value, 18)).toLocaleString(numLocale())} KONG`;
const fmtUsdt = (value, decimals = 18) =>
  `${Number(ethers.formatUnits(value, decimals)).toLocaleString(numLocale(), {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })} USDT`;
const fmtBnb = (value) =>
  `${Number(ethers.formatUnits(value, 18)).toLocaleString(numLocale(), {
    maximumFractionDigits: 6,
  })} BNB`;
const fmtPrice = (price, paymentToken) =>
  isUsdt(paymentToken) ? fmtUsdt(price) : fmtBnb(price);
// TIDAK ADA fmtIdr di halaman testnet — token test tanpa nilai rupiah.

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

let walletProvider = null;
let signer = null;
let account = null;
let walletChainId = null;
let busy = false; // sebuah transaksi sedang berjalan
// MockUSDT testnet 18 desimal (sama seperti USDT BSC asli).
// Dibaca live di refreshTestnetPanel; 18 adalah fallback yang benar.
let usdtDecimals = 18;

// Nilai tukar ke USD — HANYA untuk mengurutkan listing campuran USDT/BNB
// berdasarkan nilai yang sama. Di testnet tidak ada harga riil: test USDT
// dihitung 1 dan tBNB memakai angka acuan tetap SORT_BNB_USD dari config.
// Angka ini tidak pernah ditampilkan sebagai nilai uang.
const priceToUsd = (price, paymentToken) => {
  const amount = Number(ethers.formatUnits(price, 18));
  return isUsdt(paymentToken) ? amount : amount * SORT_BNB_USD;
};

// Status wallet yang terhubung.
const wallet = {
  passBalance: null,
  usdtBalance: null,
  bnbBalance: null,
  passes: [], // [{ tokenId, tier, claimable, listed, listingPrice,
  //            listingCurrency, approved }]
};

// Listing dari event (Map tokenId -> { tokenId, seller, price,
// paymentToken, blockNumber }), lalu hasil verifikasi live:
// verified = [{ ...listing, tier, claimable, status: "ok" | "unknown" }].
// Listing basi TIDAK masuk `verified` (disembunyikan, dihitung di staleCount).
let listings = new Map();
let verified = [];
let staleCount = 0;
let listingsLoading = true; // true sejak awal: render pertama harus
// menampilkan spinner, bukan status kosong "Belum ada listing." padahal
// pemuatan belum mulai (panel testnet dimuat dulu, ~25 detik).
let listingsError = null;
let listingsSource = null; // "bscscan" | "rpc" | null

const filters = { tier: 0, currency: "all", sort: "asc" };

// Listing yang sedang menunggu konfirmasi beli (+ rincian pembagian dana).
let pendingBuy = null;

// Draf input harga/mata uang di kartu "Pass saya", dipertahankan saat
// kartu di-render ulang (mis. setelah transaksi selesai).
const priceDrafts = new Map(); // key "list-<id>" / "update-<id>" -> string
const currencyDrafts = new Map(); // key "list-<id>" -> "USDT" | "BNB"

// Provider baca-only, dicoba berurutan sampai ada yang menjawab.
const readProviders = RPC_URLS.map(
  (url) => new ethers.JsonRpcProvider(url, CHAIN_ID)
);

function passContract(provider) {
  return new ethers.Contract(KONG_PASS_ADDRESS, MARKET_PASS_ABI, provider);
}
function usdtContract(provider) {
  return new ethers.Contract(USDT_ADDRESS, ERC20_ABI, provider);
}
function marketContract(providerOrSigner) {
  return new ethers.Contract(MARKET_ADDRESS, KONG_MARKET_ABI, providerOrSigner);
}

// Multicall3 (alamat kanonis yang sama di semua chain EVM, termasuk
// BSC testnet — terverifikasi on-chain 20 Nov 2026): menggabungkan
// puluhan listingOf menjadi SATU eth_call. Tanpa ini, loadListings
// memindai 1..nextTokenId satu per satu — 369 panggilan saat nextTokenId
// 369, dan 1.032 panggilan begitu stok dispenser #2 penuh — sehingga
// halaman tampak "loading" bermenit-menit (insiden 20 Nov 2026).
const MULTICALL3_ADDRESS = "0xcA11bde05977b3631167028862bE2a173976CA11";
const MULTICALL3_ABI = [
  "function aggregate3((address target, bool allowFailure, bytes callData)[] calls) returns ((bool success, bytes returnData)[] returnData)",
];
const LISTING_SCAN_BATCH = 50;
const marketIface = new ethers.Interface(KONG_MARKET_ABI);

function multicallContract(provider) {
  return new ethers.Contract(MULTICALL3_ADDRESS, MULTICALL3_ABI, provider);
}

/**
 * Baca listingOf(ids) lewat satu aggregate3. Mengembalikan array
 * {seller, price, paymentToken} | null per id, atau null bila batch
 * gagal total (pemanggil lalu memakai fallback per panggilan).
 */
async function readListingsMulticall(ids) {
  try {
    const calls = ids.map((id) => ({
      target: MARKET_ADDRESS,
      allowFailure: true,
      callData: marketIface.encodeFunctionData("listingOf", [id]),
    }));
    const results = await withReadProvider((p) =>
      multicallContract(p).aggregate3.staticCall(calls)
    );
    return results.map((r) => {
      if (!r.success) return null;
      try {
        const [seller, price, paymentToken] =
          marketIface.decodeFunctionResult("listingOf", r.returnData);
        return { seller, price, paymentToken };
      } catch {
        return null;
      }
    });
  } catch {
    return null;
  }
}

/** Jalankan `fn(provider)` ke provider baca berurutan; yang pertama sukses menang. */
// Satu percobaan baca dibatasi 20 detik: RPC testnet publik kadang
// menggantung tanpa merespons (tanpa timeout, fetch bisa menggantung
// bermenit-menit dan halaman tampak "terjebak" di status memuat —
// teramati 20 Nov 2026 saat RPC sibuk).
function withTimeout(promise, ms) {
  let timer = null;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error("read timeout")), ms);
  });
  return Promise.race([
    promise.then(
      (v) => {
        clearTimeout(timer);
        return v;
      },
      (e) => {
        clearTimeout(timer);
        throw e;
      }
    ),
    timeout,
  ]);
}

async function withReadProvider(fn) {
  let lastError = null;
  for (const provider of readProviders) {
    try {
      return await withTimeout(fn(provider), 20_000);
    } catch (err) {
      lastError = err;
    }
  }
  throw lastError ?? new Error(t("rpcAllFailed"));
}

// ---------------------------------------------------------------------------
// Helper UI (semua teks dinamis lewat textContent, tidak pernah innerHTML
// dengan data yang tidak tepercaya)
// ---------------------------------------------------------------------------

function showError(message) {
  const el = $("error-banner");
  el.textContent = message;
  el.hidden = false;
}

function clearError() {
  $("error-banner").hidden = true;
}

function setTxStatus(lines) {
  const box = $("tx-status");
  box.replaceChildren();
  for (const line of lines) {
    const p = document.createElement("p");
    for (const seg of line) {
      if (seg.href) {
        const a = document.createElement("a");
        a.href = seg.href;
        a.target = "_blank";
        a.rel = "noopener";
        a.textContent = seg.text;
        p.appendChild(a);
      } else {
        p.appendChild(document.createTextNode(seg.text));
      }
    }
    box.appendChild(p);
  }
  box.hidden = false;
}

function clearTxStatus() {
  $("tx-status").hidden = true;
  $("tx-status").replaceChildren();
}

function setPill(el, text, kind) {
  el.textContent = text;
  el.className = `pill pill-${kind}`;
}

function tierMeta(tier) {
  return TIERS[tier - 1];
}

function tierOfShare(shareNumber) {
  if (shareNumber <= TIERS[0].lastShare) return 1;
  if (shareNumber <= TIERS[1].lastShare) return 2;
  return 3;
}

/** Floor tier dalam raw unit (18 desimal) untuk mata uang tertentu. */
function floorRaw(tier, currency) {
  const floor = TIER_FLOORS[tier];
  return ethers.parseUnits(currency === "BNB" ? floor.bnb : floor.usdt, 18);
}

/** Harga impas: harga jual agar penjual terima bersih sebesar harga mint
 *  setelah potongan 6% (royalti 5% + fee 1%). = floor x 100 / 94. */
function breakevenRaw(tier, currency) {
  return (floorRaw(tier, currency) * 100n) / 94n;
}

// ---------------------------------------------------------------------------
// Koneksi wallet & jaringan (pola yang sama dengan halaman mint)
// ---------------------------------------------------------------------------

async function connectWallet() {
  if (!window.ethereum) {
    showError(
      t("walletNotFound")
    );
    return;
  }
  clearError();
  try {
    walletProvider = new ethers.BrowserProvider(window.ethereum);
    const accounts = await walletProvider.send("eth_requestAccounts", []);
    if (accounts.length === 0) return;
    account = ethers.getAddress(accounts[0]);
    signer = await walletProvider.getSigner();
    const network = await walletProvider.getNetwork();
    walletChainId = Number(network.chainId);
    updateWalletUI();
    await refreshWallet();
    await refreshTestnetPanel();
    renderListings();
  } catch (err) {
    showError(friendlyError(err));
  }
}

function disconnectWallet() {
  walletProvider = null;
  signer = null;
  account = null;
  walletChainId = null;
  Object.assign(wallet, {
    passBalance: null,
    usdtBalance: null,
    bnbBalance: null,
    passes: [],
  });
  pendingBuy = null;
  clearError();
  clearTxStatus();
  updateWalletUI();
  renderBuyConfirm();
  renderListings();
  renderMyPasses();
  refreshTestnetPanel();
}

function updateWalletUI() {
  const btn = $("connect-btn");
  const label = $("account-label");
  if (account) {
    btn.textContent = t("disconnectBtn");
    btn.classList.remove("btn-primary");
    label.textContent = shortAddress(account);
    label.hidden = false;
  } else {
    btn.textContent = t("connectBtn");
    btn.classList.add("btn-primary");
    label.hidden = true;
  }
  updateNetworkUI();
}

function updateNetworkUI() {
  const pill = $("network-pill");
  const warning = $("network-warning");
  if (walletChainId === null) {
    pill.hidden = true;
    warning.hidden = true;
    return;
  }
  pill.hidden = false;
  if (walletChainId === CHAIN_ID) {
    pill.textContent = t("networkOk");
    pill.className = "pill pill-ok";
    warning.hidden = true;
  } else {
    pill.textContent = t("networkWrong", { chain: walletChainId });
    pill.className = "pill pill-warn";
    warning.hidden = false;
  }
}

async function switchToBsc() {
  clearError();
  try {
    await window.ethereum.request({
      method: "wallet_switchEthereumChain",
      params: [{ chainId: CHAIN_ID_HEX }],
    });
  } catch (err) {
    // 4902: chain belum ditambahkan ke wallet — minta ditambahkan.
    if (err.code === 4902) {
      await window.ethereum.request({
        method: "wallet_addEthereumChain",
        params: [BSC_CHAIN_PARAMS],
      });
    } else {
      throw err;
    }
  }
  // Listener chainChanged menyegarkan state setelah perpindahan.
}

/** Pastikan wallet di BSC sebelum transaksi; minta pindah bila belum. */
async function ensureBsc() {
  if (walletChainId === CHAIN_ID) return;
  await switchToBsc();
  // Baca ulang chain-nya: listener mungkin belum sempat jalan.
  const network = await walletProvider.getNetwork();
  walletChainId = Number(network.chainId);
  updateNetworkUI();
  if (walletChainId !== CHAIN_ID) {
    throw new Error("WRONG_NETWORK");
  }
}

function setBusy(value) {
  busy = value;
  // Render ulang agar semua tombol transaksi ikut status busy.
  // (Draf input harga di "Pass saya" dipertahankan lewat priceDrafts.)
  renderListings();
  renderMyPasses();
  renderBuyConfirm();
  renderTestnetPanel();
}

// ---------------------------------------------------------------------------
// Panel testnet (bacaan publik — jalan tanpa wallet)
// ---------------------------------------------------------------------------
// Di testnet tidak ada KongSale: tidak ada sale, graduation, klaim, atau
// refund. Bagian ini menggantikan seluruh "Status sale" + "Kurs IDR"
// halaman mainnet. Isinya status token test: saldo test USDT, stok
// dispenser, dan apakah wallet sudah klaim test pass.

const testnet = {
  dispenserRemaining: null,
  dispenserNextId: null,
  alreadyClaimed: null,
  usdtBalance: null,
};

function dispenserContract(providerOrSigner) {
  return new ethers.Contract(DISPENSER_ADDRESS, DISPENSER_ABI, providerOrSigner);
}
function mockUsdtContract(providerOrSigner) {
  return new ethers.Contract(USDT_ADDRESS, MOCK_USDT_ABI, providerOrSigner);
}

async function refreshTestnetPanel() {
  try {
    const [remaining, nextId, decimals] = await Promise.all([
      withReadProvider((p) => dispenserContract(p).remaining()),
      withReadProvider((p) => dispenserContract(p).nextId()),
      withReadProvider((p) => usdtContract(p).decimals()),
    ]);
    testnet.dispenserRemaining = Number(remaining);
    testnet.dispenserNextId = Number(nextId);
    usdtDecimals = Number(decimals);
  } catch {
    // Panel tetap tampil dengan nilai terakhir; tombol klaim/mint akan
    // gagal dengan pesan yang jelas bila RPC masih mati.
  }
  if (account) {
    try {
      const [claimed, usdtBalance] = await Promise.all([
        withReadProvider((p) => dispenserContract(p).claimed(account)),
        withReadProvider((p) => usdtContract(p).balanceOf(account)),
      ]);
      testnet.alreadyClaimed = claimed;
      testnet.usdtBalance = usdtBalance;
    } catch {
      testnet.alreadyClaimed = null;
      testnet.usdtBalance = null;
    }
  } else {
    testnet.alreadyClaimed = null;
    testnet.usdtBalance = null;
  }
  renderTestnetPanel();
}

function renderTestnetPanel() {
  const remainingEl = $("dispenser-remaining");
  remainingEl.textContent =
    testnet.dispenserRemaining === null
      ? "—"
      : t("passRemaining", { n: testnet.dispenserRemaining });

  const usdtEl = $("testnet-usdt-balance");
  usdtEl.textContent = !account
    ? t("connectToSeeBalance")
    : testnet.usdtBalance === null
      ? "—"
      : fmtUsdt(testnet.usdtBalance, usdtDecimals);

  const passEl = $("testnet-pass-status");
  passEl.textContent = !account
    ? t("connectToClaimPass")
    : testnet.alreadyClaimed === null
      ? "—"
      : testnet.alreadyClaimed
        ? t("alreadyClaimedPass")
        : t("notClaimedPass");

  const mintBtn = $("mint-usdt-btn");
  mintBtn.disabled = busy || !account;
  const claimBtn = $("claim-pass-btn");
  claimBtn.disabled =
    busy ||
    !account ||
    testnet.alreadyClaimed === true ||
    testnet.dispenserRemaining === 0;
  if (testnet.dispenserRemaining === 0) {
    claimBtn.textContent = t("stockEmptyBtn");
  } else if (testnet.alreadyClaimed) {
    claimBtn.textContent = t("claimedBtn");
  } else {
    claimBtn.textContent = t("claimBtn");
  }
}

/** Mint 100 test USDT ke wallet sendiri (MockUSDT.mint publik). */
async function mintTestUsdt() {
  if (busy || !account) return;
  setBusy(true);
  clearTxStatus();
  try {
    await ensureBsc();
    const amount = ethers.parseUnits("100", usdtDecimals);
    const write = mockUsdtContract(signer);
    await write.mint.staticCall(account, amount);
    const tx = await write.mint(account, amount);
    setTxStatus([
      [{ text: t("mintUsdtPending") }],
      [
        { text: t("txLabel") },
        { text: shortAddress(tx.hash), href: bscscanTx(tx.hash) },
      ],
    ]);
    await tx.wait(1);
    setTxStatus([
      [
        {
          text: t("mintUsdtDone"),
        },
      ],
      [
        { text: t("txLabel") },
        { text: shortAddress(tx.hash), href: bscscanTx(tx.hash) },
      ],
    ]);
    await refreshTestnetPanel();
    await refreshWallet();
  } catch (err) {
    setTxStatus([[{ text: t("mintUsdtFailed", { err: friendlyError(err) }) }]]);
  } finally {
    setBusy(false);
  }
}

/** Klaim 1 test pass dari dispenser (1 per wallet, selamanya). */
async function claimTestPass() {
  if (busy || !account) return;
  setBusy(true);
  clearTxStatus();
  try {
    await ensureBsc();
    const write = dispenserContract(signer);
    await write.claim.staticCall();
    const tx = await write.claim();
    setTxStatus([
      [{ text: t("claimPending") }],
      [
        { text: t("txLabel") },
        { text: shortAddress(tx.hash), href: bscscanTx(tx.hash) },
      ],
    ]);
    const receipt = await tx.wait(1);
    // TokenId klaim dibaca dari event Claimed di receipt.
    let claimedId = null;
    try {
      const iface = new ethers.Interface(DISPENSER_ABI);
      for (const log of receipt.logs) {
        try {
          const parsed = iface.parseLog(log);
          if (parsed && parsed.name === "Claimed") {
            claimedId = Number(parsed.args.tokenId);
            break;
          }
        } catch {
          // Bukan log dispenser — lewati.
        }
      }
    } catch {
      // Event tidak terbaca — pass tetap bisa dicek di "Pass saya".
    }
    setTxStatus([
      [
        {
          text:
            claimedId !== null
              ? t("claimDoneWithId", { id: claimedId })
              : t("claimDone"),
        },
      ],
      [
        { text: t("txLabel") },
        { text: shortAddress(tx.hash), href: bscscanTx(tx.hash) },
      ],
    ]);
    await refreshTestnetPanel();
    await refreshWallet();
  } catch (err) {
    setTxStatus([[{ text: t("claimFailed", { err: friendlyError(err) }) }]]);
  } finally {
    setBusy(false);
  }
}

// ---------------------------------------------------------------------------
// Listing: ambil event, rekonstruksi, verifikasi live
// ---------------------------------------------------------------------------

/** Muat ulang seluruh listing — TESTNET: dibaca langsung dari state
 *  kontrak, BUKAN dari event. Alasannya: API Etherscan V2 gratis tidak
 *  mendukung chain 97 ("Free API access is not supported for this chain",
 *  terverifikasi 20 Nov 2026), dan fallback eth_getLogs tidak praktis
 *  karena testnet memproduksi ~2,2 blok/detik (rentang dari blok deploy
 *  tumbuh ~190 ribu blok/hari). Di testnet suplai pass kecil (puluhan),
 *  jadi scan listingOf(1..N) — dengan N dari pass.nextTokenId() —
 *  lengkap, cepat, dan selalu mencerminkan state terkini (listing yang
 *  terjual/dibatalkan punya seller = address(0) sehingga otomatis
 *  tidak muncul).
 */
/**
 * Verifikasi live satu listing: penjual masih pemilik, approval ke
 * market masih ada, dan data on-chain masih sama dengan yang dipindai.
 * (Fungsi ini sempat hilang saat fork testnet dibuat 20 Nov 2026 —
 * transform script menghapusnya bersama helper log BscScan — sehingga
 * loadListings() melempar ReferenceError begitu listing pertama muncul
 * dan halaman terjebak di status "Loading listings..." selamanya.
 * Dipulihkan dari market.js mainnet; alasan stale memakai string yang
 * sama seperti mainnet.)
 */
async function verifyListing(listing) {
  if (!isKnownCurrency(listing.paymentToken)) {
    return { status: "stale", reason: "Mata uang listing tidak dikenal." };
  }
  try {
    const [owner, approved, approvedForAll, onChain] = await Promise.all([
      // ownerOf revert (CALL_EXCEPTION) = token tidak ada lagi (dibakar).
      withReadProvider((p) => passContract(p).ownerOf(listing.tokenId)).catch(
        (err) => {
          if (err.code === "CALL_EXCEPTION") return null;
          throw err;
        }
      ),
      withReadProvider((p) => passContract(p).getApproved(listing.tokenId)),
      withReadProvider((p) =>
        passContract(p).isApprovedForAll(listing.seller, MARKET_ADDRESS)
      ),
      withReadProvider((p) => marketContract(p).listingOf(listing.tokenId)),
    ]);
    if (owner === null) {
      return { status: "stale", reason: "Pass sudah tidak ada (dibakar/diklaim)." };
    }
    if (owner.toLowerCase() !== listing.seller.toLowerCase()) {
      return { status: "stale", reason: "Penjual bukan lagi pemilik pass." };
    }
    if (
      approved.toLowerCase() !== MARKET_ADDRESS.toLowerCase() &&
      !approvedForAll
    ) {
      return {
        status: "stale",
        reason: "Approval ke market sudah dicabut penjual.",
      };
    }
    if (
      onChain.seller.toLowerCase() !== listing.seller.toLowerCase() ||
      onChain.price !== listing.price ||
      onChain.paymentToken.toLowerCase() !==
        listing.paymentToken.toLowerCase()
    ) {
      return {
        status: "stale",
        reason: "Listing di kontrak sudah berubah (harga/penjual berbeda).",
      };
    }
    return { status: "ok" };
  } catch {
    // RPC gagal — bukan bukti listing basi; tampilkan tanpa tombol Beli.
    return { status: "unknown" };
  }
}

async function loadListings() {
  if (!MARKET_DEPLOYED) {
    listings = new Map();
    verified = [];
    staleCount = 0;
    listingsLoading = false;
    listingsError = null;
    renderListings();
    return;
  }
  listingsLoading = true;
  listingsError = null;
  renderListings();
  listingsSource = "direct";
  try {
    const nextId = Number(
      await withReadProvider((p) => passContract(p).nextTokenId())
    );
    const found = new Map();
    // Pindai listingOf(1..nextId-1) lewat Multicall3: 50 id per eth_call
    // (terverifikasi live 20 Nov 2026: 368 id dalam ~2,5 detik).
    // Bila satu batch multicall gagal, fallback ke bacaan per panggilan
    // untuk id-id di batch itu. Id yang gagal di kedua jalur dicoba
    // sekali lagi; yang tetap gagal dianggap tidak ter-listing. Hanya
    // bila SEMUA bacaan gagal halaman menampilkan error.
    let anyReadOk = false;
    for (let start = 1; start < nextId; start += LISTING_SCAN_BATCH) {
      const end = Math.min(start + LISTING_SCAN_BATCH - 1, nextId - 1);
      const ids = [];
      for (let i = start; i <= end; i++) ids.push(i);
      const readBatch = async (list) => {
        const mc = await readListingsMulticall(list);
        if (mc) return mc;
        return withReadProvider((p) => {
          const c = marketContract(p);
          return Promise.all(
            list.map((id) =>
              c
                .listingOf(id)
                .then(([seller, price, paymentToken]) => ({
                  seller,
                  price,
                  paymentToken,
                }))
                .catch(() => null)
            )
          );
        });
      };
      const results = await readBatch(ids);
      const failedIdx = [];
      for (let k = 0; k < ids.length; k++) {
        if (results[k] === null) failedIdx.push(k);
        else anyReadOk = true;
      }
      if (failedIdx.length > 0) {
        const retry = await readBatch(failedIdx.map((k) => ids[k]));
        for (let j = 0; j < failedIdx.length; j++) {
          if (retry[j] !== null) {
            results[failedIdx[j]] = retry[j];
            anyReadOk = true;
          }
        }
      }
      for (let k = 0; k < ids.length; k++) {
        const onChain = results[k];
        if (!onChain) continue;
        if (
          onChain.seller.toLowerCase() !== ZERO_ADDRESS &&
          onChain.price > 0n
        ) {
          found.set(ids[k], {
            tokenId: ids[k],
            seller: onChain.seller,
            price: onChain.price,
            paymentToken: onChain.paymentToken,
            blockNumber: 0,
          });
        }
      }
    }
    if (nextId > 1 && !anyReadOk) throw new Error(t("rpcAllFailed"));
    listings = found;
  } catch (err) {
    listingsLoading = false;
    listingsError = err;
    renderListings();
    return;
  }

  // Verifikasi live + detail tier/claimable untuk tiap listing.
  const results = [];
  staleCount = 0;
  for (const listing of listings.values()) {
    const check = await verifyListing(listing);
    if (check.status === "stale") {
      staleCount++;
      continue;
    }
    let tier = null;
    let claimable = null;
    try {
      [tier, claimable] = await Promise.all([
        withReadProvider((p) => passContract(p).tierOf(listing.tokenId)),
        withReadProvider((p) => passContract(p).claimableOf(listing.tokenId)),
      ]);
      tier = Number(tier);
    } catch {
      // tierOf/claimableOf gagal (mis. RPC sibuk): pakai tier dari nomor
      // share — nomor token sama dengan nomor share, jadi tier bisa
      // diturunkan dari konstanta kurva. Claimable ikut tier-nya.
      tier = tierOfShare(listing.tokenId);
      claimable =
        BigInt(tierMeta(tier).tokensPerShare) * 10n ** 18n;
    }
    results.push({ ...listing, tier, claimable, status: check.status });
  }
  verified = results;
  listingsLoading = false;
  renderListings();
}

function filteredListings() {
  let list = [...verified];
  if (filters.tier !== 0) list = list.filter((l) => l.tier === filters.tier);
  if (filters.currency === "USDT") list = list.filter((l) => isUsdt(l.paymentToken));
  if (filters.currency === "BNB") list = list.filter((l) => isBnb(l.paymentToken));
  list.sort((a, b) => {
    const diff = priceToUsd(a.price, a.paymentToken) - priceToUsd(b.price, b.paymentToken);
    return filters.sort === "asc" ? diff : -diff;
  });
  return list;
}

function renderListings() {
  const grid = $("listing-grid");
  const countEl = $("listings-count");
  const noteEl = $("listings-note");
  grid.replaceChildren();

  if (!MARKET_DEPLOYED) {
    countEl.textContent = "";
    noteEl.textContent =
      t("marketNotDeployedNote");
    const p = document.createElement("p");
    p.className = "empty-note";
    p.textContent =
      t("marketNotDeployedEmpty");
    grid.appendChild(p);
    return;
  }

  if (listingsLoading) {
    countEl.textContent = "";
    noteEl.textContent = "";
    const p = document.createElement("p");
    p.className = "empty-note";
    p.textContent = t("loadingListings");
    grid.appendChild(p);
    return;
  }

  if (listingsError) {
    countEl.textContent = "";
    noteEl.textContent = "";
    const p = document.createElement("p");
    p.className = "empty-note";
    p.textContent = t("listingsLoadFailed", { err: friendlyError(listingsError) });
    grid.appendChild(p);
    return;
  }

  const list = filteredListings();
  countEl.textContent =
    verified.length === 0
      ? t("noListings")
      : t("showingListings", { shown: list.length, total: verified.length });
  const notes = [];
  if (staleCount > 0) {
    notes.push(
      t("staleHidden", { n: staleCount })
    );
  }
  if (listingsSource === "rpc") {
    notes.push(
      t("rpcFallbackNote")
    );
  }
  noteEl.textContent = notes.join(" ");

  if (list.length === 0) {
    const p = document.createElement("p");
    p.className = "empty-note";
    p.textContent =
      verified.length === 0
        ? t("noListingsYet")
        : t("noFilterMatch");
    grid.appendChild(p);
    return;
  }

  for (const listing of list) {
    grid.appendChild(buildListingCard(listing));
  }
}

function buildListingCard(listing) {
  const meta = tierMeta(listing.tier);
  const card = document.createElement("article");
  card.className = "pass-card listing-card";
  card.style.setProperty("--tier-color", meta.color);

  const img = document.createElement("img");
  img.src = meta.image;
  img.alt = `Kong Mint Pass #${listing.tokenId} — ${meta.name}`;
  img.loading = "lazy";
  card.appendChild(img);

  const body = document.createElement("div");
  body.className = "pass-body";

  const title = document.createElement("h3");
  title.textContent = `Pass #${listing.tokenId}`;
  body.appendChild(title);

  const tierLine = document.createElement("p");
  tierLine.textContent = meta.name;
  body.appendChild(tierLine);

  const priceLine = document.createElement("p");
  priceLine.className = "listing-price";
  priceLine.textContent = fmtPrice(listing.price, listing.paymentToken);
  body.appendChild(priceLine);

  const idrLine = document.createElement("p");
  idrLine.className = "listing-idr";
  idrLine.textContent = t("testnetNoValue");
  body.appendChild(idrLine);

  const claimLine = document.createElement("p");
  claimLine.className = "pass-value";
  claimLine.textContent = t("claimValueSim", { value: fmtKong(listing.claimable) });
  body.appendChild(claimLine);

  const sellerLine = document.createElement("p");
  const sellerLink = document.createElement("a");
  sellerLink.href = bscscanAddress(listing.seller);
  sellerLink.target = "_blank";
  sellerLink.rel = "noopener";
  sellerLink.textContent = t("sellerLabel", { addr: shortAddress(listing.seller) });
  sellerLine.appendChild(sellerLink);
  body.appendChild(sellerLine);

  const splitLine = document.createElement("p");
  splitLine.className = "listing-split";
  splitLine.textContent =
    t("splitLine");
  body.appendChild(splitLine);

  const linkLine = document.createElement("p");
  const a = document.createElement("a");
  a.href = bscscanToken(listing.tokenId);
  a.target = "_blank";
  a.rel = "noopener";
  a.textContent = t("viewBscScan");
  linkLine.appendChild(a);
  body.appendChild(linkLine);

  if (listing.status === "unknown") {
    const warn = document.createElement("p");
    warn.className = "listing-stale-note";
    warn.textContent =
      t("listingUnverified");
    body.appendChild(warn);
  } else if (!account) {
    const hint = document.createElement("p");
    hint.className = "listing-hint";
    hint.textContent = t("connectToBuy");
    body.appendChild(hint);
  } else if (listing.seller.toLowerCase() === account.toLowerCase()) {
    const hint = document.createElement("p");
    hint.className = "listing-hint";
    hint.textContent = t("ownListingHint");
    body.appendChild(hint);
  } else {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "btn btn-primary btn-small";
    btn.textContent = t("buyBtn");
    btn.disabled = busy;
    btn.addEventListener("click", () => startBuy(listing));
    body.appendChild(btn);
  }

  card.appendChild(body);
  return card;
}

// ---------------------------------------------------------------------------
// Membeli (verifikasi ulang live -> rincian pembagian -> konfirmasi -> tx)
// ---------------------------------------------------------------------------

/** Klik Beli: verifikasi ulang live, lalu tampilkan rincian pembagian
 *  (royalti dibaca LIVE dari royaltyInfo, bukan hardcode 5%) untuk
 *  dikonfirmasi sebelum transaksi apa pun dikirim. */
async function startBuy(listing) {
  if (busy || !account) return;
  clearTxStatus();
  setBusy(true);
  try {
    const check = await verifyListing(listing);
    if (check.status !== "ok") {
      setTxStatus([
        [
          {
            text: t("listingStale", {
              id: listing.tokenId,
              reason: check.reason ?? t("cannotVerifyNow"),
            }),
          },
        ],
      ]);
      await loadListings();
      return;
    }
    // Royalti live dari kontrak pass (ERC-2981). Bila gagal dibaca,
    // pakai asumsi 5% untuk estimasi — pembagian sebenarnya tetap
    // ditegakkan kontrak saat buy dieksekusi.
    let royalty = (listing.price * 5n) / 100n;
    let receiver = null;
    try {
      const r = await withReadProvider((p) =>
        passContract(p).royaltyInfo(listing.tokenId, listing.price)
      );
      royalty = r[1];
      receiver = r[0];
    } catch {
      // Estimasi 5% dipakai; kontrak yang menentukan angka final.
    }
    const fee = (listing.price * BigInt(MARKET_FEE_BPS)) / 10000n;
    const sellerGets = listing.price - royalty - fee;
    pendingBuy = {
      ...listing,
      royalty,
      fee,
      sellerGets,
      receiver,
    };
    renderBuyConfirm();
    $("buy-confirm").scrollIntoView({ behavior: "smooth", block: "center" });
  } catch (err) {
    setTxStatus([[{ text: t("verifyFailed", { err: friendlyError(err) }) }]]);
  } finally {
    setBusy(false);
  }
}

function renderBuyConfirm() {
  const box = $("buy-confirm");
  if (!pendingBuy) {
    box.hidden = true;
    box.replaceChildren();
    return;
  }
  box.hidden = false;
  box.replaceChildren();

  const meta = tierMeta(pendingBuy.tier);
  const title = document.createElement("h3");
  title.textContent = t("buyConfirmTitle", { id: pendingBuy.tokenId, tier: meta.name });
  box.appendChild(title);

  const quote = document.createElement("div");
  quote.className = "quote-box";
  const rows = [
    [t("quotePrice"), fmtPrice(pendingBuy.price, pendingBuy.paymentToken)],
    [t("quoteMaxPrice"), fmtPrice(pendingBuy.price, pendingBuy.paymentToken)],
    [t("quoteSellerGets"), fmtPrice(pendingBuy.sellerGets, pendingBuy.paymentToken)],
    [t("quoteRoyalty"), fmtPrice(pendingBuy.royalty, pendingBuy.paymentToken)],
    [t("quoteFee"), fmtPrice(pendingBuy.fee, pendingBuy.paymentToken)],
    [t("quoteClaim"), fmtKong(pendingBuy.claimable)],
    [t("quoteSeller"), shortAddress(pendingBuy.seller)],
  ];
  for (const [label, value] of rows) {
    const row = document.createElement("div");
    row.className = "quote-row";
    const l = document.createElement("span");
    l.textContent = label;
    const v = document.createElement("strong");
    v.textContent = value;
    row.appendChild(l);
    row.appendChild(v);
    quote.appendChild(row);
  }
  box.appendChild(quote);

  const note = document.createElement("p");
  note.className = "muted-text";
  note.textContent = isUsdt(pendingBuy.paymentToken)
    ? t("payUsdtNote")
    : t("payBnbNote");
  box.appendChild(note);

  const warn = document.createElement("p");
  warn.className = "muted-text";
  warn.textContent =
    t("maxPriceWarn");
  box.appendChild(warn);

  const actions = document.createElement("div");
  actions.className = "mint-actions";
  const confirmBtn = document.createElement("button");
  confirmBtn.id = "buy-confirm-btn";
  confirmBtn.type = "button";
  confirmBtn.className = "btn btn-primary";
  confirmBtn.textContent = t("confirmBuyBtn", {
    price: fmtPrice(pendingBuy.price, pendingBuy.paymentToken),
  });
  confirmBtn.disabled = busy;
  confirmBtn.addEventListener("click", confirmBuy);
  const cancelBtn = document.createElement("button");
  cancelBtn.type = "button";
  cancelBtn.className = "btn";
  cancelBtn.textContent = t("cancelBtn");
  cancelBtn.disabled = busy;
  cancelBtn.addEventListener("click", () => {
    pendingBuy = null;
    renderBuyConfirm();
  });
  actions.appendChild(confirmBtn);
  actions.appendChild(cancelBtn);
  box.appendChild(actions);
}

async function confirmBuy() {
  if (busy || !account || !pendingBuy) return;
  const listing = pendingBuy;
  setBusy(true);
  clearTxStatus();
  try {
    await ensureBsc();
    // Verifikasi ulang TEPAT sebelum mengirim — listing bisa berubah
    // selama pengguna membaca rincian pembagian.
    const check = await verifyListing(listing);
    if (check.status !== "ok") {
      throw new Error("LISTING_STALE");
    }
    if (listing.seller.toLowerCase() === account.toLowerCase()) {
      throw new Error("SELF_PURCHASE");
    }

    const write = marketContract(signer);
    let tx;
    if (isUsdt(listing.paymentToken)) {
      // USDT: approve dulu bila allowance ke market belum cukup.
      const allowance = await withReadProvider((p) =>
        usdtContract(p).allowance(account, MARKET_ADDRESS)
      );
      if (allowance < listing.price) {
        const usdt = new ethers.Contract(USDT_ADDRESS, ERC20_ABI, signer);
        const approveTx = await usdt.approve(MARKET_ADDRESS, listing.price);
        setTxStatus([
          [
            {
              text: t("approveUsdtPending", {
                amount: fmtUsdt(listing.price, usdtDecimals),
              }),
            },
          ],
          [
            { text: t("txLabel") },
            { text: shortAddress(approveTx.hash), href: bscscanTx(approveTx.hash) },
          ],
        ]);
        await approveTx.wait(1);
      }
      // Simulasi dulu: menangkap revert (listing basi, dll.) sebelum gas keluar.
      // maxPrice = harga listing terverifikasi (proteksi audit M-1: bila
      // harga listing naik di atas ini sebelum transaksi diproses, buy revert).
      await write.buy.staticCall(listing.tokenId, listing.price);
      tx = await write.buy(listing.tokenId, listing.price);
    } else {
      // BNB: kirim tepat sebesar harga bersama transaksi.
      await write.buy.staticCall(listing.tokenId, listing.price, {
        value: listing.price,
      });
      tx = await write.buy(listing.tokenId, listing.price, {
        value: listing.price,
      });
    }
    setTxStatus([
      [{ text: t("buyingPending", { id: listing.tokenId }) }],
      [
        { text: t("txLabel") },
        { text: shortAddress(tx.hash), href: bscscanTx(tx.hash) },
      ],
    ]);
    await tx.wait(1);
    pendingBuy = null;
    renderBuyConfirm();
    setTxStatus([
      [
        {
          text: t("buyDone", {
            id: listing.tokenId,
            price: fmtPrice(listing.price, listing.paymentToken),
          }),
        },
      ],
      [
        { text: t("txLabel") },
        { text: shortAddress(tx.hash), href: bscscanTx(tx.hash) },
      ],
    ]);
    await loadListings();
    await refreshWallet();
  } catch (err) {
    setTxStatus([
      [{ text: t("buyFailed", { err: friendlyError(err) }) }],
    ]);
    // Listing bisa saja sudah berubah — muat ulang agar grid tidak basi.
    if (err && err.message === "LISTING_STALE") await loadListings();
  } finally {
    setBusy(false);
  }
}

// ---------------------------------------------------------------------------
// Pass saya (scan ownerOf seperti halaman mint + cache localStorage)
// ---------------------------------------------------------------------------

async function refreshWallet() {
  if (!account) return;
  clearError();
  try {
    const [passBalance, usdtBalance, bnbBalance] = await Promise.all([
      withReadProvider((p) => passContract(p).balanceOf(account)),
      withReadProvider((p) => usdtContract(p).balanceOf(account)),
      withReadProvider((p) => p.getBalance(account)),
    ]);
    wallet.passBalance = Number(passBalance);
    wallet.usdtBalance = usdtBalance;
    wallet.bnbBalance = bnbBalance;
  } catch {
    showError(
      t("walletReadFailed")
    );
  }
  await refreshMyPasses();
}

const tokenCacheKey = () => `kong-testnet:tokens:${account.toLowerCase()}`;

function loadCachedTokenIds() {
  try {
    const raw = window.localStorage.getItem(tokenCacheKey());
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed.map(String) : [];
  } catch {
    return [];
  }
}

function saveCachedTokenIds(ids) {
  try {
    window.localStorage.setItem(tokenCacheKey(), JSON.stringify(ids.map(String)));
  } catch {
    // Mode privat dll. — scan ownerOf adalah fallback-nya.
  }
}

/** Cari pass milik wallet: cache dulu, lalu scan ownerOf(1..sharesSold).
 *  Pola yang sama dengan halaman mint (kontrak pass tanpa enumerasi). */
async function findOwnedPasses() {
  const balance = wallet.passBalance ?? 0;
  if (balance === 0) {
    saveCachedTokenIds([]);
    return [];
  }

  // 1. Periksa tokenId dari cache masih milik wallet ini.
  const cached = loadCachedTokenIds();
  const owned = new Set();
  if (cached.length > 0) {
    const owners = await withReadProvider((p) => {
      const c = passContract(p);
      return Promise.all(cached.map((id) => c.ownerOf(id).catch(() => null)));
    });
    for (let i = 0; i < cached.length; i++) {
      if (owners[i] && owners[i].toLowerCase() === account.toLowerCase()) {
        owned.add(cached[i]);
      }
    }
  }

  // 2. Scan ownerOf(1..TESTNET_PASS_SCAN_CAP) sampai semua pass ketemu.
  // Di testnet tidak ada sale — cap-nya konstanta (stok dispenser kecil,
  // dan scan berhenti begitu semua pass milik wallet sudah ketemu).
  if (owned.size < balance) {
    const limit = TESTNET_PASS_SCAN_CAP;
    const CHUNK = 50;
    for (let start = 1; start <= limit && owned.size < balance; start += CHUNK) {
      const ids = [];
      for (let i = start; i <= Math.min(start + CHUNK - 1, limit); i++) {
        if (!owned.has(String(i))) ids.push(i);
      }
      if (ids.length === 0) continue;
      const owners = await withReadProvider((p) => {
        const c = passContract(p);
        return Promise.all(ids.map((id) => c.ownerOf(id).catch(() => null)));
      });
      for (let j = 0; j < ids.length; j++) {
        if (owners[j] && owners[j].toLowerCase() === account.toLowerCase()) {
          owned.add(String(ids[j]));
        }
      }
    }
  }

  const ids = [...owned].map(Number).sort((a, b) => a - b);
  saveCachedTokenIds(ids);

  // 3. Detail per pass: tier, claimable, status listing + approval live.
  const details = await Promise.all(
    ids.map(async (id) => {
      const [tier, claimable] = await Promise.all([
        withReadProvider((p) => passContract(p).tierOf(id)),
        withReadProvider((p) => passContract(p).claimableOf(id)),
      ]);
      let listed = false;
      let listingPrice = null;
      let listingCurrency = null;
      let approved = false;
      if (MARKET_DEPLOYED) {
        try {
          const [onChain, approvedAddr, approvedForAll] = await Promise.all([
            withReadProvider((p) => marketContract(p).listingOf(id)),
            withReadProvider((p) => passContract(p).getApproved(id)),
            withReadProvider((p) =>
              passContract(p).isApprovedForAll(account, MARKET_ADDRESS)
            ),
          ]);
          approved =
            approvedAddr.toLowerCase() === MARKET_ADDRESS.toLowerCase() ||
            approvedForAll;
          if (
            onChain.seller.toLowerCase() === account.toLowerCase() &&
            onChain.price > 0n
          ) {
            listed = true;
            listingPrice = onChain.price;
            listingCurrency = isUsdt(onChain.paymentToken) ? "USDT" : "BNB";
          }
        } catch {
          // Listing/approval tidak terbaca — kartu tetap tampil dengan
          // info listing kosong; aksi list akan memverifikasi ulang.
        }
      }
      return {
        tokenId: id,
        tier: Number(tier),
        claimable,
        listed,
        listingPrice,
        listingCurrency,
        approved,
      };
    })
  );
  return details;
}

async function refreshMyPasses() {
  if (!account) {
    wallet.passes = [];
    renderMyPasses();
    return;
  }
  $("my-passes-loading").hidden = false;
  try {
    wallet.passes = await findOwnedPasses();
  } catch {
    showError(
      t("myPassesLoadFailed")
    );
    wallet.passes = [];
  }
  $("my-passes-loading").hidden = true;
  renderMyPasses();
}

function renderMyPasses() {
  const grid = $("my-passes-grid");
  const note = $("my-passes-note");
  grid.replaceChildren();

  if (!account) {
    note.textContent = t("connectToSeePassesNote");
    const p = document.createElement("p");
    p.className = "empty-note";
    p.textContent = t("connectToSeePasses");
    grid.appendChild(p);
    return;
  }
  if (wallet.passes.length === 0) {
    note.textContent =
      wallet.passBalance === 0
        ? t("noTestPassNote")
        : t("scanningPasses");
    const p = document.createElement("p");
    p.className = "empty-note";
    p.textContent =
      wallet.passBalance === 0
        ? t("noMintPass")
        : t("scanningPassesChain");
    grid.appendChild(p);
    return;
  }
  note.textContent = MARKET_DEPLOYED
    ? t("holdingPasses", { n: wallet.passes.length })
    : t("holdingPassesNotDeployed", { n: wallet.passes.length });

  for (const pass of wallet.passes) {
    grid.appendChild(buildMyPassCard(pass));
  }
}

function buildMyPassCard(pass) {
  const meta = tierMeta(pass.tier);
  const card = document.createElement("article");
  card.className = "pass-card";
  card.style.setProperty("--tier-color", meta.color);

  const img = document.createElement("img");
  img.src = meta.image;
  img.alt = `Kong Mint Pass #${pass.tokenId} — ${meta.name}`;
  img.loading = "lazy";
  card.appendChild(img);

  const body = document.createElement("div");
  body.className = "pass-body";

  const title = document.createElement("h3");
  title.textContent = `Pass #${pass.tokenId}`;
  body.appendChild(title);

  const tierLine = document.createElement("p");
  tierLine.textContent = meta.name;
  body.appendChild(tierLine);

  const claimLine = document.createElement("p");
  claimLine.className = "pass-value";
  claimLine.textContent = t("claimValueSim", { value: fmtKong(pass.claimable) });
  body.appendChild(claimLine);

  const linkLine = document.createElement("p");
  const a = document.createElement("a");
  a.href = bscscanToken(pass.tokenId);
  a.target = "_blank";
  a.rel = "noopener";
  a.textContent = t("viewBscScan");
  linkLine.appendChild(a);
  body.appendChild(linkLine);

  if (!MARKET_DEPLOYED) {
    const hint = document.createElement("p");
    hint.className = "listing-hint";
    hint.textContent = t("listingOpensAfterDeploy");
    body.appendChild(hint);
  } else if (pass.listed) {
    body.appendChild(buildListedControls(pass));
  } else {
    body.appendChild(buildListForm(pass));
  }

  const claimLink = document.createElement("p");
  const claimA = document.createElement("a");
  claimA.href = "#test-tokens";
  claimA.textContent = t("getFreeTestPass");
  claimLink.appendChild(claimA);
  body.appendChild(claimLink);

  card.appendChild(body);
  return card;
}

/** Kontrol untuk pass yang sudah ter-listing: ubah harga / batalkan. */
function buildListedControls(pass) {
  const wrap = document.createElement("div");
  wrap.className = "list-form";

  const status = document.createElement("p");
  status.className = "listing-status";
  status.textContent = t("listedPrice", {
    price: fmtPrice(
      pass.listingPrice,
      pass.listingCurrency === "USDT" ? USDT_ADDRESS : ZERO_ADDRESS
    ),
  });
  wrap.appendChild(status);

  if (!pass.approved) {
    const warn = document.createElement("p");
    warn.className = "listing-stale-note";
    warn.textContent =
      t("approvalStaleWarn");
    wrap.appendChild(warn);
    const approveBtn = document.createElement("button");
    approveBtn.type = "button";
    approveBtn.className = "btn btn-small";
    approveBtn.textContent = t("reapproveBtn");
    approveBtn.disabled = busy;
    approveBtn.addEventListener("click", () => approvePass(pass.tokenId));
    wrap.appendChild(approveBtn);
  }

  const label = document.createElement("label");
  label.className = "list-label";
  label.textContent = t("newPriceLabel", { currency: pass.listingCurrency });
  wrap.appendChild(label);

  const input = document.createElement("input");
  input.className = "text-input list-input";
  input.type = "text";
  input.inputMode = "decimal";
  input.autocomplete = "off";
  input.spellcheck = false;
  const draftKey = `update-${pass.tokenId}`;
  input.value =
    priceDrafts.get(draftKey) ??
    ethers.formatUnits(pass.listingPrice, 18);
  input.addEventListener("input", () => priceDrafts.set(draftKey, input.value));
  wrap.appendChild(input);

  const floorNote = document.createElement("p");
  floorNote.className = "floor-note";
  const floor = floorRaw(pass.tier, pass.listingCurrency);
  floorNote.textContent = t("floorNote", {
    tier: meta_name(pass.tier),
    floor:
      pass.listingCurrency === "USDT" ? fmtUsdt(floor) : fmtBnb(floor),
    breakeven:
      pass.listingCurrency === "USDT"
        ? fmtUsdt(breakevenRaw(pass.tier, "USDT"))
        : fmtBnb(breakevenRaw(pass.tier, "BNB")),
  });
  wrap.appendChild(floorNote);

  const errNote = document.createElement("p");
  errNote.className = "referrer-note note-bad";
  errNote.hidden = true;
  wrap.appendChild(errNote);

  const actions = document.createElement("div");
  actions.className = "mint-actions";
  const updateBtn = document.createElement("button");
  updateBtn.type = "button";
  updateBtn.className = "btn btn-primary btn-small";
  updateBtn.textContent = t("updatePriceBtn");
  updateBtn.disabled = busy;
  updateBtn.addEventListener("click", () =>
    updatePriceFlow(pass, input.value, errNote)
  );
  const cancelBtn = document.createElement("button");
  cancelBtn.type = "button";
  cancelBtn.className = "btn btn-small";
  cancelBtn.textContent = t("cancelListingBtn");
  cancelBtn.disabled = busy;
  cancelBtn.addEventListener("click", () => cancelListingFlow(pass));
  actions.appendChild(updateBtn);
  actions.appendChild(cancelBtn);
  wrap.appendChild(actions);

  return wrap;
}

/** Form untuk me-listing pass yang belum ter-listing. */
function buildListForm(pass) {
  const wrap = document.createElement("div");
  wrap.className = "list-form";

  const label = document.createElement("label");
  label.className = "list-label";
  label.textContent = t("sellPriceLabel");
  wrap.appendChild(label);

  const row = document.createElement("div");
  row.className = "list-row";
  const input = document.createElement("input");
  input.className = "text-input list-input";
  input.type = "text";
  input.inputMode = "decimal";
  input.placeholder = t("pricePlaceholder");
  input.autocomplete = "off";
  input.spellcheck = false;
  const draftKey = `list-${pass.tokenId}`;
  input.value = priceDrafts.get(draftKey) ?? "";
  input.addEventListener("input", () => priceDrafts.set(draftKey, input.value));
  const select = document.createElement("select");
  select.className = "text-input list-currency";
  for (const cur of ["USDT", "BNB"]) {
    const opt = document.createElement("option");
    opt.value = cur;
    opt.textContent = cur;
    select.appendChild(opt);
  }
  select.value = currencyDrafts.get(draftKey) ?? "USDT";
  row.appendChild(input);
  row.appendChild(select);
  wrap.appendChild(row);

  const floorNote = document.createElement("p");
  floorNote.className = "floor-note";
  const updateFloorNote = () => {
    const cur = select.value;
    const floor = floorRaw(pass.tier, cur);
    const token = cur === "USDT" ? USDT_ADDRESS : ZERO_ADDRESS;
    floorNote.textContent = t("floorNoteList", {
      tier: meta_name(pass.tier),
      floor: cur === "USDT" ? fmtUsdt(floor) : fmtBnb(floor),
      breakeven:
        cur === "USDT"
          ? fmtUsdt(breakevenRaw(pass.tier, "USDT"))
          : fmtBnb(breakevenRaw(pass.tier, "BNB")),
    });
  };
  select.addEventListener("change", () => {
    currencyDrafts.set(draftKey, select.value);
    updateFloorNote();
  });
  updateFloorNote();
  wrap.appendChild(floorNote);

  const errNote = document.createElement("p");
  errNote.className = "referrer-note note-bad";
  errNote.hidden = true;
  wrap.appendChild(errNote);

  const btn = document.createElement("button");
  btn.type = "button";
  btn.className = "btn btn-primary btn-small";
  btn.textContent = t("listPassBtn");
  btn.disabled = busy;
  btn.addEventListener("click", () =>
    listPassFlow(pass, input.value, select.value, errNote)
  );
  wrap.appendChild(btn);

  return wrap;
}

function meta_name(tier) {
  return tierMeta(tier).name;
}

/** Parse input harga pengguna (terima koma atau titik sebagai desimal). */
function parsePriceInput(raw) {
  const normalized = raw.trim().replace(",", ".");
  if (!/^\d+(\.\d{1,18})?$/.test(normalized)) return null;
  try {
    return ethers.parseUnits(normalized, 18);
  } catch {
    return null;
  }
}

function showFormError(noteEl, message) {
  noteEl.textContent = message;
  noteEl.hidden = false;
}

/** Approve market atas satu pass (bila belum di-approve). */
async function approvePass(tokenId) {
  if (busy || !account) return;
  setBusy(true);
  clearTxStatus();
  try {
    await ensureBsc();
    const write = new ethers.Contract(KONG_PASS_ADDRESS, MARKET_PASS_ABI, signer);
    const [approvedAddr, approvedForAll] = await Promise.all([
      withReadProvider((p) => passContract(p).getApproved(tokenId)),
      withReadProvider((p) =>
        passContract(p).isApprovedForAll(account, MARKET_ADDRESS)
      ),
    ]);
    if (
      approvedAddr.toLowerCase() === MARKET_ADDRESS.toLowerCase() ||
      approvedForAll
    ) {
      setTxStatus([
        [{ text: t("passApprovedAlready", { id: tokenId }) }],
      ]);
      return;
    }
    const tx = await write.approve(MARKET_ADDRESS, tokenId);
    setTxStatus([
      [{ text: t("approvePending", { id: tokenId }) }],
      [
        { text: t("txLabel") },
        { text: shortAddress(tx.hash), href: bscscanTx(tx.hash) },
      ],
    ]);
    await tx.wait(1);
    setTxStatus([
      [
        {
          text: t("approveDone", { id: tokenId }),
        },
      ],
      [
        { text: t("txLabel") },
        { text: shortAddress(tx.hash), href: bscscanTx(tx.hash) },
      ],
    ]);
    await refreshMyPasses();
    await loadListings();
  } catch (err) {
    setTxStatus([[{ text: t("approveFailed", { err: friendlyError(err) }) }]]);
  } finally {
    setBusy(false);
  }
}

async function listPassFlow(pass, rawPrice, currency, errNote) {
  if (busy || !account) return;
  errNote.hidden = true;
  const price = parsePriceInput(rawPrice);
  if (price === null || price <= 0n) {
    showFormError(errNote, t("invalidPrice"));
    return;
  }
  const floor = floorRaw(pass.tier, currency);
  if (price < floor) {
    showFormError(
      errNote,
      t("belowFloor", {
        tier: meta_name(pass.tier),
        min: currency === "USDT" ? fmtUsdt(floor) : fmtBnb(floor),
      })
    );
    return;
  }
  const paymentToken = currency === "USDT" ? USDT_ADDRESS : ZERO_ADDRESS;
  setBusy(true);
  clearTxStatus();
  try {
    await ensureBsc();
    // 1. Approve market atas pass ini bila belum.
    const [approvedAddr, approvedForAll] = await Promise.all([
      withReadProvider((p) => passContract(p).getApproved(pass.tokenId)),
      withReadProvider((p) =>
        passContract(p).isApprovedForAll(account, MARKET_ADDRESS)
      ),
    ]);
    if (
      approvedAddr.toLowerCase() !== MARKET_ADDRESS.toLowerCase() &&
      !approvedForAll
    ) {
      const passWrite = new ethers.Contract(
        KONG_PASS_ADDRESS,
        MARKET_PASS_ABI,
        signer
      );
      const approveTx = await passWrite.approve(MARKET_ADDRESS, pass.tokenId);
      setTxStatus([
        [
          {
            text: t("approvePending", { id: pass.tokenId }),
          },
        ],
        [
          { text: t("txLabel") },
          { text: shortAddress(approveTx.hash), href: bscscanTx(approveTx.hash) },
        ],
      ]);
      await approveTx.wait(1);
    }
    // 2. List.
    const write = marketContract(signer);
    await write.list.staticCall(pass.tokenId, price, paymentToken);
    const tx = await write.list(pass.tokenId, price, paymentToken);
    setTxStatus([
      [
        {
          text: t("listingPending", {
            id: pass.tokenId,
            price: fmtPrice(price, paymentToken),
          }),
        },
      ],
      [
        { text: t("txLabel") },
        { text: shortAddress(tx.hash), href: bscscanTx(tx.hash) },
      ],
    ]);
    await tx.wait(1);
    priceDrafts.delete(`list-${pass.tokenId}`);
    setTxStatus([
      [
        {
          text: t("listingDone", {
            id: pass.tokenId,
            price: fmtPrice(price, paymentToken),
          }),
        },
      ],
      [
        { text: t("txLabel") },
        { text: shortAddress(tx.hash), href: bscscanTx(tx.hash) },
      ],
    ]);
    await loadListings();
    await refreshMyPasses();
  } catch (err) {
    setTxStatus([[{ text: t("listingFailed", { err: friendlyError(err) }) }]]);
  } finally {
    setBusy(false);
  }
}

async function updatePriceFlow(pass, rawPrice, errNote) {
  if (busy || !account) return;
  errNote.hidden = true;
  const price = parsePriceInput(rawPrice);
  if (price === null || price <= 0n) {
    showFormError(errNote, t("invalidPrice"));
    return;
  }
  const floor = floorRaw(pass.tier, pass.listingCurrency);
  if (price < floor) {
    showFormError(
      errNote,
      t("belowFloor", {
        tier: meta_name(pass.tier),
        min:
          pass.listingCurrency === "USDT"
            ? fmtUsdt(floor)
            : fmtBnb(floor),
      })
    );
    return;
  }
  setBusy(true);
  clearTxStatus();
  try {
    await ensureBsc();
    const write = marketContract(signer);
    await write.updatePrice.staticCall(pass.tokenId, price);
    const tx = await write.updatePrice(pass.tokenId, price);
    setTxStatus([
      [
        {
          text: t("updatePricePending", {
            id: pass.tokenId,
            price: fmtPrice(
              price,
              pass.listingCurrency === "USDT" ? USDT_ADDRESS : ZERO_ADDRESS
            ),
          }),
        },
      ],
      [
        { text: t("txLabel") },
        { text: shortAddress(tx.hash), href: bscscanTx(tx.hash) },
      ],
    ]);
    await tx.wait(1);
    priceDrafts.delete(`update-${pass.tokenId}`);
    setTxStatus([
      [
        {
          text: t("updatePriceDone", {
            id: pass.tokenId,
            price: fmtPrice(
              price,
              pass.listingCurrency === "USDT" ? USDT_ADDRESS : ZERO_ADDRESS
            ),
          }),
        },
      ],
      [
        { text: t("txLabel") },
        { text: shortAddress(tx.hash), href: bscscanTx(tx.hash) },
      ],
    ]);
    await loadListings();
    await refreshMyPasses();
  } catch (err) {
    setTxStatus([[{ text: t("updatePriceFailed", { err: friendlyError(err) }) }]]);
  } finally {
    setBusy(false);
  }
}

async function cancelListingFlow(pass) {
  if (busy || !account) return;
  if (
    !window.confirm(
      t("cancelConfirm", { id: pass.tokenId })
    )
  ) {
    return;
  }
  setBusy(true);
  clearTxStatus();
  try {
    await ensureBsc();
    const write = marketContract(signer);
    await write.cancel.staticCall(pass.tokenId);
    const tx = await write.cancel(pass.tokenId);
    setTxStatus([
      [{ text: t("cancelPending", { id: pass.tokenId }) }],
      [
        { text: t("txLabel") },
        { text: shortAddress(tx.hash), href: bscscanTx(tx.hash) },
      ],
    ]);
    await tx.wait(1);
    setTxStatus([
      [
        {
          text: t("cancelDone", { id: pass.tokenId }),
        },
      ],
      [
        { text: t("txLabel") },
        { text: shortAddress(tx.hash), href: bscscanTx(tx.hash) },
      ],
    ]);
    await loadListings();
    await refreshMyPasses();
  } catch (err) {
    setTxStatus([[{ text: t("cancelFailed", { err: friendlyError(err) }) }]]);
  } finally {
    setBusy(false);
  }
}

// ---------------------------------------------------------------------------
// Pesan error (diterjemahkan lewat i18n — lihat ./i18n.js)
// ---------------------------------------------------------------------------

function friendlyError(err) {
  const msg = err && err.message ? String(err.message) : "";
  const code = err && err.code;

  if (msg === "WRONG_NETWORK") {
    return t("errWrongNetwork");
  }
  if (msg === "LISTING_STALE") {
    return t("errListingStale");
  }
  if (msg === "SELF_PURCHASE") {
    return t("errSelfPurchase");
  }
  if (msg === "BLOK_DEPLOY_BELUM_DIISI") {
    return t("errDeployBlockMissing");
  }
  if (code === 4001 || /user rejected|user denied/i.test(msg)) {
    return t("errUserRejected");
  }
  if (/insufficient funds/i.test(msg)) {
    return t("errInsufficientFunds");
  }
  // Custom error KongMarket (nama persis seperti di src/KongMarket.sol).
  if (/NoListing/.test(msg)) return t("errNoListing");
  if (/NotSeller/.test(msg)) return t("errNotSeller");
  if (/BelowFloor/.test(msg)) return t("errBelowFloor");
  if (/NotPassOwner/.test(msg)) return t("errNotPassOwner");
  if (/OwnershipChanged/.test(msg)) return t("errOwnershipChanged");
  if (/NotApproved/.test(msg)) return t("errNotApproved");
  if (/SelfPurchase/.test(msg)) return t("errSelfPurchase");
  if (/IncorrectValue/.test(msg)) return t("errIncorrectValue");
  if (/ValueNotAllowed/.test(msg)) return t("errValueNotAllowed");
  if (/InvalidPrice/.test(msg)) return t("errInvalidPrice");
  if (/InvalidPaymentToken/.test(msg)) return t("errInvalidPaymentToken");
  if (/NotTreasury/.test(msg)) return t("errNotTreasury");
  if (/NothingToSweep/.test(msg)) return t("errNothingToSweep");
  if (/PriceAboveMax/.test(msg)) return t("errPriceAboveMax");
  if (/ERC20InsufficientAllowance/.test(msg)) return t("errAllowance");
  if (/ERC20InsufficientBalance/.test(msg)) return t("errUsdtBalance");
  if (/ERC721NonexistentToken|nonexistent token/i.test(msg)) return t("errNoToken");
  if (/AlreadyClaimed/.test(msg)) return t("errAlreadyClaimed");
  if (/OutOfStock/.test(msg)) return t("errOutOfStock");
  if (/network|fetch|timeout|failed/i.test(msg) && code !== "CALL_EXCEPTION") {
    return t("errNetwork");
  }
  return t("errGeneric");
}

// ---------------------------------------------------------------------------
// Konten statis + init
// ---------------------------------------------------------------------------

function renderStaticInfo() {
  // Banner "belum di-deploy" — di testnet market SUDAH live, jadi tersembunyi.
  $("not-deployed-banner").hidden = MARKET_DEPLOYED;

  // Tautan faucet tBNB (satu-satunya sumber di config).
  $("faucet-link").href = FAUCET_URL;

  // Alamat kontrak market (atau status belum di-deploy).
  const marketLine = $("market-address-line");
  if (MARKET_DEPLOYED) {
    const a = document.createElement("a");
    a.className = "mono";
    a.href = bscscanAddress(MARKET_ADDRESS);
    a.target = "_blank";
    a.rel = "noopener";
    a.textContent = MARKET_ADDRESS;
    marketLine.replaceChildren(
      document.createTextNode(t("marketLabel")),
      a
    );
  } else {
    marketLine.textContent =
      t("marketNotDeployedLine");
  }

  // Footer: tautan kontrak.
  const links = [
    ["footer-pass", KONG_PASS_ADDRESS],
    ["footer-usdt", USDT_ADDRESS],
    ["footer-dispenser", DISPENSER_ADDRESS],
  ];
  for (const [id, addr] of links) {
    const el = $(id);
    el.textContent = addr;
    el.href = bscscanAddress(addr);
  }
  const marketFooter = $("footer-market");
  if (MARKET_DEPLOYED) {
    marketFooter.textContent = MARKET_ADDRESS;
    marketFooter.href = bscscanAddress(MARKET_ADDRESS);
  } else {
    marketFooter.textContent = t("notDeployedShort");
    marketFooter.removeAttribute("href");
  }
}

function wireWalletEvents() {
  if (!window.ethereum || typeof window.ethereum.on !== "function") return;
  window.ethereum.on("accountsChanged", (accounts) => {
    if (!accounts || accounts.length === 0) {
      disconnectWallet();
      return;
    }
    account = ethers.getAddress(accounts[0]);
    updateWalletUI();
    refreshWallet();
    refreshTestnetPanel();
    renderListings();
  });
  window.ethereum.on("chainChanged", async () => {
    // Provider dibuat ulang: ethers menyimpan cache jaringan di provider lama.
    walletProvider = new ethers.BrowserProvider(window.ethereum);
    signer = await walletProvider.getSigner();
    const network = await walletProvider.getNetwork();
    walletChainId = Number(network.chainId);
    updateNetworkUI();
    await refreshWallet();
    await refreshTestnetPanel();
    renderListings();
  });
}

async function init() {
  // Bahasa: baca preferensi tersimpan (bawaan: Indonesia), terapkan ke
  // teks statis HTML, lalu setel pemilih bahasa di header.
  const initialLang = initLang();
  applyStaticI18n();
  $("lang-select").value = initialLang;
  renderStaticInfo();
  renderTestnetPanel();
  renderListings();
  renderMyPasses();
  renderBuyConfirm();

  $("connect-btn").addEventListener("click", () => {
    if (account) disconnectWallet();
    else connectWallet();
  });
  $("switch-network-btn").addEventListener("click", async () => {
    try {
      await switchToBsc();
    } catch (err) {
      showError(friendlyError(err));
    }
  });
  $("filter-tier").addEventListener("change", (e) => {
    filters.tier = Number(e.target.value);
    renderListings();
  });
  $("filter-currency").addEventListener("change", (e) => {
    filters.currency = e.target.value;
    renderListings();
  });
  $("filter-sort").addEventListener("change", (e) => {
    filters.sort = e.target.value;
    renderListings();
  });
  $("refresh-listings-btn").addEventListener("click", () => {
    if (!listingsLoading) loadListings();
  });
  $("mint-usdt-btn").addEventListener("click", mintTestUsdt);
  $("claim-pass-btn").addEventListener("click", claimTestPass);
  $("lang-select").addEventListener("change", (e) => {
    if (!setLang(e.target.value)) return;
    applyStaticI18n();
    // Render ulang semua konten dinamis dalam bahasa baru. (Riwayat
    // tx-status / error-banner sengaja dibiarkan — itu log transaksi,
    // bukan teks antarmuka.)
    updateWalletUI();
    renderStaticInfo();
    renderTestnetPanel();
    renderListings();
    renderMyPasses();
    renderBuyConfirm();
  });

  wireWalletEvents();

  // Muat panel testnet + listing secara paralel (keduanya jalan tanpa
  // wallet dan independen), lalu polling panel testnet tiap menit.
  // Sebelumnya berurutan — listing menunggu panel (~25 detik) dulu.
  await Promise.all([refreshTestnetPanel(), loadListings()]);
  setInterval(refreshTestnetPanel, 60_000);

  // Reconnect diam-diam bila wallet sudah pernah diotorisasi (tanpa prompt).
  if (window.ethereum) {
    try {
      const accounts = await window.ethereum.request({ method: "eth_accounts" });
      if (accounts && accounts.length > 0) {
        walletProvider = new ethers.BrowserProvider(window.ethereum);
        account = ethers.getAddress(accounts[0]);
        signer = await walletProvider.getSigner();
        const network = await walletProvider.getNetwork();
        walletChainId = Number(network.chainId);
        updateWalletUI();
        await refreshWallet();
        await refreshTestnetPanel();
        renderListings();
      }
    } catch {
      // Tetap terputus; pengguna bisa menghubungkan manual.
    }
  }
}

init();
