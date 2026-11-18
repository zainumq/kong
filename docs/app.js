// $KONG mint page — vanilla JS + ethers.js v6.
//
// Reads go through public BSC RPC endpoints (with fallback). Writes go
// through the user's own wallet, and every transaction is one the user
// reviews and confirms themselves — nothing is ever auto-signed.
//
// Money flow: minting pulls USDT from the buyer (after an explicit
// approve of the exact quoted amount); claiming/refunding burns a pass
// and sends KONG/USDT back. There is no admin key anywhere in the system.

// NOTE: the KongMintPass contract has no totalSupply() and no token
// enumeration. Shares sold always comes from KongSale.sharesSold(), and a
// wallet's passes are found via an ownerOf() scan (see findOwnedPasses).

import { ethers } from "https://cdn.jsdelivr.net/npm/ethers@6.13.5/+esm";
import {
  KONG_TOKEN_ADDRESS,
  KONG_SALE_ADDRESS,
  KONG_PASS_ADDRESS,
  USDT_ADDRESS,
  AGENT_ID_ADDRESS,
  CHAIN_ID,
  CHAIN_ID_HEX,
  BSC_CHAIN_PARAMS,
  RPC_URLS,
  BSCSCAN_BASE,
  ZERO_ADDRESS,
  SALE_START_LABEL,
  MAX_SHARES,
  MAX_PER_WALLET,
  TIERS,
  KONG_SALE_ABI,
  KONG_PASS_ABI,
  ERC20_ABI,
  AGENT_ID_ABI,
  PASS_SCAN_CAP,
  SALE_POLL_MS,
} from "./config.js";

const $ = (id) => document.getElementById(id);
const shortAddress = (a) => `${a.slice(0, 6)}…${a.slice(-4)}`;
const bscscanTx = (hash) => `${BSCSCAN_BASE}/tx/${hash}`;
const bscscanAddress = (addr) => `${BSCSCAN_BASE}/address/${addr}`;
const bscscanToken = (tokenId) =>
  `${BSCSCAN_BASE}/token/${KONG_PASS_ADDRESS}?a=${tokenId}`;

const fmtKong = (value) =>
  `${Number(ethers.formatUnits(value, 18)).toLocaleString("en-US")} KONG`;
const fmtUsdt = (value, decimals = 18) =>
  `${Number(ethers.formatUnits(value, decimals)).toLocaleString("en-US", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })} USDT`;
const fmtInt = (n) => Number(n).toLocaleString("en-US");

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

let walletProvider = null; // ethers.BrowserProvider (user's wallet)
let signer = null;
let account = null; // checksummed address
let walletChainId = null;
let busy = false; // a transaction is in flight
// BSC USDT (0x55d398…) has 18 decimals (verified on-chain 19 Nov 2026).
// The live decimals() read below confirms it; 18 is the correct fallback.
let usdtDecimals = 18;

// Live sale state, refreshed from the chain every SALE_POLL_MS.
const sale = {
  sharesSold: null,
  totalRaised: null,
  graduated: null,
  saleStart: null,
  saleDeadline: null,
  refundDeadline: null,
  saleActive: null,
  refundActive: null,
  currentPrice: null, // USDT (6 dec) for the next share, null when sold out
  wiringOk: null, // sale contract points at the expected token/pass/USDT
};

// Live per-wallet state, refreshed on connect and after every transaction.
const wallet = {
  hasAgentId: null,
  minted: null, // passes minted by this wallet (cap accounting)
  passBalance: null,
  usdtBalance: null,
  usdtAllowance: null,
  kongBalance: null,
  referralEarned: null,
  referralClaimable: null,
  passes: [], // [{ tokenId, tier, claimable, paidFor }]
};

// Mint form state.
let amount = 1;
// referrerState: "empty" | "invalid" | "self" | "valid" | "no-pass"
let referrerState = "empty";
let referrerAddress = null; // checksummed address, or null
let quoteUsdt = null; // bigint (6 dec) from contract quote()
let quoteKong = 0n; // bigint (18 dec), computed locally per share
let quoteReferral = 0n; // bigint (18 dec) the referrer would earn

// Read-only providers, tried in order until one answers.
const readProviders = RPC_URLS.map((url) => new ethers.JsonRpcProvider(url, CHAIN_ID));

function saleContract(provider) {
  return new ethers.Contract(KONG_SALE_ADDRESS, KONG_SALE_ABI, provider);
}
function passContract(provider) {
  return new ethers.Contract(KONG_PASS_ADDRESS, KONG_PASS_ABI, provider);
}
function usdtContract(provider) {
  return new ethers.Contract(USDT_ADDRESS, ERC20_ABI, provider);
}
function kongContract(provider) {
  return new ethers.Contract(KONG_TOKEN_ADDRESS, ERC20_ABI, provider);
}
function agentIdContract(provider) {
  return new ethers.Contract(AGENT_ID_ADDRESS, AGENT_ID_ABI, provider);
}

/** Run `fn(provider)` against read providers in order; first success wins. */
async function withReadProvider(fn) {
  let lastError = null;
  for (const provider of readProviders) {
    try {
      return await fn(provider);
    } catch (err) {
      lastError = err;
    }
  }
  throw lastError ?? new Error("All BSC RPC endpoints failed.");
}

// ---------------------------------------------------------------------------
// Small UI helpers (all dynamic text goes through textContent, never
// innerHTML with untrusted data)
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

// ---------------------------------------------------------------------------
// Wallet connection & network
// ---------------------------------------------------------------------------

async function connectWallet() {
  if (!window.ethereum) {
    showError("No wallet found. Install MetaMask or Binance Wallet, then reload this page.");
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
    hasAgentId: null,
    minted: null,
    passBalance: null,
    usdtBalance: null,
    usdtAllowance: null,
    kongBalance: null,
    referralEarned: null,
    referralClaimable: null,
    passes: [],
  });
  clearError();
  clearTxStatus();
  updateWalletUI();
  renderAgentId();
  renderMintForm();
  renderReferral();
  renderPassLists();
}

function updateWalletUI() {
  const btn = $("connect-btn");
  const label = $("account-label");
  if (account) {
    btn.textContent = "Disconnect";
    btn.classList.remove("btn-primary");
    label.textContent = shortAddress(account);
    label.hidden = false;
  } else {
    btn.textContent = "Connect wallet";
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
    pill.textContent = "BSC · Chain 56";
    pill.className = "pill pill-ok";
    warning.hidden = true;
  } else {
    pill.textContent = `Wrong network (chain ${walletChainId})`;
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
    // 4902: chain not added to the wallet yet — ask to add it.
    if (err.code === 4902) {
      await window.ethereum.request({
        method: "wallet_addEthereumChain",
        params: [BSC_CHAIN_PARAMS],
      });
    } else {
      throw err;
    }
  }
  // The chainChanged listener refreshes state after the switch.
}

/** Make sure the wallet is on BSC before a transaction; prompts to switch. */
async function ensureBsc() {
  if (walletChainId === CHAIN_ID) return;
  await switchToBsc();
  // Re-read the chain: the listener may not have fired yet.
  const network = await walletProvider.getNetwork();
  walletChainId = Number(network.chainId);
  updateNetworkUI();
  if (walletChainId !== CHAIN_ID) {
    throw new Error("WRONG_NETWORK");
  }
}

// ---------------------------------------------------------------------------
// Tier helpers (pure — the curve constants are immutable in the contract)
// ---------------------------------------------------------------------------

function tierOfShare(shareNumber) {
  if (shareNumber <= TIERS[0].lastShare) return 1;
  if (shareNumber <= TIERS[1].lastShare) return 2;
  return 3;
}

function tierMeta(tier) {
  return TIERS[tier - 1];
}

/** Sold counts per tier from the total shares sold. */
function tierSoldCounts(sharesSold) {
  return TIERS.map((t) => {
    const sold = Math.min(Math.max(sharesSold - t.firstShare + 1, 0), t.lastShare - t.firstShare + 1);
    return { ...t, sold, total: t.lastShare - t.firstShare + 1 };
  });
}

/**
 * Local quote for `count` shares starting at share `first`: total claimable
 * KONG and total referral reward. Exact — the per-share amounts are the
 * contract's own constants (tokensOfShare / referralOfShare are pure
 * functions of the share number). The USDT total always comes from the
 * contract's quote() view instead (see updateQuote).
 */
function localQuote(first, count) {
  let kong = 0n;
  let referral = 0n;
  for (let i = 0; i < count; i++) {
    const t = tierMeta(tierOfShare(first + i));
    kong += BigInt(t.tokensPerShare) * 10n ** 18n;
    referral += BigInt(t.referralPerShare) * 10n ** 18n;
  }
  return { kong, referral };
}

// ---------------------------------------------------------------------------
// Sale state (public reads — work without a wallet)
// ---------------------------------------------------------------------------

async function refreshSaleState() {
  try {
    const c = await withReadProvider(async (p) => {
      const s = saleContract(p);
      const [sharesSold, totalRaised, graduated, saleStart, saleDeadline, refundDeadline, saleActive, refundActive] =
        await Promise.all([
          s.sharesSold(),
          s.totalRaised(),
          s.graduated(),
          s.saleStart(),
          s.saleDeadline(),
          s.refundDeadline(),
          s.saleActive(),
          s.refundActive(),
        ]);
      return { sharesSold, totalRaised, graduated, saleStart, saleDeadline, refundDeadline, saleActive, refundActive };
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

    // Current price for the next share (null when sold out).
    if (sale.sharesSold < MAX_SHARES) {
      sale.currentPrice = await withReadProvider((p) =>
        saleContract(p).priceOfShare(sale.sharesSold + 1)
      );
    } else {
      sale.currentPrice = null;
    }

    // One-time wiring sanity check: the sale must point at the deployed
    // token / pass / USDT / Agent ID contracts. If not, something is very
    // wrong — say so loudly and block writes.
    if (sale.wiringOk === null) {
      try {
        const w = await withReadProvider(async (p) => {
          const s = saleContract(p);
          const [pass, kong, usdt, agentId] = await Promise.all([
            s.pass(),
            s.kong(),
            s.usdt(),
            s.agentId(),
          ]);
          return { pass, kong, usdt, agentId };
        });
        sale.wiringOk =
          w.pass.toLowerCase() === KONG_PASS_ADDRESS.toLowerCase() &&
          w.kong.toLowerCase() === KONG_TOKEN_ADDRESS.toLowerCase() &&
          w.usdt.toLowerCase() === USDT_ADDRESS.toLowerCase() &&
          w.agentId.toLowerCase() === AGENT_ID_ADDRESS.toLowerCase();
        if (!sale.wiringOk) {
          showError(
            "Warning: this sale contract points at different token/pass contracts than this page expects. Minting and claims are disabled."
          );
        }
      } catch {
        // A failure here means RPC trouble, surfaced by the other reads.
        // Leave wiringOk null so it is retried on the next poll.
      }
    }

    // USDT decimals (read once; BSC USDT 0x55d398… is 18 — verified
    // on-chain 19 Nov 2026, despite the v2 contract assuming 6).
    try {
      usdtDecimals = Number(await withReadProvider((p) => usdtContract(p).decimals()));
    } catch {
      usdtDecimals = 18;
    }
  } catch {
    showError("Could not reach BNB Chain to load the sale status. Check your connection — retrying automatically.");
  }
  renderSaleStatus();
  renderTierCards();
  renderMintForm();
  renderPassLists();
  renderReferral();
}

/** Which phase the sale is in, derived from on-chain state + local clock. */
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
  const label = $("countdown-label");
  const note = $("countdown-note");

  const phases = {
    loading: ["Loading…", "pill-muted"],
    upcoming: ["Coming soon", "pill-warn"],
    live: ["Live", "pill-ok"],
    soldout: ["Sold out — graduation pending", "pill-warn"],
    graduated: ["Graduated", "pill-ok"],
    refund: ["Refund window open", "pill-warn"],
    ended: ["Ended", "pill-muted"],
  };
  setPill(pill, phases[phase][0], phases[phase][1]);

  if (phase === "upcoming") {
    label.textContent = "Sale opens in";
    note.textContent = `Sale opens ${SALE_START_LABEL}.`;
  } else if (phase === "live") {
    label.textContent = "Sale ends in";
    note.textContent = "30-day sale — unsold shares mean a full refund for everyone.";
  } else if (phase === "refund") {
    label.textContent = "Refund window closes in";
    note.textContent = "Burn your passes for a 100% USDT refund before the window closes.";
  } else if (phase === "graduated") {
    label.textContent = "Sale status";
    note.textContent = "The pool is live — passes can be claimed for $KONG below.";
  } else if (phase === "soldout") {
    label.textContent = "Sale status";
    note.textContent = "All shares sold — graduation opens the pool and claims.";
  } else if (phase === "ended") {
    label.textContent = "Sale status";
    note.textContent = "The sale ended without selling out and the refund window has closed.";
  }

  if (sale.sharesSold !== null) {
    $("shares-status").textContent = `${fmtInt(sale.sharesSold)} / ${fmtInt(MAX_SHARES)} shares`;
    $("shares-bar").style.width = `${Math.min(100, (sale.sharesSold / MAX_SHARES) * 100)}%`;
  }
  if (sale.totalRaised !== null) {
    $("raised-note").textContent = `Total raised: ${fmtUsdt(sale.totalRaised, usdtDecimals)} (held in escrow until graduation)`;
  }
  if (sale.sharesSold !== null) {
    if (sale.sharesSold >= MAX_SHARES) {
      $("tier-status").textContent = "Sold out";
      $("tier-note").textContent = "All 10,000 shares are sold.";
    } else {
      const nextTier = tierMeta(tierOfShare(sale.sharesSold + 1));
      $("tier-status").textContent = nextTier.name;
      $("tier-note").textContent = `Price per share: ${nextTier.priceUsdt} USDT · claims ${fmtInt(nextTier.tokensPerShare)} KONG`;
    }
  }

  $("graduate-box").hidden = phase !== "soldout";
  $("graduated-box").hidden = phase !== "graduated";
  $("refund-window-box").hidden = phase !== "refund";
  $("claim-section").hidden = phase !== "graduated";
  $("refund-section").hidden = phase !== "refund";
  if (phase === "refund" && sale.refundDeadline) {
    $("refund-deadline-label").textContent = new Date(sale.refundDeadline * 1000).toLocaleString("en-US", {
      dateStyle: "medium",
      timeStyle: "short",
    });
  }
  tickCountdown();
}

function formatDuration(totalSeconds) {
  if (totalSeconds <= 0) return "0s";
  const d = Math.floor(totalSeconds / 86400);
  const h = Math.floor((totalSeconds % 86400) / 3600);
  const m = Math.floor((totalSeconds % 3600) / 60);
  const s = totalSeconds % 60;
  const parts = [];
  if (d > 0) parts.push(`${d}d`);
  parts.push(`${String(h).padStart(2, "0")}h`);
  parts.push(`${String(m).padStart(2, "0")}m`);
  parts.push(`${String(s).padStart(2, "0")}s`);
  return parts.join(" ");
}

function tickCountdown() {
  const el = $("countdown");
  const phase = salePhase();
  const now = Math.floor(Date.now() / 1000);
  if (phase === "upcoming" && sale.saleStart) {
    el.textContent = formatDuration(sale.saleStart - now);
  } else if (phase === "live" && sale.saleDeadline) {
    el.textContent = formatDuration(sale.saleDeadline - now);
  } else if (phase === "refund" && sale.refundDeadline) {
    el.textContent = formatDuration(sale.refundDeadline - now);
  } else if (phase === "graduated") {
    el.textContent = "Graduated ✓";
  } else if (phase === "soldout") {
    el.textContent = "Sold out";
  } else if (phase === "ended") {
    el.textContent = "Ended";
  } else {
    el.textContent = "—";
  }
  // Re-render the phase when a boundary passes (cheap: once a second the
  // phase string is recomputed; renderSaleStatus only re-renders text).
  const currentPill = $("sale-state-pill").textContent;
  const expected = {
    upcoming: "Coming soon",
    live: "Live",
    soldout: "Sold out — graduation pending",
    graduated: "Graduated",
    refund: "Refund window open",
    ended: "Ended",
  }[phase];
  if (expected && currentPill !== expected && currentPill !== "Loading…") {
    renderSaleStatus();
    renderMintForm();
  }
}

// ---------------------------------------------------------------------------
// Tier cards
// ---------------------------------------------------------------------------

function renderTierCards() {
  const list = $("tier-list");
  list.replaceChildren();
  const counts = sale.sharesSold === null
    ? TIERS.map((t) => ({ ...t, sold: null, total: t.lastShare - t.firstShare + 1 }))
    : tierSoldCounts(sale.sharesSold);

  for (const t of counts) {
    const card = document.createElement("article");
    card.className = "tier-card";
    card.style.setProperty("--tier-color", t.color);

    const img = document.createElement("img");
    img.src = t.image;
    img.alt = `Kong Mint Pass — ${t.name} artwork`;
    img.loading = "lazy";
    card.appendChild(img);

    const body = document.createElement("div");
    body.className = "tier-body";

    const title = document.createElement("h3");
    title.textContent = t.name;
    body.appendChild(title);

    const range = document.createElement("p");
    range.className = "tier-range";
    range.textContent = t.range;
    body.appendChild(range);

    const price = document.createElement("p");
    price.className = "tier-price";
    price.textContent = `${t.priceUsdt} USDT / share`;
    body.appendChild(price);

    const claim = document.createElement("p");
    claim.className = "tier-claim";
    claim.textContent = `Claims ${fmtInt(t.tokensPerShare)} KONG`;
    body.appendChild(claim);

    const referral = document.createElement("p");
    referral.className = "tier-referral";
    referral.textContent = `Referrer earns ${fmtInt(t.referralPerShare)} KONG per share`;
    body.appendChild(referral);

    const sold = document.createElement("p");
    sold.className = "tier-sold";
    if (t.sold === null) {
      sold.textContent = `${fmtInt(t.total)} shares`;
    } else if (t.sold >= t.total) {
      sold.textContent = "Sold out";
      sold.classList.add("tier-sold-out");
    } else {
      sold.textContent = `${fmtInt(t.sold)} / ${fmtInt(t.total)} sold`;
    }
    body.appendChild(sold);

    const bar = document.createElement("div");
    bar.className = "progress";
    bar.setAttribute("aria-hidden", "true");
    const fill = document.createElement("div");
    fill.className = "progress-bar tier-bar";
    fill.style.width = t.sold === null ? "0%" : `${Math.min(100, (t.sold / t.total) * 100)}%`;
    bar.appendChild(fill);
    body.appendChild(bar);

    card.appendChild(body);
    list.appendChild(card);
  }
}

// ---------------------------------------------------------------------------
// Wallet state
// ---------------------------------------------------------------------------

async function refreshWallet() {
  if (!account) return;
  clearError();

  try {
    const bal = await withReadProvider((p) => agentIdContract(p).balanceOf(account));
    wallet.hasAgentId = bal > 0n;
  } catch {
    showError("Could not reach BNB Chain to check your Agent ID. Check your connection and try again.");
    wallet.hasAgentId = null;
  }
  renderAgentId();

  try {
    const [minted, passBalance, usdtBalance, usdtAllowance, kongBalance, referralEarned, referralClaimable] =
      await Promise.all([
        withReadProvider((p) => saleContract(p).mintedByWallet(account)),
        withReadProvider((p) => passContract(p).balanceOf(account)),
        withReadProvider((p) => usdtContract(p).balanceOf(account)),
        withReadProvider((p) => usdtContract(p).allowance(account, KONG_SALE_ADDRESS)),
        withReadProvider((p) => kongContract(p).balanceOf(account)),
        withReadProvider((p) => saleContract(p).referralEarned(account)),
        withReadProvider((p) => saleContract(p).referralClaimable(account)),
      ]);
    wallet.minted = Number(minted);
    wallet.passBalance = Number(passBalance);
    wallet.usdtBalance = usdtBalance;
    wallet.usdtAllowance = usdtAllowance;
    wallet.kongBalance = kongBalance;
    wallet.referralEarned = referralEarned;
    wallet.referralClaimable = referralClaimable;
  } catch {
    showError("Could not read your wallet status from BNB Chain. Check your connection and try again.");
  }

  // Re-validate the referrer against the newly connected account
  // (a ?ref= link pointing at your own address is a self-referral).
  await validateReferrer();
  await updateQuote();
  renderMintForm();
  renderReferral();
  await refreshPasses();
}

function renderAgentId() {
  const el = $("agent-id-pill");
  if (!account) {
    setPill(el, "Connect your wallet to check your Agent ID.", "muted");
    $("mint-no-agent-id").hidden = true;
    return;
  }
  if (wallet.hasAgentId === null) {
    setPill(el, "Agent ID status unknown — RPC unreachable.", "warn");
    $("mint-no-agent-id").hidden = true;
    return;
  }
  if (wallet.hasAgentId) {
    setPill(el, "✓ Agent ID held", "ok");
    $("mint-no-agent-id").hidden = true;
  } else {
    setPill(el, "✗ No Agent ID in this wallet", "bad");
    $("mint-no-agent-id").hidden = false;
  }
}

// ---------------------------------------------------------------------------
// Owned passes (localStorage cache + ownerOf scan fallback)
// ---------------------------------------------------------------------------

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
    // Private mode etc. — the ownerOf scan is the fallback.
  }
}

function cacheTokenIdsFromReceipt(receipt) {
  const iface = new ethers.Interface(KONG_SALE_ABI);
  const found = [];
  for (const log of receipt.logs) {
    if (log.address.toLowerCase() !== KONG_SALE_ADDRESS.toLowerCase()) continue;
    let parsed = null;
    try {
      parsed = iface.parseLog(log);
    } catch {
      continue;
    }
    if (!parsed || parsed.name !== "PassMinted") continue;
    if (parsed.args.buyer.toLowerCase() !== account.toLowerCase()) continue;
    found.push(parsed.args.tokenId.toString());
  }
  if (found.length > 0) {
    const merged = [...new Set([...loadCachedTokenIds(), ...found])];
    saveCachedTokenIds(merged);
  }
  return found;
}

async function findOwnedPasses() {
  const balance = wallet.passBalance ?? 0;
  if (balance === 0) {
    saveCachedTokenIds([]);
    return [];
  }

  // 1. Verify the cached tokenIds still belong to this wallet.
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

  // 2. Scan ownerOf(1..sharesSold) until every pass is found (or the cap).
  // TokenIds are sequential 1..sharesSold and equal the share number.
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

  // 3. Per-pass details: tier, claimable KONG, USDT paid (refund amount).
  const details = await Promise.all(
    ids.map(async (id) => {
      const [tier, claimable, paidFor] = await Promise.all([
        withReadProvider((p) => passContract(p).tierOf(id)),
        withReadProvider((p) => passContract(p).claimableOf(id)),
        withReadProvider((p) => saleContract(p).paidFor(id)),
      ]);
      return { tokenId: id, tier: Number(tier), claimable, paidFor };
    })
  );
  return details;
}

async function refreshPasses() {
  if (!account) {
    wallet.passes = [];
    renderPassLists();
    return;
  }
  try {
    wallet.passes = await findOwnedPasses();
  } catch {
    showError("Could not load your passes from BNB Chain. Check your connection and try again.");
    wallet.passes = [];
  }
  renderPassLists();
  renderReferral(); // the hold-a-pass note depends on passBalance
}

function renderPassLists() {
  const phase = salePhase();
  renderPassList($("pass-list"), "claim");
  renderPassList($("refund-list"), "refund");
  $("kong-balance").textContent =
    wallet.kongBalance === null ? "—" : fmtKong(wallet.kongBalance);

  const claimAllBtn = $("claim-all-btn");
  claimAllBtn.disabled =
    busy || !account || wallet.passes.length === 0 || phase !== "graduated";
  claimAllBtn.textContent =
    wallet.passes.length > 0
      ? `Claim all (${wallet.passes.length})`
      : "Claim all";

  const refundAllBtn = $("refund-all-btn");
  refundAllBtn.disabled =
    busy || !account || wallet.passes.length === 0 || phase !== "refund";
  refundAllBtn.textContent =
    wallet.passes.length > 0
      ? `Refund all (${wallet.passes.length})`
      : "Refund all";
}

function renderPassList(listEl, mode) {
  listEl.replaceChildren();
  if (!account) {
    const p = document.createElement("p");
    p.className = "empty-note";
    p.textContent = "Connect your wallet to see your passes.";
    listEl.appendChild(p);
    return;
  }
  if (wallet.passes.length === 0) {
    const p = document.createElement("p");
    p.className = "empty-note";
    p.textContent =
      mode === "claim"
        ? "You hold no Mint Passes."
        : "You hold no Mint Passes to refund.";
    listEl.appendChild(p);
    return;
  }
  for (const pass of wallet.passes) {
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
    const valueLine = document.createElement("p");
    valueLine.className = "pass-value";
    valueLine.textContent =
      mode === "claim"
        ? `Claims ${fmtKong(pass.claimable)}`
        : `Refunds ${fmtUsdt(pass.paidFor, usdtDecimals)}`;
    body.appendChild(valueLine);

    const link = document.createElement("p");
    const a = document.createElement("a");
    a.href = bscscanToken(pass.tokenId);
    a.target = "_blank";
    a.rel = "noopener";
    a.textContent = "View on BscScan";
    link.appendChild(a);
    body.appendChild(link);

    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "btn btn-primary btn-small";
    btn.textContent = mode === "claim" ? "Claim" : "Refund";
    btn.disabled = busy;
    btn.addEventListener("click", () =>
      mode === "claim" ? claimPasses([pass.tokenId]) : refundPasses([pass.tokenId])
    );
    body.appendChild(btn);

    card.appendChild(body);
    listEl.appendChild(card);
  }
}

// ---------------------------------------------------------------------------
// Referrer input + validation
// ---------------------------------------------------------------------------

function readRefFromUrl() {
  try {
    const ref = new URLSearchParams(window.location.search).get("ref");
    if (ref && ethers.isAddress(ref)) return ethers.getAddress(ref);
  } catch {
    // Ignore malformed URLs.
  }
  return null;
}

let referrerDebounce = null;

function onReferrerInput() {
  clearTimeout(referrerDebounce);
  referrerDebounce = setTimeout(() => {
    validateReferrer().then(() => {
      updateQuote().then(renderMintForm);
    });
  }, 400);
}

async function validateReferrer() {
  const raw = $("referrer-input").value.trim();
  const note = $("referrer-note");
  referrerAddress = null;

  if (raw === "") {
    referrerState = "empty";
    note.hidden = true;
    return;
  }
  if (!ethers.isAddress(raw)) {
    referrerState = "invalid";
    note.textContent = "That is not a valid address. Fix it or clear the field — minting is blocked until then.";
    note.className = "referrer-note note-bad";
    note.hidden = false;
    return;
  }
  const addr = ethers.getAddress(raw);
  if (account && addr.toLowerCase() === account.toLowerCase()) {
    referrerState = "self";
    note.textContent = "You cannot refer yourself — the contract rejects self-referrals. Clear the field to mint without a referrer.";
    note.className = "referrer-note note-bad";
    note.hidden = false;
    return;
  }
  // The contract only rewards a referrer who holds at least one pass at
  // mint time; an invalid referrer is silently ignored (no reward, mint
  // still succeeds). Warn the buyer instead of failing silently.
  try {
    const bal = await withReadProvider((p) => passContract(p).balanceOf(addr));
    if (bal > 0n) {
      referrerState = "valid";
      referrerAddress = addr;
      note.textContent = "✓ This referrer holds a Mint Pass — they earn 3% of your claimable $KONG.";
      note.className = "referrer-note note-ok";
    } else {
      referrerState = "no-pass";
      referrerAddress = addr;
      note.textContent =
        "This address holds no Mint Pass yet, so no referral reward will accrue — your mint will still succeed. Double-check the address, or clear it.";
      note.className = "referrer-note note-warn";
    }
  } catch {
    // RPC trouble: do not block the mint — the contract itself ignores an
    // invalid referrer, so the worst case is a missed reward, not a loss.
    referrerState = "no-pass";
    referrerAddress = addr;
    note.textContent =
      "Could not verify this referrer on-chain (RPC unreachable). If they hold no Mint Pass, no reward accrues — your mint will still succeed.";
    note.className = "referrer-note note-warn";
  }
  note.hidden = false;
}

// ---------------------------------------------------------------------------
// Mint form: amount, quote, allowance, buttons
// ---------------------------------------------------------------------------

function maxMintable() {
  if (sale.sharesSold === null) return MAX_PER_WALLET;
  const remainingShares = MAX_SHARES - sale.sharesSold;
  const remainingCap =
    wallet.minted === null ? MAX_PER_WALLET : MAX_PER_WALLET - wallet.minted;
  return Math.max(0, Math.min(remainingShares, remainingCap));
}

function clampAmount() {
  const max = maxMintable();
  if (amount > max) amount = Math.max(1, max);
  if (amount < 1) amount = 1;
  $("amount-display").textContent = String(amount);
}

async function updateQuote() {
  quoteUsdt = null;
  quoteKong = 0n;
  quoteReferral = 0n;
  if (sale.sharesSold === null) return;
  if (amount < 1 || sale.sharesSold + amount > MAX_SHARES) return;
  try {
    quoteUsdt = await withReadProvider((p) => saleContract(p).quote(amount));
  } catch {
    quoteUsdt = null;
  }
  const local = localQuote(sale.sharesSold + 1, amount);
  quoteKong = local.kong;
  quoteReferral = referrerState === "valid" ? local.referral : 0n;
}

/** The single reason minting is currently blocked, or null if it can proceed. */
function mintBlockReason() {
  if (sale.wiringOk === false) return "Contract configuration mismatch — see the warning above.";
  if (!account) return "Connect your wallet to mint.";
  if (walletChainId !== CHAIN_ID) return "Switch your wallet to BNB Smart Chain (chain 56) to mint.";
  const phase = salePhase();
  if (phase === "upcoming") return `The sale opens ${SALE_START_LABEL}.`;
  if (phase === "soldout" || phase === "graduated") return "The sale is sold out — minting is closed.";
  if (phase === "refund" || phase === "ended") return "The sale has ended — minting is closed.";
  if (phase === "loading") return "Loading the sale status…";
  if (wallet.hasAgentId === false) return "This wallet holds no Agent ID — minting would fail.";
  if (wallet.hasAgentId === null) return "Checking your Agent ID…";
  if (maxMintable() <= 0) {
    return wallet.minted >= MAX_PER_WALLET
      ? `You already minted the maximum of ${MAX_PER_WALLET} passes with this wallet.`
      : "No shares left to mint.";
  }
  if (referrerState === "invalid") return "Fix or clear the referrer address to mint.";
  if (referrerState === "self") return "You cannot refer yourself — clear the referrer field to mint.";
  if (quoteUsdt === null) return "Could not load the price — check your connection.";
  if (wallet.usdtBalance !== null && wallet.usdtBalance < quoteUsdt) {
    return `Not enough USDT — you need ${fmtUsdt(quoteUsdt, usdtDecimals)} and hold ${fmtUsdt(wallet.usdtBalance, usdtDecimals)}.`;
  }
  return null;
}

function renderMintForm() {
  const phase = salePhase();
  $("mint-not-started").hidden = phase !== "upcoming";
  $("mint-cap-note").hidden = true;
  if (account && wallet.minted !== null && wallet.minted > 0) {
    const note = $("mint-cap-note");
    const left = MAX_PER_WALLET - wallet.minted;
    note.textContent =
      left > 0
        ? `You already minted ${wallet.minted} of ${MAX_PER_WALLET} passes with this wallet — you can mint ${left} more.`
        : `You already minted the maximum of ${MAX_PER_WALLET} passes with this wallet.`;
    note.hidden = false;
  }

  clampAmount();
  const max = maxMintable();
  $("amount-minus").disabled = busy || amount <= 1;
  $("amount-plus").disabled = busy || amount >= max;
  $("amount-hint").textContent =
    wallet.minted === null
      ? `Max ${MAX_PER_WALLET} per wallet.`
      : `Max ${MAX_PER_WALLET} per wallet · you minted ${wallet.minted} · ${max} left for you.`;

  // Quote box.
  $("quote-usdt").textContent =
    quoteUsdt === null ? "—" : fmtUsdt(quoteUsdt, usdtDecimals);
  $("quote-kong").textContent = quoteKong > 0n ? fmtKong(quoteKong) : "—";
  $("quote-referral-row").hidden = referrerState !== "valid" || quoteReferral === 0n;
  if (referrerState === "valid") {
    $("quote-referral").textContent = fmtKong(quoteReferral);
  }
  $("usdt-balance").textContent =
    wallet.usdtBalance === null ? "—" : fmtUsdt(wallet.usdtBalance, usdtDecimals);
  $("usdt-allowance").textContent =
    wallet.usdtAllowance === null ? "—" : fmtUsdt(wallet.usdtAllowance, usdtDecimals);

  // Buttons.
  const reason = mintBlockReason();
  const needsApproval =
    reason === null &&
    quoteUsdt !== null &&
    wallet.usdtAllowance !== null &&
    wallet.usdtAllowance < quoteUsdt;
  const approveBtn = $("approve-btn");
  const mintBtn = $("mint-btn");
  approveBtn.hidden = !needsApproval;
  approveBtn.disabled = busy || !needsApproval;
  approveBtn.textContent = `Approve ${quoteUsdt === null ? "USDT" : fmtUsdt(quoteUsdt, usdtDecimals)}`;
  mintBtn.disabled = busy || reason !== null || needsApproval;
  mintBtn.textContent =
    amount > 1 ? `Mint ${amount} passes` : "Mint 1 pass";
  $("mint-hint").textContent = needsApproval
    ? "Approve the exact USDT amount first, then mint. The approval only covers this purchase."
    : reason ?? "Ready to mint — you will confirm the transaction in your wallet.";
}

// ---------------------------------------------------------------------------
// Referral panel
// ---------------------------------------------------------------------------

function renderReferral() {
  const linkInput = $("referral-link");
  const copyBtn = $("copy-link-btn");
  if (!account) {
    linkInput.value = "Connect your wallet to get your link.";
    copyBtn.disabled = true;
  } else {
    const url = new URL(window.location.href);
    url.hash = "";
    url.searchParams.set("ref", account);
    linkInput.value = url.toString();
    copyBtn.disabled = false;
  }

  const holdNote = $("referral-hold-note");
  if (!account) {
    holdNote.textContent = "You need to hold at least one Mint Pass for referrals to earn rewards.";
  } else if (wallet.passBalance === null) {
    holdNote.textContent = "Checking whether you hold a Mint Pass…";
  } else if (wallet.passBalance > 0) {
    holdNote.textContent = `✓ You hold ${wallet.passBalance} Mint Pass${wallet.passBalance > 1 ? "es" : ""} — your link earns rewards.`;
  } else {
    holdNote.textContent = "You hold no Mint Pass yet — mint one first, or your referrals earn nothing.";
  }

  $("referral-earned").textContent =
    wallet.referralEarned === null ? "—" : fmtKong(wallet.referralEarned);
  $("referral-claimable").textContent =
    wallet.referralClaimable === null ? "—" : fmtKong(wallet.referralClaimable);

  const phase = salePhase();
  const claimBtn = $("claim-referral-btn");
  const canClaim =
    !!account &&
    phase === "graduated" &&
    wallet.referralClaimable !== null &&
    wallet.referralClaimable > 0n;
  claimBtn.disabled = busy || !canClaim;
  $("referral-hint").textContent =
    phase !== "graduated"
      ? "Referral rewards can be claimed after graduation."
      : wallet.referralClaimable > 0n
        ? "Your referral rewards are ready to claim."
        : "No referral rewards to claim.";
}

async function copyReferralLink() {
  const input = $("referral-link");
  const btn = $("copy-link-btn");
  try {
    await navigator.clipboard.writeText(input.value);
  } catch {
    input.select();
    document.execCommand("copy");
  }
  const original = btn.textContent;
  btn.textContent = "Copied ✓";
  setTimeout(() => {
    btn.textContent = original;
  }, 2000);
}

// ---------------------------------------------------------------------------
// Transactions (each one is user-confirmed in their wallet)
// ---------------------------------------------------------------------------

function writeSale() {
  return new ethers.Contract(KONG_SALE_ADDRESS, KONG_SALE_ABI, signer);
}
function writeUsdt() {
  return new ethers.Contract(USDT_ADDRESS, ERC20_ABI, signer);
}

function setBusy(value) {
  busy = value;
  renderMintForm();
  renderPassLists();
  renderReferral();
  $("graduate-btn").disabled = busy;
}

async function approveUsdt() {
  if (busy || !account || quoteUsdt === null) return;
  setBusy(true);
  clearTxStatus();
  try {
    await ensureBsc();
    const write = writeUsdt();
    // Re-read the allowance right before approving — the on-page value
    // may be stale.
    const allowance = await withReadProvider((p) =>
      usdtContract(p).allowance(account, KONG_SALE_ADDRESS)
    );
    if (allowance >= quoteUsdt) {
      wallet.usdtAllowance = allowance;
      setTxStatus([[{ text: "USDT is already approved for this amount — you can mint now." }]]);
      return;
    }
    const tx = await write.approve(KONG_SALE_ADDRESS, quoteUsdt);
    setTxStatus([
      [{ text: `Approving ${fmtUsdt(quoteUsdt, usdtDecimals)} for the sale contract… waiting for confirmation. ` }],
      [{ text: "Transaction: " }, { text: shortAddress(tx.hash), href: bscscanTx(tx.hash) }],
    ]);
    await tx.wait(1);
    wallet.usdtAllowance = await withReadProvider((p) =>
      usdtContract(p).allowance(account, KONG_SALE_ADDRESS)
    );
    setTxStatus([
      [{ text: `✓ Approved ${fmtUsdt(quoteUsdt, usdtDecimals)}. You can mint now. ` }],
      [{ text: "Transaction: " }, { text: shortAddress(tx.hash), href: bscscanTx(tx.hash) }],
    ]);
  } catch (err) {
    setTxStatus([[{ text: `✗ Approval failed: ${friendlyError(err)}` }]]);
  } finally {
    setBusy(false);
    renderMintForm();
  }
}

async function mintPasses() {
  if (busy || !account) return;
  setBusy(true);
  clearTxStatus();
  try {
    await ensureBsc();
    const write = writeSale();
    const referrer = referrerState === "valid" || referrerState === "no-pass"
      ? referrerAddress
      : ZERO_ADDRESS;
    // Fresh checks right before sending — the on-page state may be stale,
    // and a reverted mint still costs gas.
    const freshQuote = await withReadProvider((p) => saleContract(p).quote(amount));
    const [allowance, usdtBalance] = await Promise.all([
      withReadProvider((p) => usdtContract(p).allowance(account, KONG_SALE_ADDRESS)),
      withReadProvider((p) => usdtContract(p).balanceOf(account)),
    ]);
    if (usdtBalance < freshQuote) throw new Error("INSUFFICIENT_USDT");
    if (allowance < freshQuote) throw new Error("NEEDS_APPROVAL");
    // Dry run against the wallet's own node: catches a revert (no Agent
    // ID, cap exceeded, sale ended, self-referral) before any gas is spent.
    await write.mintPass.staticCall(amount, referrer);
    const tx = await write.mintPass(amount, referrer);
    setTxStatus([
      [{ text: `Minting ${amount} pass${amount > 1 ? "es" : ""}… waiting for confirmation. ` }],
      [{ text: "Transaction: " }, { text: shortAddress(tx.hash), href: bscscanTx(tx.hash) }],
    ]);
    const receipt = await tx.wait(1);
    const mintedIds = cacheTokenIdsFromReceipt(receipt);
    setTxStatus([
      [{ text: `✓ Minted ${amount} pass${amount > 1 ? "es" : ""}${mintedIds.length > 0 ? ` (#${mintedIds.join(", #")})` : ""}. ` }],
      [{ text: "Transaction: " }, { text: shortAddress(tx.hash), href: bscscanTx(tx.hash) }],
    ]);
    await refreshSaleState();
    await refreshWallet();
  } catch (err) {
    setTxStatus([[{ text: `✗ Mint failed: ${friendlyError(err)}` }]]);
  } finally {
    setBusy(false);
  }
}

async function graduateSale() {
  if (busy || !account) return;
  setBusy(true);
  clearTxStatus();
  try {
    await ensureBsc();
    const write = writeSale();
    await write.graduate.staticCall();
    const tx = await write.graduate();
    setTxStatus([
      [{ text: "Graduating the sale — opening the pool and claims… waiting for confirmation. " }],
      [{ text: "Transaction: " }, { text: shortAddress(tx.hash), href: bscscanTx(tx.hash) }],
    ]);
    await tx.wait(1);
    setTxStatus([
      [{ text: "✓ Sale graduated — the pool is live and claims are open. " }],
      [{ text: "Transaction: " }, { text: shortAddress(tx.hash), href: bscscanTx(tx.hash) }],
    ]);
    await refreshSaleState();
    await refreshWallet();
  } catch (err) {
    setTxStatus([[{ text: `✗ Graduation failed: ${friendlyError(err)}` }]]);
  } finally {
    setBusy(false);
  }
}

async function claimPasses(tokenIds) {
  if (busy || !account || tokenIds.length === 0) return;
  setBusy(true);
  clearTxStatus();
  try {
    await ensureBsc();
    const write = writeSale();
    const tx =
      tokenIds.length === 1
        ? await write.claim(tokenIds[0])
        : await write.claimMany(tokenIds);
    setTxStatus([
      [{ text: `Claiming $KONG for ${tokenIds.length} pass${tokenIds.length > 1 ? "es" : ""}… waiting for confirmation. ` }],
      [{ text: "Transaction: " }, { text: shortAddress(tx.hash), href: bscscanTx(tx.hash) }],
    ]);
    await tx.wait(1);
    setTxStatus([
      [{ text: `✓ Claimed $KONG for ${tokenIds.length} pass${tokenIds.length > 1 ? "es" : ""}. The pass${tokenIds.length > 1 ? "es were" : " was"} burned. ` }],
      [{ text: "Transaction: " }, { text: shortAddress(tx.hash), href: bscscanTx(tx.hash) }],
    ]);
    await refreshSaleState();
    await refreshWallet();
  } catch (err) {
    setTxStatus([[{ text: `✗ Claim failed: ${friendlyError(err)}` }]]);
  } finally {
    setBusy(false);
  }
}

async function claimReferralRewards() {
  if (busy || !account) return;
  setBusy(true);
  clearTxStatus();
  try {
    await ensureBsc();
    const write = writeSale();
    await write.claimReferral.staticCall();
    const tx = await write.claimReferral();
    setTxStatus([
      [{ text: "Claiming your referral rewards… waiting for confirmation. " }],
      [{ text: "Transaction: " }, { text: shortAddress(tx.hash), href: bscscanTx(tx.hash) }],
    ]);
    await tx.wait(1);
    setTxStatus([
      [{ text: "✓ Referral rewards claimed. " }],
      [{ text: "Transaction: " }, { text: shortAddress(tx.hash), href: bscscanTx(tx.hash) }],
    ]);
    await refreshWallet();
  } catch (err) {
    setTxStatus([[{ text: `✗ Referral claim failed: ${friendlyError(err)}` }]]);
  } finally {
    setBusy(false);
  }
}

async function refundPasses(tokenIds) {
  if (busy || !account || tokenIds.length === 0) return;
  setBusy(true);
  clearTxStatus();
  try {
    await ensureBsc();
    const write = writeSale();
    const tx =
      tokenIds.length === 1
        ? await write.refund(tokenIds[0])
        : await write.refundMany(tokenIds);
    setTxStatus([
      [{ text: `Refunding ${tokenIds.length} pass${tokenIds.length > 1 ? "es" : ""} for 100% of the USDT paid… waiting for confirmation. ` }],
      [{ text: "Transaction: " }, { text: shortAddress(tx.hash), href: bscscanTx(tx.hash) }],
    ]);
    await tx.wait(1);
    setTxStatus([
      [{ text: `✓ Refunded ${tokenIds.length} pass${tokenIds.length > 1 ? "es" : ""}. The USDT is back in your wallet; the pass${tokenIds.length > 1 ? "es were" : " was"} burned. ` }],
      [{ text: "Transaction: " }, { text: shortAddress(tx.hash), href: bscscanTx(tx.hash) }],
    ]);
    await refreshSaleState();
    await refreshWallet();
  } catch (err) {
    setTxStatus([[{ text: `✗ Refund failed: ${friendlyError(err)}` }]]);
  } finally {
    setBusy(false);
  }
}

// ---------------------------------------------------------------------------
// Errors, in plain language
// ---------------------------------------------------------------------------

function friendlyError(err) {
  const msg = err && err.message ? String(err.message) : "";
  const code = err && err.code;

  if (msg === "WRONG_NETWORK") {
    return "Your wallet is not on BNB Smart Chain (chain 56). Switch networks and try again.";
  }
  if (msg === "INSUFFICIENT_USDT") {
    return "Not enough USDT in your wallet for this purchase.";
  }
  if (msg === "NEEDS_APPROVAL") {
    return "The sale contract is not approved to spend that much USDT yet. Approve it first, then mint.";
  }
  if (code === 4001 || /user rejected|user denied/i.test(msg)) {
    return "Transaction rejected in your wallet. Nothing was sent.";
  }
  if (/insufficient funds/i.test(msg)) {
    return "Not enough BNB in your wallet to pay for gas.";
  }
  // KongSale custom errors (ethers v6 decodes them into the message).
  if (/SaleNotStarted/.test(msg)) return "The sale has not opened yet.";
  if (/SaleEnded/.test(msg)) return "The sale has ended.";
  if (/SaleSoldOut/.test(msg)) return "The sale is sold out.";
  if (/NotSoldOut/.test(msg)) return "The sale has not sold out yet — graduation needs all 10,000 shares sold.";
  if (/InvalidAmount/.test(msg)) return "Invalid amount — mint between 1 and 10 passes.";
  if (/NoAgentId/.test(msg)) return "This wallet does not hold an Agent ID, which is required to mint.";
  if (/ExceedsWalletCap/.test(msg)) return "That would exceed the 10-pass limit per wallet.";
  if (/NotGraduated/.test(msg)) return "The sale has not graduated yet — claims open after graduation.";
  if (/AlreadyGraduated/.test(msg)) return "The sale has already graduated.";
  if (/RefundNotActive/.test(msg)) return "Refunds are not open right now.";
  if (/RefundWindowClosed/.test(msg)) return "The refund window has closed.";
  if (/NotPassOwner/.test(msg)) return "This wallet does not own that pass.";
  if (/Underfunded/.test(msg)) return "The sale contract is underfunded — graduation cannot proceed. Please report this.";
  if (/SelfReferral/.test(msg)) return "You cannot refer yourself.";
  if (/NothingToClaim/.test(msg)) return "There is nothing to claim.";
  if (/ERC20InsufficientAllowance/.test(msg)) return "The sale contract is not approved to spend that much USDT yet. Approve it first, then mint.";
  if (/ERC20InsufficientBalance/.test(msg)) return "Not enough USDT in your wallet for this purchase.";
  if (/network|fetch|timeout|failed/i.test(msg) && code !== "CALL_EXCEPTION") {
    return "Could not reach BNB Chain. Check your connection and try again.";
  }
  return "Something went wrong. Please try again.";
}

// ---------------------------------------------------------------------------
// Static content + init
// ---------------------------------------------------------------------------

function renderFooterLinks() {
  const links = [
    ["footer-sale", KONG_SALE_ADDRESS],
    ["footer-token", KONG_TOKEN_ADDRESS],
    ["footer-pass", KONG_PASS_ADDRESS],
    ["footer-usdt", USDT_ADDRESS],
    ["footer-agent-id", AGENT_ID_ADDRESS],
  ];
  for (const [id, addr] of links) {
    const el = $(id);
    el.textContent = addr;
    el.href = bscscanAddress(addr);
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
  });
  window.ethereum.on("chainChanged", async () => {
    // Recreate the provider: ethers caches the network on the old one.
    walletProvider = new ethers.BrowserProvider(window.ethereum);
    signer = await walletProvider.getSigner();
    const network = await walletProvider.getNetwork();
    walletChainId = Number(network.chainId);
    updateNetworkUI();
    await refreshWallet();
  });
}

async function init() {
  renderFooterLinks();
  renderTierCards();
  renderSaleStatus();
  renderAgentId();
  renderMintForm();
  renderReferral();
  renderPassLists();

  // Prefill the referrer from ?ref= (referral links), then validate it.
  const urlRef = readRefFromUrl();
  if (urlRef) {
    $("referrer-input").value = urlRef;
    await validateReferrer();
  }

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
  $("amount-minus").addEventListener("click", () => {
    amount = Math.max(1, amount - 1);
    updateQuote().then(renderMintForm);
  });
  $("amount-plus").addEventListener("click", () => {
    amount = Math.min(maxMintable(), amount + 1);
    updateQuote().then(renderMintForm);
  });
  $("referrer-input").addEventListener("input", onReferrerInput);
  $("approve-btn").addEventListener("click", approveUsdt);
  $("mint-btn").addEventListener("click", mintPasses);
  $("graduate-btn").addEventListener("click", graduateSale);
  $("copy-link-btn").addEventListener("click", copyReferralLink);
  $("claim-referral-btn").addEventListener("click", claimReferralRewards);
  $("claim-all-btn").addEventListener("click", () =>
    claimPasses(wallet.passes.map((p) => p.tokenId))
  );
  $("refund-all-btn").addEventListener("click", () =>
    refundPasses(wallet.passes.map((p) => p.tokenId))
  );

  wireWalletEvents();

  // Load the public sale state first (works without a wallet), then poll.
  await refreshSaleState();
  await updateQuote();
  renderMintForm();
  setInterval(refreshSaleState, SALE_POLL_MS);
  setInterval(tickCountdown, 1000);

  // Silent reconnect if the wallet is already authorized (no prompt).
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
      }
    } catch {
      // Stay disconnected; the user can connect manually.
    }
  }
}

init();
