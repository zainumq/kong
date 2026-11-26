// Marketplace $KONG — halaman /market, vanilla JS + ethers.js v6.
//
// Model non-custodial (spek §2): penjual tetap pegang pass dan hanya memberi
// approval ke kontrak market. Konsekuensinya listing bisa BASI (pass diklaim
// / dipindah / approval dicabut) — halaman ini memverifikasi setiap listing
// secara live (ownerOf + approval + listingOf) sebelum menampilkan tombol
// Beli, dan memverifikasi ulang tepat sebelum transaksi dikirim.
//
// Data listing direkonstruksi dari event Listed / PriceUpdated / Cancelled /
// Sold. Sumber UTAMA: BscScan API (Etherscan V2, module=logs). Fallback:
// eth_getLogs RPC publik (sering kena limit — jangan diandalkan sebagai
// sumber utama). Tanpa wallet pun listing tetap tampil; tombol transaksi
// baru aktif setelah wallet terhubung.
//
// Semua teks antarmuka lewat i18n.js (Indonesia / English / Mandarin).
//
// KONDISI SAAT INI: kontrak market BELUM di-deploy (MARKET_ADDRESS masih
// zero address di market-config.js). Dalam kondisi itu halaman menampilkan
// pesan "Marketplace belum dibuka" dan melewati semua pemanggilan kontrak
// market — tidak ada error mentah.

import { ethers } from "https://cdn.jsdelivr.net/npm/ethers@6.13.5/+esm";
import {
  KONG_SALE_ADDRESS,
  KONG_PASS_ADDRESS,
  USDT_ADDRESS,
  CHAIN_ID,
  CHAIN_ID_HEX,
  BSC_CHAIN_PARAMS,
  RPC_URLS,
  BSCSCAN_BASE,
  ZERO_ADDRESS,
  MAX_SHARES,
  TIERS,
  KONG_SALE_ABI,
  ERC20_ABI,
  PASS_SCAN_CAP,
  SALE_POLL_MS,
} from "../config.js";
import {
  MARKET_ADDRESS,
  MARKET_DEPLOY_BLOCK,
  BSCSCAN_API_KEY,
  BSCSCAN_API_V2,
  KONG_MARKET_ABI,
  MARKET_PASS_ABI,
  TIER_FLOORS,
  MARKET_FEE_BPS,
} from "./market-config.js";
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
// Market USDT-only sejak 26 Nov 2026 (opsi 2): satu-satunya mata uang
// pembayaran yang dikenal adalah USDT. Listing BNB lama (bila ada di
// state kontrak lama) dianggap tidak dikenal.
const isKnownCurrency = (paymentToken) => isUsdt(paymentToken);

// ---------------------------------------------------------------------------
// Format angka (lokal mengikuti bahasa aktif via numLocale())
// ---------------------------------------------------------------------------

const fmtInt = (n) => Number(n).toLocaleString(numLocale());
const fmtKong = (value) =>
  `${Number(ethers.formatUnits(value, 18)).toLocaleString(numLocale())} KONG`;
const fmtUsdt = (value, decimals = 18) =>
  `${Number(ethers.formatUnits(value, decimals)).toLocaleString(numLocale(), {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })} USDT`;
// fmtPrice: semua harga kini USDT (parameter paymentToken dipertahankan
// supaya semua pemanggil lama tetap jalan tanpa diubah).
const fmtPrice = (price) => fmtUsdt(price);

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

let walletProvider = null;
let signer = null;
let account = null;
let walletChainId = null;
let busy = false; // sebuah transaksi sedang berjalan
// BSC USDT (0x55d398…) 18 desimal (terverifikasi on-chain 19 Nov 2026).
// Dibaca live di refreshSaleState; 18 adalah fallback yang benar.
let usdtDecimals = 18;

// Nilai tukar harga listing ke USDT (dipakai untuk mengurutkan listing
// berdasarkan nilai yang sama). Semua listing kini USDT (harga = nilai
// USDT-nya), jadi tidak ada lagi konversi kurs BNB/USDT.
const priceToUsdt = (price) => Number(ethers.formatUnits(price, 18));

// Status sale (dibaca live dari KongSale — sama seperti halaman mint).
const sale = {
  sharesSold: null,
  totalRaised: null,
  graduated: null,
  saleStart: null,
  saleDeadline: null,
  refundDeadline: null,
  saleActive: null,
  refundActive: null,
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
let listingsLoading = false;
let listingsError = null;
let listingsSource = null; // "bscscan" | "rpc" | null

const filters = { tier: 0, currency: "all", sort: "asc" };

// Listing yang sedang menunggu konfirmasi beli (+ rincian pembagian dana).
let pendingBuy = null;

// Draf input harga/mata uang di kartu "Pass saya", dipertahankan saat
// kartu di-render ulang (mis. setelah transaksi selesai).
const priceDrafts = new Map(); // key "list-<id>" / "update-<id>" -> string
const currencyDrafts = new Map(); // key "list-<id>" -> "USDT"

// Provider baca-only, dicoba berurutan sampai ada yang menjawab.
const readProviders = RPC_URLS.map(
  (url) => new ethers.JsonRpcProvider(url, CHAIN_ID)
);

function saleContract(provider) {
  return new ethers.Contract(KONG_SALE_ADDRESS, KONG_SALE_ABI, provider);
}
function passContract(provider) {
  return new ethers.Contract(KONG_PASS_ADDRESS, MARKET_PASS_ABI, provider);
}
function usdtContract(provider) {
  return new ethers.Contract(USDT_ADDRESS, ERC20_ABI, provider);
}
function marketContract(providerOrSigner) {
  return new ethers.Contract(MARKET_ADDRESS, KONG_MARKET_ABI, providerOrSigner);
}

/** Jalankan `fn(provider)` ke provider baca berurutan; yang pertama sukses menang. */
async function withReadProvider(fn) {
  let lastError = null;
  for (const provider of readProviders) {
    try {
      return await fn(provider);
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

/** Floor tier dalam raw unit (18 desimal). Market USDT-only: floor selalu
 *  dari TIER_FLOORS (USDT). Parameter currency dipertahankan supaya
 *  pemanggil lama tetap jalan. */
function floorRaw(tier, currency) {
  const floor = TIER_FLOORS[tier];
  return ethers.parseUnits(floor.usdt, 18);
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
    showError(t("walletNotFound"));
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
}

// ---------------------------------------------------------------------------
// Status sale (bacaan publik — jalan tanpa wallet)
// ---------------------------------------------------------------------------

async function refreshSaleState() {
  try {
    const c = await withReadProvider(async (p) => {
      const s = saleContract(p);
      const [
        sharesSold,
        totalRaised,
        graduated,
        saleStart,
        saleDeadline,
        refundDeadline,
        saleActive,
        refundActive,
      ] = await Promise.all([
        s.sharesSold(),
        s.totalRaised(),
        s.graduated(),
        s.saleStart(),
        s.saleDeadline(),
        s.refundDeadline(),
        s.saleActive(),
        s.refundActive(),
      ]);
      return {
        sharesSold,
        totalRaised,
        graduated,
        saleStart,
        saleDeadline,
        refundDeadline,
        saleActive,
        refundActive,
      };
    });
    Object.assign(sale, {
      sharesSold: Number(c.sharesSold),
      totalRaised: c.totalRaised,
      graduated: c.graduated,
      saleStart: Number(c.saleStart),
      saleDeadline: Number(c.saleDeadline),
      refundDeadline: Number(c.refundDeadline),
      saleActive: c.saleActive,
      refundActive: c.refundActive,
    });

    // Desimal USDT (dibaca sekali; BSC USDT 0x55d398… adalah 18 —
    // terverifikasi on-chain 19 Nov 2026, bukan 6).
    try {
      usdtDecimals = Number(
        await withReadProvider((p) => usdtContract(p).decimals())
      );
    } catch {
      usdtDecimals = 18;
    }
  } catch {
    showError(t("saleLoadFailed"));
  }
  renderSaleStatus();
}

/** Fase sale, diturunkan dari state on-chain + jam lokal. */
function salePhase() {
  if (sale.graduated) return "graduated";
  if (sale.sharesSold === null) return "loading";
  const now = Math.floor(Date.now() / 1000);
  if (now < sale.saleStart) return "upcoming";
  if (sale.sharesSold >= MAX_SHARES) return "soldout";
  if (sale.saleActive) return "live";
  if (sale.refundActive) return "refund";
  if (now >= sale.refundDeadline) return "ended";
  return "live";
}

function renderSaleStatus() {
  const phase = salePhase();
  const pill = $("sale-state-pill");
  const phases = {
    loading: [t("salePhaseLoading"), "muted"],
    upcoming: [t("salePhaseUpcoming"), "warn"],
    live: [t("salePhaseLive"), "ok"],
    soldout: [t("salePhaseSoldout"), "warn"],
    graduated: [t("salePhaseGraduated"), "ok"],
    refund: [t("salePhaseRefund"), "warn"],
    ended: [t("salePhaseEnded"), "muted"],
  };
  setPill(pill, phases[phase][0], phases[phase][1]);

  const label = $("countdown-label");
  const note = $("countdown-note");
  if (phase === "upcoming") {
    label.textContent = t("countdownLabelUpcoming");
    note.textContent = t("countdownNoteUpcoming", { start: t("saleStartDate") });
  } else if (phase === "live") {
    label.textContent = t("countdownLabelLive");
    note.textContent = t("countdownNoteLive");
  } else if (phase === "refund") {
    label.textContent = t("countdownLabelRefund");
    note.textContent = t("countdownNoteRefund");
  } else if (phase === "graduated") {
    label.textContent = t("countdownLabelStatus");
    note.textContent = t("countdownNoteGraduated");
  } else if (phase === "soldout") {
    label.textContent = t("countdownLabelStatus");
    note.textContent = t("countdownNoteSoldout");
  } else if (phase === "ended") {
    label.textContent = t("countdownLabelStatus");
    note.textContent = t("countdownNoteEnded");
  }

  if (sale.sharesSold !== null) {
    $("shares-status").textContent = t("sharesStatus", {
      sold: fmtInt(sale.sharesSold),
      total: fmtInt(MAX_SHARES),
    });
    $("shares-bar").style.width = `${Math.min(
      100,
      (sale.sharesSold / MAX_SHARES) * 100
    )}%`;
  }
  if (sale.totalRaised !== null) {
    $("raised-note").textContent = t("raisedNote", {
      amount: fmtUsdt(sale.totalRaised, usdtDecimals),
    });
  }

  // Kartu jendela refund.
  if (phase === "refund") {
    $("refund-label").textContent = t("countdownLabelRefund");
    $("refund-note").textContent = t("refundNoteActive");
  } else if (sale.refundDeadline) {
    $("refund-label").textContent = t("refundLabel");
    $("refund-note").textContent = t("refundNote", {
      date: new Date(sale.refundDeadline * 1000).toLocaleString(numLocale(), {
        dateStyle: "medium",
        timeStyle: "short",
      }),
    });
  }
  tickCountdown();
}

function formatDuration(totalSeconds) {
  if (totalSeconds <= 0) return t("durationZero");
  const d = Math.floor(totalSeconds / 86400);
  const h = Math.floor((totalSeconds % 86400) / 3600);
  const m = Math.floor((totalSeconds % 3600) / 60);
  const s = totalSeconds % 60;
  const parts = [];
  if (d > 0) parts.push(t("durationDays", { d, n: d }));
  parts.push(t("durationHours", { h: String(h).padStart(2, "0") }));
  parts.push(t("durationMin", { m: String(m).padStart(2, "0") }));
  parts.push(t("durationSec", { s: String(s).padStart(2, "0") }));
  return parts.join(" ");
}

function tickCountdown() {
  const el = $("countdown");
  const refundEl = $("refund-countdown");
  const phase = salePhase();
  const now = Math.floor(Date.now() / 1000);
  if (phase === "upcoming" && sale.saleStart) {
    el.textContent = formatDuration(sale.saleStart - now);
  } else if (phase === "live" && sale.saleDeadline) {
    el.textContent = formatDuration(sale.saleDeadline - now);
  } else if (phase === "refund" && sale.refundDeadline) {
    el.textContent = formatDuration(sale.refundDeadline - now);
  } else if (phase === "graduated") {
    el.textContent = t("countdownGraduated");
  } else if (phase === "soldout") {
    el.textContent = t("countdownSoldout");
  } else if (phase === "ended") {
    el.textContent = t("salePhaseEnded");
  } else {
    el.textContent = "—";
  }
  if (phase === "refund" && sale.refundDeadline) {
    refundEl.textContent = formatDuration(sale.refundDeadline - now);
  } else if (sale.refundDeadline) {
    refundEl.textContent = new Date(
      sale.refundDeadline * 1000
    ).toLocaleDateString(numLocale(), { dateStyle: "medium" });
  } else {
    refundEl.textContent = "—";
  }
  // Render ulang bila fase berubah saat batas waktu terlewati.
  const currentPill = $("sale-state-pill").textContent;
  const expected = {
    upcoming: t("salePhaseUpcoming"),
    live: t("salePhaseLive"),
    soldout: t("salePhaseSoldout"),
    graduated: t("salePhaseGraduated"),
    refund: t("salePhaseRefund"),
    ended: t("salePhaseEnded"),
  }[phase];
  if (
    expected &&
    currentPill !== expected &&
    currentPill !== t("salePhaseLoading")
  ) {
    renderSaleStatus();
  }
}

// ---------------------------------------------------------------------------
// Listing: ambil event, rekonstruksi, verifikasi live
// ---------------------------------------------------------------------------

/** Nomor blok dari sebuah log (BscScan mengembalikan hex, RPC mengembalikan angka). */
function logBlockNumber(log) {
  if (typeof log.blockNumber === "number") return log.blockNumber;
  return parseInt(log.blockNumber, 16);
}
function logIndexNumber(log) {
  if (typeof log.logIndex === "number") return log.logIndex;
  return parseInt(log.logIndex, 16);
}

/**
 * Sumber UTAMA: BscScan API (Etherscan V2, module=logs&action=getLogs).
 * Tanpa API key tetap dicoba; Etherscan bisa menolak — pemanggil akan
 * jatuh ke fallback RPC. API mengembalikan maks 1.000 log per panggilan;
 * bila hasilnya penuh, rentang dibelah dua secara rekursif.
 */
async function fetchLogsBscScanRange(fromBlock, toBlock, depth = 0) {
  const params = new URLSearchParams({
    module: "logs",
    action: "getLogs",
    address: MARKET_ADDRESS,
    fromBlock: String(fromBlock),
    toBlock: String(toBlock),
    chainid: "56",
  });
  if (BSCSCAN_API_KEY) params.set("apikey", BSCSCAN_API_KEY);
  const res = await fetch(`${BSCSCAN_API_V2}?${params}`);
  if (!res.ok) throw new Error(`BscScan HTTP ${res.status}`);
  const json = await res.json();
  if (json.status === "1") {
    const result = json.result;
    if (result.length >= 1000 && depth < 10 && toBlock - fromBlock > 1) {
      const mid = Math.floor((fromBlock + toBlock) / 2);
      const [a, b] = await Promise.all([
        fetchLogsBscScanRange(fromBlock, mid, depth + 1),
        fetchLogsBscScanRange(mid + 1, toBlock, depth + 1),
      ]);
      return [...a, ...b];
    }
    return result;
  }
  // "No records found" bukan error — artinya belum ada event sama sekali.
  if (json.message === "No records found") return [];
  throw new Error(json.message || json.result || "BscScan gagal.");
}

async function fetchMarketLogsBscScan() {
  const latest = await withReadProvider((p) => p.getBlockNumber());
  const from = MARKET_DEPLOY_BLOCK ?? 0;
  const logs = [];
  // Dipecah per 2 juta blok agar satu panggilan tidak terlalu besar.
  const CHUNK = 2_000_000;
  for (let start = from; start <= latest; start += CHUNK) {
    const end = Math.min(start + CHUNK - 1, latest);
    const chunk = await fetchLogsBscScanRange(start, end);
    logs.push(...chunk);
  }
  return logs;
}

/**
 * Fallback: eth_getLogs langsung ke RPC publik, dipecah per 1.000 blok.
 * RPC publik gratis sering membatasi getLogs (limit exceeded / 403),
 * jadi ini hanya cadangan. Membutuhkan MARKET_DEPLOY_BLOCK terisi —
 * tanpa blok awal yang diketahui, memindai dari blok 0 tidak mungkin.
 */
async function fetchMarketLogsRpc() {
  if (MARKET_DEPLOY_BLOCK === null || MARKET_DEPLOY_BLOCK === undefined) {
    throw new Error("BLOK_DEPLOY_BELUM_DIISI");
  }
  const latest = await withReadProvider((p) => p.getBlockNumber());
  const logs = [];
  const CHUNK = 1000;
  for (let start = MARKET_DEPLOY_BLOCK; start <= latest; start += CHUNK) {
    const end = Math.min(start + CHUNK - 1, latest);
    const chunk = await withReadProvider((p) =>
      p.getLogs({ address: MARKET_ADDRESS, fromBlock: start, toBlock: end })
    );
    logs.push(...chunk);
  }
  return logs;
}

/**
 * Rekonstruksi state listing dari event, diurutkan blok lalu logIndex:
 * Listed menambah, Sold/Cancelled menghapus, PriceUpdated mengubah harga.
 * Log yang bentuknya tidak cocok dengan ABI (mis. bentuk event kontrak
 * final berbeda dari asumsi di market-config.js) dilewati dan dihitung.
 */
function reconstructListings(logs) {
  const iface = new ethers.Interface(KONG_MARKET_ABI);
  const map = new Map();
  let skipped = 0;
  const sorted = [...logs].sort(
    (a, b) =>
      logBlockNumber(a) - logBlockNumber(b) ||
      logIndexNumber(a) - logIndexNumber(b)
  );
  for (const log of sorted) {
    let parsed = null;
    try {
      parsed = iface.parseLog({ topics: log.topics, data: log.data });
    } catch {
      skipped++;
      continue;
    }
    if (!parsed) {
      skipped++;
      continue;
    }
    const tokenId = Number(parsed.args.tokenId);
    if (parsed.name === "Listed") {
      map.set(tokenId, {
        tokenId,
        seller: parsed.args.seller,
        price: parsed.args.price,
        paymentToken: parsed.args.paymentToken,
        blockNumber: logBlockNumber(log),
      });
    } else if (parsed.name === "PriceUpdated") {
      const existing = map.get(tokenId);
      if (existing) existing.price = parsed.args.newPrice;
    } else if (parsed.name === "Cancelled" || parsed.name === "Sold") {
      map.delete(tokenId);
    }
    // FeesSwept tidak memengaruhi listing — diabaikan.
  }
  if (skipped > 0) {
    console.warn(
      `[market] ${skipped} log dilewati (bentuk event tidak cocok dengan ABI di market-config.js).`
    );
  }
  return map;
}

/**
 * Verifikasi live satu listing sebelum ditampilkan sebagai bisa dibeli:
 *  - ownerOf(tokenId) == seller (pass belum diklaim/dipindah/dibakar)
 *  - approval masih berlaku (getApproved == market ATAU isApprovedForAll)
 *  - listingOf() di kontrak cocok dengan hasil rekonstruksi event
 *  - mata uang listing dikenal (USDT saja)
 * Hasil: "ok" (bisa dibeli), "stale" (basi — disembunyikan), "unknown"
 * (RPC gagal menjawab — ditampilkan tanpa tombol Beli).
 */
async function verifyListing(listing) {
  if (!isKnownCurrency(listing.paymentToken)) {
    return { status: "stale", reason: t("staleUnknownCurrency") };
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
      return { status: "stale", reason: t("staleTokenGone") };
    }
    if (owner.toLowerCase() !== listing.seller.toLowerCase()) {
      return { status: "stale", reason: t("staleNotOwner") };
    }
    if (
      approved.toLowerCase() !== MARKET_ADDRESS.toLowerCase() &&
      !approvedForAll
    ) {
      return { status: "stale", reason: t("staleApprovalRevoked") };
    }
    if (
      onChain.seller.toLowerCase() !== listing.seller.toLowerCase() ||
      onChain.price !== listing.price ||
      onChain.paymentToken.toLowerCase() !==
        listing.paymentToken.toLowerCase()
    ) {
      return { status: "stale", reason: t("staleChanged") };
    }
    return { status: "ok" };
  } catch {
    // RPC gagal — bukan bukti listing basi; tampilkan tanpa tombol Beli.
    return { status: "unknown" };
  }
}

/** Muat ulang seluruh listing: event -> rekonstruksi -> verifikasi live. */
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
  let logs;
  try {
    logs = await fetchMarketLogsBscScan();
    listingsSource = "bscscan";
  } catch (bscscanErr) {
    console.warn("[market] BscScan gagal, mencoba fallback RPC:", bscscanErr);
    try {
      logs = await fetchMarketLogsRpc();
      listingsSource = "rpc";
    } catch (rpcErr) {
      listingsLoading = false;
      listingsError = rpcErr;
      renderListings();
      return;
    }
  }
  listings = reconstructListings(logs);

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
  list.sort((a, b) => {
    const diff = priceToUsdt(a.price, a.paymentToken) - priceToUsdt(b.price, b.paymentToken);
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
    noteEl.textContent = t("marketNotDeployedNote");
    const p = document.createElement("p");
    p.className = "empty-note";
    p.textContent = t("marketNotDeployedEmpty");
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
    notes.push(t("staleHidden", { n: staleCount }));
  }
  if (listingsSource === "rpc") {
    notes.push(t("rpcFallbackNote"));
  }
  noteEl.textContent = notes.join(" ");

  if (list.length === 0) {
    const p = document.createElement("p");
    p.className = "empty-note";
    p.textContent =
      verified.length === 0 ? t("noListingsYet") : t("noFilterMatch");
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

  const claimLine = document.createElement("p");
  claimLine.className = "pass-value";
  claimLine.textContent = t("claimValue", {
    value: fmtKong(listing.claimable),
  });
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
  splitLine.textContent = t("splitLine");
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
    warn.textContent = t("listingUnverified");
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
  note.textContent = t("payUsdtNote");
  box.appendChild(note);

  const warn = document.createElement("p");
  warn.className = "muted-text";
  warn.textContent = t("maxPriceWarn");
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
    // USDT-only (market USDT-only sejak 26 Nov 2026): approve dulu bila
    // allowance ke market belum cukup.
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
    showError(t("walletReadFailed"));
  }
  await refreshMyPasses();
}

const tokenCacheKey = () => `kong:tokens:${account.toLowerCase()}`;

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

  // 2. Scan ownerOf(1..sharesSold) sampai semua pass ketemu (atau cap).
  // TokenId berurutan 1..sharesSold dan sama dengan nomor share.
  if (owned.size < balance && sale.sharesSold !== null && sale.sharesSold > 0) {
    const limit = Math.min(sale.sharesSold, PASS_SCAN_CAP);
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
            listingCurrency = "USDT";
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
    showError(t("myPassesLoadFailed"));
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
      wallet.passBalance === 0 ? t("noPassNote") : t("scanningPasses");
    const p = document.createElement("p");
    p.className = "empty-note";
    p.textContent =
      wallet.passBalance === 0 ? t("noMintPass") : t("scanningPassesChain");
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
  claimLine.textContent = t("claimValueShort", { value: fmtKong(pass.claimable) });
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
  claimA.href = "../";
  claimA.textContent = t("claimRefundLink");
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
    price: fmtPrice(pass.listingPrice, USDT_ADDRESS),
  });
  wrap.appendChild(status);

  if (!pass.approved) {
    const warn = document.createElement("p");
    warn.className = "listing-stale-note";
    warn.textContent = t("approvalStaleWarn");
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
    floor: fmtUsdt(floor),
    breakeven: fmtUsdt(breakevenRaw(pass.tier, "USDT")),
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
  for (const cur of ["USDT"]) {
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
    floorNote.textContent = t("floorNoteList", {
      tier: meta_name(pass.tier),
      floor: fmtUsdt(floor),
      breakeven: fmtUsdt(breakevenRaw(pass.tier, "USDT")),
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
        min: fmtUsdt(floor),
      })
    );
    return;
  }
  const paymentToken = USDT_ADDRESS;
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
        min: fmtUsdt(floor),
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
            price: fmtPrice(price, USDT_ADDRESS),
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
            price: fmtPrice(price, USDT_ADDRESS),
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
// Pesan error (lewat i18n.js)
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
  if (/network|fetch|timeout|failed/i.test(msg) && code !== "CALL_EXCEPTION") {
    return t("errNetwork");
  }
  return t("errGeneric");
}

// ---------------------------------------------------------------------------
// Konten statis + init
// ---------------------------------------------------------------------------

function renderStaticInfo() {
  // Banner "belum di-deploy".
  $("not-deployed-banner").hidden = MARKET_DEPLOYED;

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
    marketLine.textContent = t("marketNotDeployedLine");
  }

  // Footer: tautan kontrak.
  const links = [
    ["footer-sale", KONG_SALE_ADDRESS],
    ["footer-pass", KONG_PASS_ADDRESS],
    ["footer-usdt", USDT_ADDRESS],
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
  renderSaleStatus();
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
  $("lang-select").addEventListener("change", (e) => {
    if (!setLang(e.target.value)) return;
    applyStaticI18n();
    // Render ulang semua konten dinamis dalam bahasa baru. (Riwayat
    // tx-status / error-banner sengaja dibiarkan — itu log transaksi,
    // bukan teks antarmuka. renderSaleStatus memanggil tickCountdown
    // di akhir, jadi countdown ikut ter-render ulang.)
    updateWalletUI();
    renderStaticInfo();
    renderSaleStatus();
    renderListings();
    renderMyPasses();
    renderBuyConfirm();
  });

  wireWalletEvents();

  // Muat status sale + listing (semuanya jalan tanpa wallet),
  // lalu polling status sale.
  await refreshSaleState();
  await loadListings();
  setInterval(refreshSaleState, SALE_POLL_MS);
  setInterval(tickCountdown, 1000);

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
        renderListings();
      }
    } catch {
      // Tetap terputus; pengguna bisa menghubungkan manual.
    }
  }
}

init();
