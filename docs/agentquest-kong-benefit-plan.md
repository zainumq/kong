# AgentQuest → $KONG Benefit Plan

Dibuat 19 Nov 2026 ~09:05 WIB atas perintah user ("eksekusi").
**DISETUJUI user 19 Nov 2026 ~09:10 WIB: Split 30M.**
Desain awal 20M holder saja ditolak karena hanya menumbuhkan
AgentQuest tanpa mendorong pembelian share.

## Ringkasan

Holder badge AgentQuest mendapat tiga benefit untuk $KONG, tanpa
mengubah kontrak apa pun (KongSale v3 immutable, tanpa allowlist).
Total maksimal 30M KONG dari alokasi komunitas 50M yang dipegang
deployer (Account 16); sisa 20M tetap di cadangan komunitas.

1. **Airdrop holder 10M KONG** — proporsional dengan jumlah badge.
2. **Bonus pembeli 20M KONG** — +20% KONG ekstra dari claimable bagi
   holder badge yang membeli share.
3. **Early access 48 jam** — sequencing pengumuman + opsi gate UI.

## Bagian A — Airdrop holder (pool 10M KONG)

- **Pool: 10.000.000 KONG** (1% total supply).
- **Syarat**: pegang ≥1 badge AgentQuest (kontrak
  0x26ad277193ff31bd086a47bf7b1d25a93573c989) saat snapshot.
  Badge soulbound, maks 4/wallet — distribusi tercapai secara alami,
  tanpa cap tambahan.
- **Snapshot: saat graduation** (ketika 10.000 share terjual dan pool
  terbentuk). Bila sale TIDAK lulus (refund), tidak ada airdrop dan
  10M tetap di cadangan komunitas.
- **Pembagian**: proporsional dengan jumlah badge yang dipegang.
  Estimasi per badge (tergantung total badge saat snapshot):

  | Total badge saat snapshot | KONG per badge | Holder 4 badge |
  |---|---:|---:|
  | 1.000 | 10.000 | 40.000 (~$0,67 di harga T1) |
  | 1.500 | 6.667 | 26.667 (~$0,44 di harga T1) |
  | 2.000 | 5.000 | 20.000 (~$0,33 di harga T1) |

  Patokan harga: 1 share Tier 1 = 1 USDT = 60.000 KONG.
  Per 19 Nov 08:54 WIB: 451 badge / 181 holder.
- **Anti-sybil**: badge butuh Agent ID, dan Agent ID 1 per akun
  Binance — sybil terbatas oleh akun Binance, bukan gratis.

## Bagian B — Bonus pembeli (pool 20M KONG)

- **Pool: 20.000.000 KONG** (2% total supply) sebagai CAP, bukan
  komitmen belanja — bonus hanya terbayar bila holder badge
  benar-benar membeli share; sisa pool kembali ke cadangan komunitas.
- **Besaran: +20% KONG ekstra** dari jumlah claimable pembeli.
  Contoh: beli 10 share Tier 1 (claimable 600.000 KONG) → bonus
  +120.000 KONG. Beli 10 share Tier 3 (claimable 400.000 KONG) →
  bonus +80.000 KONG.
- **Syarat**: (1) pegang ≥1 badge AgentQuest saat snapshot
  (graduation); (2) membeli ≥1 share (terbukti on-chain dari
  kepemilikan/klaim Mint Pass). Badge boleh diklaim kapan saja
  sebelum snapshot — holder yang baru klaim badge di tengah sale
  tetap eligible.
- **Bila total bonus yang diperoleh melebihi pool 20M**, dibayar
  pro-rata (semua bonus diskalakan turun dengan faktor yang sama).
  Estimasi kasar: bila 181 holder badge saat ini semuanya beli
  maksimal 10 share (1.810 share, claimable ~90M KONG), bonus 20%
  = ~18M — masih di dalam pool.
- **Catatan**: bonus ini DI LUAR referral 3% yang sudah ada di
  kontrak — keduanya bisa didapat bersamaan.

## Bagian C — Distribusi (kedua komponen)

- Satu kontrak **Merkle distributor** baru (kecil, terverifikasi),
  di-deploy SETELAH graduation; holder klaim sendiri (gas-only).
- Semua data pembuktian on-chain: kepemilikan badge (snapshot di
  blok graduation) + pembelian share (event Mint Pass / klaim).
- Tidak ada distribusi bila sale tidak lulus — KONG tanpa pool
  tidak bernilai, dan kedua pool tetap di cadangan komunitas.

## Bagian D — Early access 48 jam

Kontrak sale permissionless (semua holder Agent ID bisa mint sejak
saleStart), jadi "early access" di sini adalah sequencing + gate UI,
BUKAN whitelist on-chain. Pengumuman tidak boleh mengklaim eksklusif.

- **30 Nov 2026**: pengumuman ke holder badge AgentQuest (X + Telegram
  + entri Alphapedia) — sale buka 1 Des, mereka yang pertama tahu.
- **1 Des 2026 00:00 WIB**: sale buka. Halaman mint (opsi, MASIH
  MENUNGGU keputusan user): tombol mint hanya aktif untuk wallet
  yang pegang ≥1 badge AgentQuest sampai 3 Des 00:00 WIB. Gate ini
  UI saja — siapa pun tetap bisa memanggil kontrak langsung; hal itu
  diungkapkan jujur di halaman.
- **3 Des 2026 00:00 WIB**: pengumuman publik penuh (X + Telegram).

## Bagian E — Pengumuman benefit (sekarang, untuk mendorong klaim badge)

Benefit diumumkan SEGERA (tidak menunggu 30 Nov) karena tujuannya
mendorong klaim badge AgentQuest — setiap klaim menambah holder +
transaksi selama periode submission hackathon (s.d. 9 Des).

### X (≤280 karakter)

> AgentQuest holders get more than badges 🦍 Hold any badge at $KONG
> graduation: share a 10M KONG airdrop — and buy shares for a +20%
> KONG bonus. Plus 48h early access. Sale opens 1 Dec:
> zainumq.github.io/kong #AgenticWallet

(221 karakter, terverifikasi ≤280.)

### Telegram (Kong Alpha)

> 🦍 AgentQuest holders — your badges now earn $KONG
>
> Hold any AgentQuest badge when the $KONG sale graduates:
>
> • Share a 10,000,000 KONG airdrop — proportional to the badges you
>   hold (max 4 per wallet).
> • Buy shares and get a +20% KONG bonus on top of your claimable.
>   Example: 10 Tier 1 shares (600,000 KONG) earn +120,000 KONG.
> • 48h early access — the sale opens 1 Dec 2026, badge holders hear
>   about it first.
>
> AgentQuest badges are FREE (gas only) for Agent ID holders:
> zainumq.github.io/agentquest
>
> $KONG sale: zainumq.github.io/kong
> 1–2 USDT per share, max 10 per Agent ID, 100% refund if the sale
> does not graduate.
>
> DYOR. Not financial advice.

### Entri Alphapedia (listing Kong, kind update)

EN: "AgentQuest badge holders receive three benefits for the $KONG
sale, from the 50M KONG community allocation: (1) a 10,000,000 KONG
airdrop, distributed proportionally to AgentQuest badges held at
graduation; (2) a buyer bonus of +20% extra KONG on claimable tokens
for badge holders who buy shares (20M KONG pool cap, pro-rata if
oversubscribed); (3) 48-hour early access — the sale is announced to
badge holders first on 30 Nov 2026, with the public announcement on
3 Dec. Snapshot and distribution happen at graduation via a Merkle
distributor; no airdrop or bonus if the sale does not graduate. Note:
the sale contract has no on-chain allowlist; early access is
announcement sequencing plus an optional mint-page UI gate, not
exclusive on-chain access."

**Entri sudah diposting 19 Nov ~09:11 WIB — entry id 11703**
(kind update, listing Kong).

## Keputusan yang masih terbuka (butuh user)

1. Gate UI halaman mint 1–3 Des: ya / tidak?
2. Posting pengumuman X: oleh Muse (browser task, perlu persetujuan
   per posting) atau oleh user sendiri? Telegram selalu oleh user.
