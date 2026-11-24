# Audit Keamanan — KongMerkleDistributor

**Tanggal:** 23 Nov 2026
**Auditor:** Muse (subagent, metode review manual + PoC Foundry + live test
BSC testnet, seperti audit bug-bounty)
**Status kontrak:** DEPLOYED di BSC mainnet 23 Nov 2026 18:25 WIB —
`0xdbe15d0566205cdf94288bc983fb72e279278234` (deploy tx
`0xe71ac50419b9f88899ab0e51c7475d10d3ae60825d75fa4826e1fd89b604e11c`,
block 135262639). BscScan + Sourcify verified (exact_match). DIdanai
tepat 33.000.000 KONG (tx `0x300e05041e6f44c4d9452f3019ea5fcdf86db6b74327436bdd6497d5ba15fbe5`,
block 135266256). `merkleRoot()` belum di-set — root baru di-set setelah
graduation. **Catatan:** audit ini ditulis sebelum deploy; source yang
di-deploy sama dengan yang diaudit (Sourcify exact_match mengonfirmasi
bytecode cocok dengan source ini), jadi temuan di bawah tetap berlaku
untuk kontrak mainnet.
**Scope:** `src/KongMerkleDistributor.sol` (196 baris) +
`test/KongMerkleDistributor.t.sol` (20 test) +
`script/build-tree.py` (off-chain tree builder) +
`script/DeployKongMerkleDistributor.s.sol`.

| Kontrak | Alamat | Baris |
|---|---|---|
| KongMerkleDistributor (mainnet) | `0xdbe15d0566205cdf94288bc983fb72e279278234` | 196 |
| KongMerkleDistributor (testnet 97) | `0xbd01d8326C85425A94a9B6decBAD29F9e76437e2` | — |
| Mock KongToken (testnet 97) | `0xE99938E1f4645E7E98a17a9064805fFdDB4D0CFE` | — |
| KongToken (mainnet, immutable arg) | `0x410eAA536d701c5096619be8cBB6D46643796ee4` | 24 |

Kontrak ini memegang 33.000.000 KONG (10M airdrop holder + 20M bonus
pembeli + 3M streak pool) dan didanai SEBELUM sale dibuka (1 Des 2026),
sehingga janji benefit menjadi komitmen on-chain yang bisa diverifikasi —
bukan sekadar janji di dokumen. Konsekuensinya, aturan tanpa-kebocoran
(no-leak) sebelum graduation adalah syarat keamanan utama kontrak ini
(lihat § M-1 KongSale di bawah).

## Ringkasan eksekutif

| Severity | Jumlah |
|---|---|
| Critical | **0** |
| High | **0** |
| Medium | **2** |
| Low | **2** |
| Informational | **6** |

**Verdict: tidak ditemukan cara bagi pihak luar untuk menguras dana atau
mencuri klaim orang lain.** Semua jalur pemindahan dana memakai
`nonReentrant` + checks-effects-interactions, klaim ganda dicegah bitmap
Uniswap-style, proof diverifikasi dengan OpenZeppelin `MerkleProof`, dan
20/20 test Foundry lolos. Live test di BSC testnet mengonfirmasi
end-to-end: root di-set, klaim 133.000 KONG terbayar persis, klaim ganda
revert `AlreadyClaimed`.

Kedua temuan Medium bersifat operasional / asumsi kepercayaan (trust
assumption) — bukan bug yang bisa dieksploitasi pihak luar. Keduanya
dimitigasi dengan prosedur, bukan dengan mengubah kode (desain kontrak
sudah fixed).

---

## Mitigasi M-1 KongSale — eksplisit

Audit KongSale 19 Nov 2026 (M-1): `graduate()` mengabaikan nilai balik
`addLiquidity`, sehingga bila KONG sudah beredar / ada pool KONG/USDT
sebelum graduation, sebagian escrow bisa terkunci permanen di kontrak
sale. Mitigasinya: **jangan pernah membuat KONG komunitas bisa bergerak
atau diperdagangkan sebelum graduation.**

Distributor ini memegang 33M KONG sebelum sale dibuka — jadi pertanyaan
auditnya: **apakah ada jalur KONG keluar dari kontrak ini sebelum
graduation?** Jawabannya tidak, dengan satu pengecualian yang
ter-time-lock jauh melewati graduation:

| Jalur keluar | Gate | Bisa sebelum graduation? |
|---|---|---|
| `claim()` | root harus sudah di-set | Tidak — root hanya di-set saat graduation (prosedur; lihat L-2 untuk catatan bahwa gate ini prosedural, bukan on-chain) |
| `sweepUnclaimed()` (root set) | root set + 180 hari | Tidak |
| `sweepUnclaimed()` (no-root) | root TIDAK pernah di-set + lewat 2027-03-01 | Tidak — 2027-03-01 adalah sale deadline (31 Des 2026) + jendela refund 14 hari + buffer; graduation (bila terjadi) jauh sebelum tanggal itu |
| Fungsi lain | — | Tidak ada jalur keluar lain: tidak ada `withdraw`, `rescue`, `transferOwnership` darurat, atau `selfdestruct` |

Satu-satunya skenario kebocoran pra-graduation adalah owner sendiri yang
sengaja memanggil `setRoot()` sebelum graduation (lihat L-2) — itu
membutuhkan kunci deployer, yang sudah memegang 50M KONG likuid di luar
kontrak ini. Model kepercayaan tidak berubah: **mitigasi M-1 KongSale
tetap utuh.**

---

## Temuan Medium

### M-1 — Root yang salah tidak bisa diperbaiki di tempat; dana terkunci 180 hari

**Lokasi:** `src/KongMerkleDistributor.sol` (`setRoot`, once-only)

**Penjelasan:**
`setRoot()` hanya bisa dipanggil sekali — by design, agar owner tidak
bisa menukar pohon setelah holder mulai klaim (itu akan memungkinkan
owner mencuri alokasi holder). Sisi buruknya: bila root yang di-set
salah (blok snapshot keliru, bug tree builder, format leaf tidak cocok),
**tidak ada** klaim yang bisa lolos verifikasi, dan tidak ada cara
memperbaiki root. Satu-satunya pemulihan: tunggu `sweepUnclaimed()`
terbuka 180 hari setelah root di-set, tarik dana, deploy distributor
baru, dan ulangi proses — holder menunggu 6 bulan.

**Dampak:**
- Kesalahan off-chain (snapshot/tree builder) berubah menjadi penundaan
  180 hari bagi seluruh komunitas. Bukan kehilangan dana (dana kembali
  ke owner lalu bisa didistribusikan ulang), tapi kerusakan kepercayaan
  yang besar.
- Pihak luar tidak bisa memicu ini — hanya owner yang bisa memanggil
  `setRoot()`.

**Mitigasi (prosedural, wajib — tercantum di pre-root checklist,
kong-distributor-design.md):**
1. Bangun pohon dengan DUA implementasi independen
   (`script/build-tree.py` + OpenZeppelin StandardMerkleTree JS);
   kedua root harus cocok byte-for-byte.
2. Verifikasi total ketiga pool ≤ 33.000.000 KONG sebelum root di-set.
3. Simulasikan klaim di fork mainnet lokal (forge) dengan root
   kandidat: klaim SEMUA leaf (atau sampel besar termasuk edge case
   jumlah 0 di satu pool), pastikan tidak ada yang revert dan total
   payout sama dengan total pohon.
4. Publikasikan data pohon (leaf + proof) di repo + situs SEBELUM
   `setRoot()` dipanggil, agar siapa pun bisa memverifikasi
   independen.
5. `setRoot()` hanya dipanggil setelah checklist 1–4 lolos.

### M-2 — Root-setting adalah aksi kepercayaan: owner bisa menahan root dan mereklamasi 2027-03-01

**Lokasi:** `src/KongMerkleDistributor.sol` (`setRoot`, `sweepUnclaimed`
cabang no-root)

**Penjelasan:**
Tidak ada mekanisme on-chain yang MEMAKSA owner memanggil `setRoot()`.
Bila sale lulus tapi owner tidak pernah men-set root, holder tidak bisa
klaim apa pun, dan pada 2027-03-01 owner bisa mereklamasi seluruh 33M
KONG lewat cabang no-root `sweepUnclaimed()`. Skenario ini tidak
membutuhkan bug — ini adalah perilaku kontrak sesuai desain.

**Dampak:**
- 33M KONG kembali ke owner; holder mendapat 0. Ini adalah asumsi
  kepercayaan yang sama dengan seluruh rencana benefit (builder
  memegang alokasi komunitas 50M sejak awal), tapi perlu dinyatakan
  eksplisit karena dana sudah terkunci di kontrak dan holder tidak
  punya jalan keluar on-chain.
- Catatan penyeimbang: setelah root di-set, owner TIDAK bisa menarik
  dana sebelum jendela 180 hari berakhir, dan klaim holder tidak bisa
  diblokir — jadi kepercayaan hanya dibutuhkan untuk SATU aksi
  (`setRoot()`), yang transaksinya bisa diamati publik.

**Mitigasi (prosedural):**
1. Komitmen publik: root di-set segera setelah graduation (target:
   dalam 7 hari setelah blok graduation final), diumumkan di X +
   Telegram + Alphapedia.
2. Komunitas bisa memverifikasi on-chain kapan saja: `merkleRoot() ==
   0` berarti root belum di-set; `rootSetTime()` menunjukkan kapan.
3. Bila owner tidak kunjung men-set root, itu terlihat publik dan
   menjadi masalah reputasi builder — bukan kegagalan teknis yang
   tersembunyi.

---

## Temuan Low

### L-1 — Kompromi kunci owner memungkinkan root jahat atau sweep

**Lokasi:** `setRoot`, `sweepUnclaimed` (`onlyOwner`, owner = EOA
Account 16)

**Penjelasan:**
Owner adalah satu EOA (deployer, Account 16). Bila kunci itu bocor,
penyerang bisa: (a) memanggil `setRoot()` dengan pohon yang daunnya
membayar penyerang — mencuri hingga 33M KONG; (b) setelah jendela 180
hari, memanggil `sweepUnclaimed()`. Tidak ada multisig / timelock.

**Dampak:** Terbatas oleh model kepercayaan yang sudah ada: kunci yang
sama mengendalikan 50M KONG komunitas, beneficiary kedua kontrak
vesting (200M KONG), dan treasury sale. Kontrak ini tidak menambah
permukaan kepercayaan baru yang material — penyerang yang memegang
kunci itu sudah bisa mencuri jauh lebih banyak di luar kontrak ini.

**Rekomendasi:** Tidak ada perubahan kode yang diminta (desain fixed).
Operasional: kunci Account 16 sudah seharusnya disimpan sebagai
cold/hot wallet yang disiplin; pertimbangkan memindahkan ownership ke
multisig SETELAH root di-set dan klaim berjalan (OZ `Ownable` mendukung
`transferOwnership`), karena setelah root di-set satu-satunya wewenang
owner yang tersisa adalah sweep pasca-jendela.

### L-2 — `setRoot()` tidak punya gate graduation on-chain

**Lokasi:** `setRoot` — tidak membaca state `KongSale`

**Penjelasan:**
Kontrak tidak memeriksa apakah sale sudah lulus sebelum menerima root.
Owner (atau kunci yang dikompromi, lihat L-1) secara teknis bisa
memanggil `setRoot()` sebelum graduation dan membuka klaim — membuat
KONG bergerak sebelum graduation dan melanggar mitigasi M-1 KongSale.
Gate graduation ditegakkan oleh prosedur (design doc), bukan oleh kode.

**Dampak:** Membutuhkan kunci owner; pihak luar tidak bisa memicu.
Alternatif desain — `setRoot()` memeriksa `KongSale.graduated()` —
ditolak karena desain fixed dan karena menambahkan dependensi
antar-kontrak (bila `KongSale` diganti / dibaca salah, root bisa
terkunci selamanya).

**Rekomendasi:** Prosedural — `setRoot()` hanya dipanggil setelah
graduation terkonfirmasi on-chain (`KongSale.graduated() == true` +
pool terbentuk), tercantum di pre-root checklist.

---

## Temuan Informational

### I-1 — Hashing sorted-pair harus cocok dengan tree builder off-chain

`MerkleProof.verify` (OZ v5.7) memakai commutative hashing: tiap
pasangan diurutkan sebelum di-hash. Tree builder yang memakai pasangan
tak-terurut menghasilkan root yang tidak satu pun proof-nya lolos.
**Diverifikasi:** `script/build-tree.py` memakai sorted-pair dan
terbukti cocok lewat live test testnet (klaim sukses on-chain).
Dokumentasi format leaf ada di design doc + NatSpec kontrak.

### I-2 — Klaim boleh dibayarkan gas-nya oleh pihak ketiga

`claim()` tidak memeriksa `msg.sender == account` (seperti distributor
Uniswap). Siapa pun boleh membayar gas untuk klaim siapa pun; token
selalu masuk ke `account`, tidak pernah ke `msg.sender`. Ini disengaja:
memungkinkan relayer / bantuan klaim untuk holder yang kehabisan BNB.
Bukan celah — penyerang tidak mendapat apa pun dari mengklaimkan
punya orang lain.

### I-3 — Gas klaim naik dengan kedalaman pohon

Live test (pohon 4 daun, proof 2 elemen): 70.413 gas. Pohon realistis
(~500–1.000 holder, proof 9–10 elemen) diperkirakan ~75–90k gas —
tetap murah (~0,000008 BNB / ~Rp85 di 0,1 gwei). Deploy: 671.390 gas
(testnet aktual). `setRoot`: 69.699 gas.

### I-4 — Tidak ada penanganan ETH

Kontrak tidak punya `receive`/`fallback`: transfer ETH biasa revert.
ETH yang dipaksa masuk via `selfdestruct` akan terjebak selamanya
(tidak ada fungsi rescue — by design, agar tidak ada jalur keluar
dana). Dampak nihil: tidak ada alasan mengirim ETH ke kontrak ini.

### I-5 — `block.timestamp` untuk jendela 180 hari

Validator BSC bisa menggeser timestamp beberapa detik — tidak relevan
pada skala 180 hari / tanggal 2027-03-01. Bukan masalah.

### I-6 — `sweepUnclaimed()` menyapu SELURUH saldo

Termasuk KONG ekstra yang mungkin terkirim ke kontrak secara tidak
sengaja (salah alamat transfer). Standar untuk distributor semacam
ini; tidak ada dana user lain yang disimpan di kontrak ini, jadi
tidak ada risiko menyapu milik orang lain.

---

## Cakupan yang TIDAK diaudit

- **Tree builder / snapshot off-chain** (`build-tree.py` diverifikasi
  cocok formatnya lewat live test, tapi logika snapshot graduation —
  scan holder badge, kepemilikan pass, hari streak — belum dibangun
  dan harus diaudit terpisah saat dibuat).
- **KongSale / KongToken / AgentQuest / AgentQuestStreak** — di luar
  scope; diasumsikan sesuai audit 19 Nov 2026.
- **Remix deploy flow** — langkah-langkahnya didokumentasikan di
  design doc; verifikasi source pasca-deploy adalah tanggung jawab
  sesi deploy.

## Lampiran — bukti pengujian

- **Forge:** 20/20 test lolos (`forge test --match-contract
  KongMerkleDistributorTest`, 23 Nov 2026). Meliputi: klaim happy-path
  (1 + 4 daun), klaim pihak ketiga, klaim ganda, proof salah (jumlah /
  akun / index), klaim sebelum root, klaim dengan value ETH, setRoot
  ganda / non-owner / nol, sweep sebelum tenggat, sweep setelah
  tenggat, reclaim no-root sebelum/tepat/sesudah 2027-03-01, sweep
  non-owner, dan root-set memblokir reclaim no-root.
- **Testnet (chain 97):**
  - Distributor `0xbd01d8326C85425A94a9B6decBAD29F9e76437e2`
    (deploy tx `0x3cf76d72d2da1cd9edf1ae8b3f4011d5fd18f179645d2b0ab134403f936756b8`,
    671.390 gas)
  - Mock KONG `0xE99938E1f4645E7E98a17a9064805fFdDB4D0CFE`
    (deploy tx `0x69f4ac4cbc72c3e432b99c1dfe365007c52131656644929114bfcf105059de9c`)
  - Pendanaan 33M (tx `0x4ddb5f0351315b9f16b4c802b40ec5aeafc8b9ce47bf14a23e143d49078ac7f1`)
  - `setRoot` (tx `0xc842a76b66a92a4f0fe1d3eb928b00e05e366686882692ca72f83dc7bee9249a`,
    blok 144388553, 69.699 gas, event `RootSet` terbit)
  - `claim` leaf 0 (tx `0xef9cfe6c4c7ed2520efb594e7585822580de24784d0a1487838f1ad6f25ad093`,
    blok 144388568, 70.413 gas): 133.000 KONG terbayar persis
    (10.000 airdrop + 120.000 bonus + 3.000 streak); saldo deployer
    967.000.000 → 967.133.000; saldo distributor 33.000.000 →
    32.867.000; `isClaimed(0) == true`, `isClaimed(1) == false`.
  - Klaim ganda (eth_call) revert `0x646cf558` = `AlreadyClaimed()`.
- **Flattened source** (`flattened/KongMerkleDistributor.flattened.sol`,
  69.682 byte) dikompilasi dengan solc 0.8.24 (optimizer 200, Cancun):
  bytecode identik dengan build forge kecuali trailer metadata hash
  (ekspektasi normal — path source berbeda).
