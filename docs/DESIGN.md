# Desain Bonding Curve — Mint Pass Token

> **Status:** DRAF untuk review uncle (18 Nov 2026). Belum ada kontrak, belum ada
> biaya. Nama token, konsep utilitas, dan semua angka masih bisa diubah.
> Proyek ini TERPISAH dari AgentQuest (entri hackathon, satu tim satu proyek,
> dan AgentQuest tetap gas-only). Kontaknya dengan AgentQuest hanya: holder
> badge dapat allowlist + airdrop komunitas.

## 1. Konsep (usulan)

- **Nama kerja:** $KONG — token maskot King Kong agen (nama final TBD).
- **Chain:** BNB Smart Chain. Pembayaran dalam USDT (BEP-20), seperti JAGENT.
- **Total supply:** 1.000.000.000 (1 miliar).
- **Utilitas yang diusulkan** (ini yang menentukan orang mau beli atau tidak):
  1. Governance — voting arah proyek/drop berikutnya.
  2. Staking — bagi hasil fee (royalti pass + fee launchpad bila ada).
  3. Akses — allowlist/early access untuk drop berikutnya.
  4. Buyback & burn — sebagian pendapatan dipakai beli kembali token dari pasar.
- **Tanpa janji return.** Token utilitas, bukan investasi.

## 2. Cara kerja singkat

1. Pembeli mint **Mint Pass (NFT ERC-721)** — 1 pass = 1 share. Maksimal
   **10 pass per Agent ID** (anti-whale, distribusi merata).
2. Pass bisa **diperdagangkan di Element** sebelum graduation (royalti 5%
   ke treasury). Pass mencatat tier saat mint — tier menentukan jumlah token
   yang bisa diklaim.
3. Token **tidak dibagikan saat mint**. Token baru bisa diklaim setelah
   graduation — dan klaim membakar pass-nya.
4. Kalau **10.000 share terjual** → graduation: pool PancakeSwap dibuka,
   klaim token dibuka.
5. Kalau **30 hari tidak tercapai** → jendela refund 14 hari: pass dibakar,
   USDT kembali 100%.

## 3. Tier harga (stepped bonding curve)

| Tier | Share | Harga/share | Token/share | Total USDT | Total token |
|------|-------|-------------|-------------|------------|-------------|
| 1 | 1–2.500 | 1 USDT | 60.000 | 2.500 | 150.000.000 |
| 2 | 2.501–6.000 | 1,5 USDT | 50.000 | 5.250 | 175.000.000 |
| 3 | 6.001–10.000 | 2 USDT | 40.000 | 8.000 | 160.000.000 |
| **Total** | **10.000** | — | — | **15.750 USDT** | **485.000.000** |

Pembeli awal diuntungkan dua kali: harga lebih murah DAN token per share
lebih banyak. Total raise bila habis terjual: **15.750 USDT (~Rp286,6 juta)**.
Maksimal belanja per wallet: 20 USDT (10 share Tier 3) — terjangkau.
Minimal 1.000 buyer bila semua ambil maksimal.

## 4. Alokasi supply (1 miliar)

| Alokasi | Jumlah | % | Keterangan |
|---------|--------|---|------------|
| Penjualan kurva | 485.000.000 | 48,5% | Diklaim pemegang pass setelah graduation |
| Pool likuiditas | 250.000.000 | 25% | Dipasangkan dengan 80% USDT saat graduation |
| Treasury | 100.000.000 | 10% | Vesting 12 bulan (cliff 3 bulan) |
| Tim | 100.000.000 | 10% | Vesting 12 bulan (cliff 3 bulan) |
| Pool referral | 15.000.000 | 1,5% | Hadiah referral on-chain, dipegang KongSale (lihat §15); maks payout 14,55M |
| Komunitas/airdrop | 50.000.000 | 5% | Airdrop ke holder badge AgentQuest, dll. |

## 5. Graduation — yang terjadi saat 10.000 share terjual

- **Pool PancakeSwap dibuka:** 250.000.000 token + 12.600 USDT (80% raise).
  Harga buka pool: **0,0000504 USDT/token**.
- **Treasury menerima:** 3.150 USDT (20% raise) ≈ **Rp57,3 juta** —
  pendapatan langsung kreator, ditambah alokasi token treasury (vested).
- **Klaim dibuka:** pemegang pass klaim token sesuai tier (pass dibakar).
- Perbandingan harga beli vs harga buka pool:
  - Tier 1: 0,0000167/token → ~3x di bawah harga buka.
  - Tier 2: 0,0000300/token → ~1,7x di bawah harga buka.
  - Tier 3: 0,0000500/token → ≈ harga buka.
  - Pembeli awal masuk di bawah harga buka; pembeli terakhir masuk di harga buka.

## 6. Refund — bila target tidak tercapai

- **Deadline penjualan: 30 hari.** Bila 10.000 share tidak terjual:
  - Jendela refund **14 hari** dibuka.
  - Pemegang pass memanggil refund → pass dibakar, **100% USDT kembali**.
  - Dana ditahan penuh di escrow selama penjualan — treasury TIDAK mengambil
    apa pun sebelum graduation. Jadi refund penuh selalu memungkinkan.
  - Setelah jendela refund tutup, escrow yang tidak diklaim masuk treasury
    (aturan diumumkan di muka).
- Bila gagal: kreator rugi hanya biaya deploy (gas, kecil). Pembeli rugi
  hanya gas mint. Ini pembeda utama dari JAGENT (yang tidak punya refund —
  dana tertahan tanpa batas bila target tidak terisi).

## 7. Aturan anti-curang & keadilan

- **Gate Agent ID:** hanya wallet dengan Agent ID (balanceOf > 0) bisa mint.
- **Maks 10 pass per Agent ID.** Tanpa pre-mint tim untuk pass.
- **Tim & treasury vested** (cliff 3 bulan, lunas 12 bulan) — tidak bisa dump
  saat graduation.
- **Kontrak terverifikasi + open-source** (BscScan + Sourcify), seperti
  AgentQuest. Tanpa owner/admin setelah deploy bila memungkinkan; parameter
  kurva immutable.
- Pass adalah NFT standar ERC-721 + royalti ERC-2981 5% → otomatis
  diperdagangkan di Element.

## 8. Pendapatan kreator — ringkasan

| Skenario | Pendapatan |
|----------|------------|
| Graduation (habis terjual) | 3.150 USDT (~Rp57,3 jt) + 100 jt token treasury (vested) + royalti 5% trading pass |
| Gagal (refund) | 0 (rugi hanya gas deploy) |

## 9. Risiko — jujur

- **Risiko permintaan (terbesar):** kalau tidak ada yang beli, tidak ada
  yang didapat. Desain ini tidak menciptakan permintaan — promosi dan
  utilitas token yang melakukannya.
- **Risiko harga pasca-graduation:** pool awal tipis (12.600 USDT); penjual
  awal bisa menekan harga dengan cepat.
- **Risiko utilitas:** tanpa utilitas nyata, token cenderung menuju nol
  setelah graduation. Governance/staking/akses harus benar-benar dibangun,
  bukan janji.
- **Risiko reputasi:** proyek gagal (refund) bukan aib — refund justru
  membangun kepercayaan — tapi proyek yang lolos lalu ditinggalkan akan
  merusak nama kingkoung untuk proyek berikutnya.

## 10. Tahapan bila dilanjutkan

1. **Keputusan uncle:** nama + konsep utilitas token (ini penentu utama).
2. Build kontrak (Foundry) + test — pola yang sama dengan AgentQuest.
3. Review keamanan + test di testnet.
4. Deploy mainnet via Remix + verifikasi BscScan/Sourcify.
5. Frontend klaim/mint + daftar Alphapedia + promosi X/Square.
6. Launch: allowlist 48 jam untuk holder badge AgentQuest, lalu publik.
7. Graduation atau refund (otomatis oleh kontrak).

## 11. Yang perlu diputuskan uncle

1. Nama + konsep token (utilitasnya apa — yang bikin orang mau beli?).
2. Setuju angka di atas, atau ubah (tier, harga, target, split)?
3. Deadline 30 hari + refund 14 hari — setuju?
4. Airdrop komunitas 50 jt: untuk siapa saja (holder badge AgentQuest saja,
   atau lebih luas)?

## 12. Analisa utilitas — rekomendasi (18 Nov 23:34 WIB)

**Inti masalah:** di ekosistem free-mint, orang tidak membayar untuk janji.
Token harus nyambung ke sesuatu yang orang sudah mau. Satu-satunya yang
benar-benar dicari di ekosistem ini: **info mint gratis lebih awal +
akses yang tidak didapat orang lain**. Governance saja tidak cukup (tidak
ada yang membeli token hanya untuk voting di proyek kecil). Staking
bagi-hasil butuh pendapatan dulu — ayam-telur.

**Ranking utilitas (rekomendasi):**
1. **Token akses "alpha" (terkuat)** — $KONG jadi kunci ke sinyal mint
   gratis terverifikasi lebih awal (dari radar yang sudah jalan tiap jam),
   allowlist spot, dan quest premium. Ini satu-satunya utilitas yang memakai
   keunggulan asli kingkoung: radar + kurasi + audiens AgentQuest.
2. **Token bagi-hasil (fase 2)** — staking untuk bagi hasil royalti pass +
   fee. Hanya setelah ada pendapatan nyata.
3. **Token launchpad (jangka panjang)** — factory bonding curve untuk
   proyek lain, fee masuk ke holder. Paling besar, paling lama.

**Saran paling penting:** jangan luncurkan token untuk utilitas yang belum
ada. Urutan yang benar: (1) buktikan alpha feed-nya dicari orang — jalankan
channel alpha gratis dulu (X/Telegram), lihat apakah ramai; (2) baru
tokenize aksesnya. Token yang diluncurkan duluan tanpa utilitas jalan hanya
menjual spekulasi — dan spekulasi tanpa utilitas biasanya berakhir di nol
setelah graduation.

**Konsep yang diusulkan:** "Kong Alpha" — $KONG + maskot King Kong agen
sebagai kunci akses alpha mint gratis Agent ID.

## 13. Strategi — disetujui user 18 Nov 23:37 WIB ("ikut analisa kamu")

**Prinsip:** buktikan permintaan dulu (gratis), baru tokenize. Token
diluncurkan hanya bila channel alpha-nya terbukti dicari orang.

**Fase 0 — Persiapan (minggu ini)**
- Buat channel alpha gratis: Telegram channel "Kong Alpha" (dibuat user
  dari aplikasinya) + X @fer_rodrigues06 yang sudah ada.
- Format postingan konsisten: mint gratis terverifikasi, alamat kontrak,
  deadline, cara klaim. Sumber: radar per jam yang sudah jalan.
- Branding: maskot King Kong agen + nama "Kong Alpha".

**Fase 1 — Buktikan permintaan (2–4 minggu, gratis, tanpa token)**
- Posting sinyal alpha konsisten di X + Telegram.
- **Aturan delay (ini produknya):** sinyal dipublikasikan SETELAH wallet
  sendiri mint — supaya kuota gratis tidak direbut orang lain duluan.
  Nanti, pemegang token dapat sinyal instan (tanpa delay); channel gratis
  tetap dapat sinyal tertunda.
- **Gerbang keputusan:** lanjut ke Fase 2 hanya bila ada traksi nyata
  (mis. 500+ anggota Telegram atau engagement konsisten). Bila sepi
  setelah 3–4 minggu → ide token dihentikan, biaya yang keluar hanya waktu.
- Sambil jalan: AgentQuest tetap prioritas utama (submit hackathon
  sebelum 9 Des 15:00 WIB).

**Fase 2 — Tokenize (hanya bila Fase 1 lolos)**
- Luncurkan bonding curve sesuai desain ini (tier, refund, graduation).
- Utilitas saat launch: sinyal instan + allowlist spot + quest premium.
  Channel gratis tetap jalan dengan sinyal tertunda (corong audiens).
- Urutan launch: allowlist 48 jam untuk holder badge AgentQuest, lalu publik.
- Promosi: X, Square, Alphapedia (listing $KONG), program referral.

**Fase 3 — Setelah graduation**
- Jalankan utilitas: staking/bagi-hasil setelah ada pendapatan nyata.
- Buyback & burn dari pendapatan. Jaga kualitas alpha (mesin retensi).
- Jangka panjang: factory bonding curve (launchpad) bila ada proyek lain
  yang mau memakai.

**Risiko per fase:** Fase 1 gagal → berhenti, rugi waktu saja. Fase 2 tidak
terisi → refund melindungi semua pihak, rugi gas deploy saja.

## 14. Keputusan build — 19 Nov 00:02 WIB

User memilih "Langsung bangun kontraknya" (bukan menunggu Fase 1 lolos).
Builder subagent di-spawn untuk proyek Foundry di
`~/workspace/bonding-curve-design/kong/` — kontrak + test saja, TANPA
deploy. Deploy tetap langkah terpisah yang butuh konfirmasi user (via
Remix, seperti AgentQuest — baw tidak bisa deploy kontrak).

**BUILD SELESAI 19 Nov 00:12 WIB — 36/36 test lolos** (diverifikasi ulang
oleh Muse dengan forge test, 4 suite, 0 gagal). Kontrak: KongToken
(ERC-20, 1 miliar), KongMintPass (ERC-721, tier 1/2/3 per tokenId,
artwork berbeda per tier, royalti 5%), KongSale (escrow, graduation,
refund), KongVesting (cliff 90 hari + linear 365 hari, jam mulai saat
graduation). Graduation on-chain via PancakeSwap V2 router, LP token ke
dead address (likuiditas terkunci permanen). Estimasi total deploy +
funding ≈ Rp5.300. Catatan: allowlist 48 jam holder AgentQuest TIDAK
ditegakkan on-chain (langkah sequencing launch, bukan mekanik kontrak).
Sisa sebelum deploy: alamat treasury/tim/komunitas, timestamp saleStart,
3 URI artwork tier, konfirmasi deploy.

**Artwork 3 tier SELESAI 19 Nov 00:45 WIB** — maskot King Kong agen yang
sama, dibedakan bingkai + badge + pencahayaan: T1 emas (legendary),
T2 perak-biru (epic), T3 perunggu (rare). File JPG persegi di
`~/workspace/bonding-curve-design/kong/artwork/` (kong-pass-tier1/2/3).
Masih perlu hosting publik (URL) sebelum deploy — URI gambar dikunci di
kontrak saat deploy.

**PARAMETER DEPLOY DIPUTUSKAN 19 Nov 01:05 WIB** (user pilih usulan):
treasury = tim = komunitas = MetaMask Account 16
0xed1A29F81a61029089Ad8D641670baD47bDced3A; saleStart 1 Des 2026 00:00 WIB
(unix 1796058000). Semua 11 parameter constructor KongSale kini terisi
(tercatat di kong/README.md). Kontrak flattened siap di kong/flattened/
(buat deploy via Remix + verifikasi BscScan). Deploy BELUM dilakukan —
menunggu perintah deploy eksplisit user (deploy via Remix di browser
user + konfirmasi MetaMask).

**DEPLOY PERTAMA DIBATALKAN 19 Nov 01:11 WIB** — user bertanya soal
referral saat deploy sedang berjalan; kontrak v1 tidak punya referral.
User memilih hentikan deploy dan tambah referral on-chain dulu (lihat
§15). Terverifikasi on-chain: TIDAK ADA tx dari Account 16 setelah
deploy AgentQuest — tidak ada kontrak Kong yang ter-deploy. Deploy ulang
menunggu build v2 selesai + test lolos + perintah user.

**DEPLOY DIBATALKAN 19 Nov 01:11 WIB** — user bertanya soal referral;
kontrak v1 tidak punya referral, user memilih hentikan deploy dan tambah
referral on-chain dulu. Terverifikasi on-chain: tidak ada tx dari Account 16
setelah deploy AgentQuest (nonce 1428, txcount 1429) — tidak ada kontrak
Kong yang ter-deploy. **Referral v2 (dalam pengerjaan)**: mintPass(amount,
referrer); referrer harus pegang pass, self-referral revert; reward 3% dari
claimable KONG per share (T1 1.800 / T2 1.500 / T3 1.200), diklaim setelah
graduation; pool referral 15M KONG dari alokasi komunitas (65M → 50M);
funding KongSale jadi 750M KONG. Deploy ulang menunggu build v2 selesai +
test lolos + perintah user.

**HOSTING SELESAI 19 Nov 00:53 WIB** — repo publik
https://github.com/zainumq/kong (Pages aktif, main /docs), 3 gambar
di-upload (commit 3a22dda) dan terverifikasi HTTP 200 (ukuran byte sama
persis dengan file lokal):
- T1: https://zainumq.github.io/kong/kong-pass-tier1.jpg
- T2: https://zainumq.github.io/kong/kong-pass-tier2.jpg
- T3: https://zainumq.github.io/kong/kong-pass-tier3.jpg
URI inilah yang dipakai sebagai parameter constructor KongSale saat deploy.

- Model tier yang dibangun: kurva naik 3 tier sesuai desain ini (opsi
  flat 1 USDT ditawarkan tapi tidak dipilih user).
- Nama kerja token: $KONG (TBD); utilitas "Kong Alpha" (akses sinyal
  alpha) — utilitasnya off-chain (gating channel), bukan fungsi kontrak.
- Alamat kunci: USDT BSC 0x55d398326f99059fF775485246999027B3197955;
  Agent ID 0x60b9262456de011f7d15a54cdd8c48baaa8b022f.
- **Artwork pass berbeda per tier** (permintaan user 19 Nov 00:03 WIB):
  pass T1/T2/T3 masing-masing punya gambar NFT berbeda. Kontrak wajib
  simpan tier per tokenId dan tokenURI mengembalikan image sesuai tier
  (3 URI gambar sebagai parameter constructor, immutable). Artwork dibuat
  nanti, SEBELUM deploy — URI-nya harus sudah ada saat deploy.

## 15. Referral on-chain (ditambahkan 19 Nov 01:12 WIB, v2)

Atas permintaan user ("itu nanti ada referal nya kan"), kontrak v2
menambahkan sistem referral ON-CHAIN ke KongSale. Deploy pertama
dihentikan sebelum selesai agar fitur ini masuk kontrak.

**Cara kerja:**
- `mintPass(amount, referrer)` — pembeli menyertakan alamat referrer
  (atau `address(0)` bila tidak ada).
- Referrer HARUS memegang minimal 1 Mint Pass saat mint berlangsung.
  Bila referrer tidak memegang pass, referral diabaikan diam-diam: mint
  tetap berhasil, tidak ada reward, tidak revert. (Pilihan desain: pembeli
  yang salah ketik/salah tempel link referral tidak boleh kehilangan
  pembeliannya; frontend sebaiknya memvalidasi referrer memegang pass
  sebelum mint.)
- Self-referral (`referrer == pembeli`) REVERT.
- Reward: **3% dari claimable KONG pembeli per share** — T1: 1.800,
  T2: 1.500, T3: 1.200 KONG/share (semua bilangan bulat, tanpa rounding).
  Diakru saat mint; pembelian yang melintasi batas tier diakru per share.
- Klaim: `claimReferral()` — HANYA setelah graduation. Sebelum graduation
  revert; klaim ganda revert; saldo nol revert. Bila sale GAGAL (jalur
  refund), reward referral hangus — tidak ada graduation, tidak ada klaim
  referral (konsisten dengan klaim normal).
- Referrer TIDAK perlu masih memegang pass saat klaim — reward sudah jadi
  haknya sejak mint.

**Pendanaan:**
- Pool referral **15.000.000 KONG** dipegang KongSale, diambil dari
  alokasi komunitas (65M → 50M; lihat §4).
- Payout maksimum: 3% × 485M = **14.550.000 KONG** < 15M — pool selalu
  cukup. Sisa pool yang tidak diklaim tetap terkunci (tanpa fungsi
  recovery — konsisten dengan desain tanpa admin).
- Funding KongSale menjadi **750M KONG** (485M klaim + 250M likuiditas +
  15M pool referral); komunitas menerima 50M. `graduate()` kini
  mensyaratkan saldo sale ≥ 750M agar semua payout pasca-graduation
  terjamin.

**Event & view:** `ReferralReward(referrer, buyer, amount)` saat mint
dengan referrer valid; `ReferralClaimed(referrer, amount)` saat klaim;
view publik `referralEarned(address)` dan
`referralClaimable(address)` (0 sebelum graduation).

**Test:** suite baru `KongReferral.t.sol` (14 test) + 1 test reentrancy
`claimReferral` — total suite menjadi 51 test, semua lolos.

## 16. Bug desimal USDT v2 → v3 (ditemukan 19 Nov 03:06 WIB)

**Bug kritis:** kontrak v2 mengasumsikan USDT BSC berdecimal 6 (seperti
USDT Ethereum). SALAH — USDT BSC
(0x55d398326f99059fF775485246999027B3197955) mengembalikan
`decimals() == 18` (terverifikasi on-chain 19 Nov 2026; totalSupply
~9,18 miliar USDT di 18 desimal — di 6 desimal angkanya 9,18×10²¹, tidak
masuk akal). Harga v2 (TIER1_PRICE = 1e6 raw dst.) hanya bernilai
1e-12 USDT/share — sale praktis gratis, graduation tidak menghasilkan
apa-apa. Semua 51 test v2 lolos karena mock USDT di test memakai asumsi
6 desimal yang sama salahnya. Ditemukan oleh builder frontend saat
memverifikasi asumsi kontrak terhadap mainnet.

**Dampak:** sale belum mulai (1 Des), 0 mint, tidak ada dana user yang
berisiko. Kerugian hanya gas deploy v2 (~0,00026 BNB, ~Rp2.750). 750M
KONG terkunci di KongSale v2 + 100M di tiap vesting v2 tidak bisa
ditarik (immutable, tanpa fungsi withdraw) — tapi token belum punya
pasar sehingga nilainya nol. Satu-satunya jalan: token + sale BARU (v3).
Alamat v2 DITINGGALKAN, jangan dipakai: KongToken
0x6D877542A54F6e7839186Da5039442866DB31978, KongSale
0x7255d2Cdb1a535A6fE8740dFe5d200c6E697d18D.

**Perbaikan v3 (logika lain tidak berubah, termasuk referral):**
- Harga: TIER1 = 1e18, TIER2 = 1.5e18, TIER3 = 2e18 USDT;
  FULL_RAISE_USDT = 15_750e18. Tidak ada lagi asumsi 6 desimal di
  codebase (dicek via grep atas `1e6`, `e6`, `6 decimal`).
- Mock USDT di test: 18 desimal, sesuai mainnet.
- Test regresi baru: `KongDecimals.t.sol` (3 test) — mock dipatok ke 18
  desimal + harga diassert terhadap `decimals()` token itu sendiri
  (dibaca live, bukan hardcode 18); terbukti GAGAL terhadap kode lama
  (2 dari 3 gagal saat mock dikembalikan ke 6). `KongDecimalsFork.t.sol`
  (2 test) — membaca `decimals()` dari kontrak USDT mainnet asli via
  fork dan mengassert harga sale terhadapnya; di-skip otomatis bila
  `BSC_RPC_URL` tidak di-set. Total suite: 54 lolos + 1 skip (56 lolos
  dengan fork test).
- Aturan baru: SELALU baca `decimals()` LIVE dari token asli sebelum
  menulis konstanta harga; mock test HARUS cocok dengan mainnet.
- Pendanaan tidak berubah: sale 750M, tiap vesting 100M, komunitas 50M.
- Frontend (`kong/frontend/`) sudah membaca decimals live — tinggal
  diarahkan ke alamat kontrak v3 setelah deploy.
