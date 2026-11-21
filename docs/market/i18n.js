// i18n — halaman marketplace $KONG mainnet (/market).
//
// Tiga bahasa: id (bawaan), en, zh. Semua teks antarmuka (statis di
// index.html maupun dinamis di market.js) hidup di kamus I18N di bawah;
// tidak ada lagi string Bahasa Indonesia hardcoded di kode UI.
//
// Cara pakai:
//   t("connectBtn")                    -> "Hubungkan wallet" / "Connect wallet" / "连接钱包"
//   t("holdingPasses", { n: 2 })       -> interpolasi {n}; bila nilainya
//                                        objek {one, other}, pilih bentuk
//                                        tunggal bila n === 1.
//   setLang("en")                      -> ganti bahasa + simpan preferensi
//                                        (localStorage kong-market:lang)
//   applyStaticI18n()                  -> terapkan ke semua elemen HTML
//                                        ber-atribut data-i18n /
//                                        data-i18n-attr.
//   numLocale()                        -> "id-ID" / "en-US" / "zh-CN" untuk
//                                        format angka (fmtInt/fmtUsdt/...).
//
// Nama tier ("Tier 1 — Gold" dst.) sengaja TIDAK diterjemahkan — itu nama
// produk yang sama di semua halaman (mint, Alphapedia, artwork).
//
// File ini bisa diimpor di Node untuk pengujian konsistensi kunci: semua
// akses document/window/localStorage dijaga typeof.

export const LANGS = ["id", "en", "zh"];
export const LANG_LABELS = { id: "Indonesia", en: "English", zh: "中文" };
export const DEFAULT_LANG = "id";
const STORAGE_KEY = "kong-market:lang";
const NUM_LOCALES = { id: "id-ID", en: "en-US", zh: "zh-CN" };
const HTML_LANG = { id: "id", en: "en", zh: "zh-CN" };

export const I18N = {

  id: {
    // -- meta / header --
    pageTitle: "Marketplace $KONG — Kong Mint Pass",
    metaDescription:
      "Marketplace $KONG — jual beli Kong Mint Pass di BNB Chain. Bayar USDT atau BNB, royalti 5% ke treasury, fee market 1%. Non-custodial: pass tetap di wallet penjual.",
    ogDescription:
      "Jual beli Kong Mint Pass (1 pass = 1 share $KONG). Bayar USDT atau BNB. Floor = harga mint per tier.",
    brandSub: "Jual beli Kong Mint Pass — USDT atau BNB",
    mintPageBtn: "← Halaman Mint",
    testnetDemoBtn: "Coba demo testnet",
    langSelectLabel: "Pilih bahasa",
    // -- banner --
    networkWarnStrong: "Jaringan salah.",
    networkWarnText:
      "Wallet Anda tidak di BNB Smart Chain (chain 56). Membeli dan me-listing butuh BSC.",
    switchNetworkBtn: "Pindah ke BSC",
    notDeployedStrong: "Marketplace belum dibuka.",
    notDeployedText:
      "Kontrak market belum di-deploy ke mainnet. Deploy dijadwalkan setelah sale dibuka 1 Desember 2026 dan pass pertama ada. Halaman ini sudah siap — listing akan muncul otomatis setelah kontrak aktif.",
    // -- hero --
    heroAria: "Tentang marketplace",
    heroImgAlt: "Kong Mint Pass — artwork Tier 1 Gold: King Kong berpakaian agen rahasia",
    heroTitle: "Jual beli pass, tanpa perantara.",
    heroP1:
      "Setiap Mint Pass adalah satu share sale $KONG. Di sini pass bisa diperdagangkan sebelum diklaim: bayar dengan USDT atau BNB, harga tetap, dan dana terbagi otomatis — penjual 94%, royalti 5% ke treasury, fee marketplace 1%.",
    heroP2:
      "Non-custodial: pass tetap di wallet penjual selama ter-listing. Penjual tetap bisa klaim atau refund kapan saja — listing yang pass-nya sudah diklaim otomatis tidak bisa dibeli.",
    heroP3:
      "Harga listing tidak boleh di bawah floor tier-nya (sama dengan harga mint): 1 / 1,5 / 2 USDT.",
    // -- status sale --
    saleAria: "Status sale",
    saleTitle: "Status sale",
    sharesTitle: "Share terjual",
    sharesStatus: "{sold} / {total} share",
    raisedNoteEmpty: "Total terkumpul: —",
    raisedNote: "Total terkumpul: {amount} (disimpan di escrow sampai graduation)",
    countdownLabelUpcoming: "Sale dibuka dalam",
    countdownLabelLive: "Sale berakhir dalam",
    countdownLabelRefund: "Jendela refund berakhir dalam",
    countdownLabelStatus: "Status sale",
    countdownNoteInitial: "Sale dibuka 1 Desember 2026, 00:00 WIB.",
    countdownNoteUpcoming: "Sale dibuka {start}. Marketplace dibuka setelah pass pertama ada.",
    saleStartDate: "1 Desember 2026, 00:00 WIB",
    countdownNoteLive:
      "Batas graduation: bila semua 10.000 share terjual sebelum ini, sale lulus dan klaim dibuka.",
    countdownNoteRefund:
      "Sale tidak terjual habis — pemegang pass bisa refund 100% USDT di halaman mint.",
    countdownNoteGraduated: "Pool sudah live — pass bisa diklaim menjadi $KONG di halaman mint.",
    countdownNoteSoldout: "Semua share terjual — graduation membuka pool dan klaim.",
    countdownNoteEnded: "Sale berakhir tanpa terjual habis dan jendela refund sudah tutup.",
    refundLabel: "Jendela refund",
    refundNoteInitial: "Refund 100% hanya dibuka bila sale tidak terjual habis.",
    refundNote:
      "Refund 100% hanya dibuka bila sale tidak terjual habis. Jendela refund tutup {date}.",
    refundNoteActive:
      "Refund 100% USDT — bakar pass Anda di halaman mint sebelum jendela ini tutup.",
    countdownGraduated: "Graduated ✓",
    countdownSoldout: "Terjual habis",
    durationZero: "0 dtk",
    durationDays: "{d} hari",
    durationHours: "{h} jam",
    durationMin: "{m} mnt",
    durationSec: "{s} dtk",
    // -- listing (statis) --
    listingsAria: "Listing",
    listingsTitle: "Listing",
    refreshListingsBtn: "Muat ulang listing",
    listingsIntro:
      "Setiap listing diverifikasi live sebelum ditampilkan: penjual masih pemilik pass, approval ke market masih berlaku, dan listing di kontrak masih cocok. Listing yang sudah tidak valid disembunyikan.",
    filterTier: "Tier",
    filterAllTiers: "Semua tier",
    filterCurrency: "Mata uang",
    filterAll: "Semua",
    filterSort: "Urutkan harga",
    sortAsc: "Termurah dulu",
    sortDesc: "Termahal dulu",
    // -- pass saya (statis) --
    myPassesAria: "Pass saya",
    myPassesTitle: "Pass saya",
    scanningPasses: "Memindai pass Anda…",
    // -- cara kerja --
    howAria: "Cara kerja",
    howTitle: "Cara kerja",
    howListVerb: "List",
    howListText:
      " — approve kontrak market atas pass Anda, lalu tentukan harga (USDT atau BNB). Harga tidak boleh di bawah floor tier-nya. Pass tetap di wallet Anda.",
    howBuyVerb: "Beli",
    howBuyText:
      " — untuk listing USDT, approve USDT sebesar harga dulu; untuk listing BNB, BNB dikirim bersama transaksi beli. Dana terbagi otomatis dalam satu transaksi: penjual 94%, royalti 5% ke treasury, fee 1% ditampung di kontrak market. Pembelian dilindungi batas harga maksimum: bila harga listing naik di atas harga yang ditampilkan sebelum transaksi diproses, transaksi dibatalkan otomatis.",
    howUpdateVerb: "Ubah / batal",
    howUpdateText:
      " — penjual bisa mengubah harga atau membatalkan listing kapan saja (biaya gas saja).",
    howClaimVerb: "Klaim / refund",
    howClaimText:
      " — pemilik bisa klaim (setelah graduation) atau refund (bila sale gagal) kapan saja, bahkan saat pass ter-listing. Listing pass yang sudah dibakar otomatis tidak bisa dibeli.",
    floorTableTitle: "Floor harga per tier",
    thTier: "Tier",
    thFloorUsdt: "Floor USDT",
    thFloorBnb: "Floor BNB (perkiraan)",
    thBreakeven: "Harga impas*",
    tier1Usdt: "1 USDT",
    tier1Bnb: "~0,0017 BNB",
    tier1Be: "1,064 USDT",
    tier2Usdt: "1,5 USDT",
    tier2Bnb: "~0,00254 BNB",
    tier2Be: "1,596 USDT",
    tier3Usdt: "2 USDT",
    tier3Bnb: "~0,00339 BNB",
    tier3Be: "2,128 USDT",
    breakevenNote:
      "* Harga impas: harga jual agar penjual terima bersih sebesar harga mint setelah potongan 6% (royalti 5% + fee 1%). Floor BNB final ditetapkan saat deploy berdasarkan harga BNB saat itu.",
    splitTableTitle: "Contoh pembagian — penjualan 2 USDT",
    thPart: "Bagian",
    thAmount: "Besaran",
    thReceiver: "Penerima",
    splitRoyalty: "Royalti",
    splitRoyaltyAmt: "0,10 USDT",
    splitRoyaltyTo: "Treasury",
    splitFee: "Fee marketplace",
    splitFeeAmt: "0,02 USDT",
    splitFeeTo: "Ditampung di kontrak market",
    splitSeller: "Penjual terima",
    splitSellerAmt: "1,88 USDT",
    splitSellerTo: "Penjual",
    approvalWarnStrong: "Hati-hati approval palsu.",
    approvalWarnText:
      "Hanya approve alamat kontrak market resmi di bawah ini. Jangan pernah approve kontrak lain yang mengatasnamakan marketplace KONG — approval palsu bisa memindahkan pass Anda.",
    factPassLabel: "KongMintPass:",
    factSaleLabel: "KongSale:",
    factUsdtLabel: "USDT (BSC, 18 desimal):",
    factTreasuryLabel: "Treasury:",
    // -- footer --
    footerMarketLabel: "KongMarket:",
    footerSaleLabel: "KongSale:",
    footerPassLabel: "KongMintPass:",
    footerUsdtLabel: "USDT:",
    footerAbout:
      "Marketplace $KONG adalah frontend statis tanpa server — semua data dibaca langsung dari BNB Chain. Kontrak market belum di-deploy; halaman ini akan aktif otomatis setelah deploy mainnet.",
    footerNote:
      "Bukan nasihat keuangan. $KONG tidak punya nilai yang dijamin; pasar secondary bisa sepi dan harga bisa bergerak cepat. Satu-satunya jaminan di kontrak adalah refund 100% USDT bila sale tidak terjual habis. Selalu periksa alamat kontrak di wallet sebelum menyetujui transaksi apa pun.",
    // -- wallet / jaringan (JS) --
    walletNotFound:
      "Wallet tidak ditemukan. Pasang MetaMask atau Binance Wallet, lalu muat ulang halaman ini.",
    disconnectBtn: "Putuskan",
    connectBtn: "Hubungkan wallet",
    networkOk: "BSC · Chain 56",
    networkWrong: "Jaringan salah (chain {chain})",
    rpcAllFailed: "Semua endpoint RPC BSC gagal.",
    // -- status sale (JS) --
    saleLoadFailed:
      "Tidak bisa membaca status sale dari BNB Chain. Periksa koneksi Anda — halaman mencoba lagi otomatis.",
    salePhaseLoading: "Memuat…",
    salePhaseUpcoming: "Segera dibuka",
    salePhaseLive: "Sale aktif",
    salePhaseSoldout: "Terjual habis — menunggu graduation",
    salePhaseGraduated: "Graduated",
    salePhaseRefund: "Jendela refund dibuka",
    salePhaseEnded: "Berakhir",
    // -- kurs (JS) --
    ratesNoteLive:
      "Kurs live (Binance US): 1 BNB ≈ {bnbUsdt} USDT.",
    ratesNoteFallback:
      "Kurs acuan 19 Nov 2026 (API harga tidak tersedia): 1 BNB ≈ {bnbUsdt} USDT.",
    // -- listing (JS) --
    marketNotDeployedNote:
      "Listing akan muncul di sini setelah kontrak market di-deploy dan ada pass yang di-listing.",
    marketNotDeployedEmpty:
      "Marketplace belum dibuka — kontrak market belum di-deploy ke mainnet. Deploy dijadwalkan setelah sale dibuka 1 Desember 2026 dan pass pertama ada.",
    loadingListings: "Memuat listing dari blockchain…",
    listingsLoadFailed: "Listing tidak bisa dimuat: {err} Coba muat ulang dengan tombol di atas.",
    noListings: "Belum ada listing.",
    showingListings: "Menampilkan {shown} dari {total} listing aktif.",
    staleHidden:
      "{n} listing disembunyikan karena sudah tidak valid (pass diklaim/dipindah atau approval dicabut).",
    rpcFallbackNote:
      "Data listing diambil lewat RPC (BscScan tidak bisa dijangkau) — bisa lebih lambat.",
    noListingsYet:
      "Belum ada pass yang di-listing. Jadilah yang pertama — hubungkan wallet dan list pass Anda di bawah.",
    noFilterMatch: "Tidak ada listing yang cocok dengan filter ini.",
    claimValue: "Klaim {value} setelah graduation",
    sellerLabel: "Penjual: {addr}",
    splitLine: "Pembagian: penjual 94% · royalti 5% ke treasury · fee market 1%",
    viewBscScan: "Lihat di BscScan",
    listingUnverified:
      "Listing ini belum bisa diverifikasi (RPC tidak menjawab) — tombol Beli dinonaktifkan sampai verifikasi berhasil.",
    connectToBuy: "Hubungkan wallet untuk membeli.",
    ownListingHint: "Ini listing Anda — kelola di bagian “Pass saya”.",
    buyBtn: "Beli",
    listingStale: "Listing Pass #{id} sudah tidak valid: {reason} Daftar listing dimuat ulang.",
    cannotVerifyNow: "tidak bisa diverifikasi saat ini.",
    verifyFailed: "Gagal memeriksa listing: {err}",
    staleUnknownCurrency: "Mata uang listing tidak dikenal.",
    staleTokenGone: "Pass sudah tidak ada (dibakar/diklaim).",
    staleNotOwner: "Penjual bukan lagi pemilik pass.",
    staleApprovalRevoked: "Approval ke market sudah dicabut penjual.",
    staleChanged: "Listing di kontrak sudah berubah (harga/penjual berbeda).",
    // -- konfirmasi beli (JS) --
    buyConfirmTitle: "Konfirmasi pembelian — Pass #{id} ({tier})",
    quotePrice: "Harga yang Anda bayar",
    quoteMaxPrice: "Batas harga maksimum (proteksi)",
    quoteSellerGets: "Penjual terima (94%)",
    quoteRoyalty: "Royalti ke treasury (5%)",
    quoteFee: "Fee marketplace (1%, ditampung)",
    quoteClaim: "Klaim setelah graduation",
    quoteSeller: "Penjual",
    payUsdtNote:
      "Pembayaran USDT: bila allowance belum cukup, Anda akan diminta menyetujui (approve) USDT sebesar harga dulu — lalu transaksi beli menyusul. Keduanya perlu konfirmasi di wallet.",
    payBnbNote:
      "Pembayaran BNB: BNB sebesar harga dikirim bersama transaksi beli — tanpa approve terpisah.",
    maxPriceWarn:
      "Pembelian dilindungi batas harga maksimum: bila harga listing berubah naik di atas harga di atas sebelum transaksi diproses, transaksi dibatalkan otomatis dan Anda tidak membayar lebih. Listing diverifikasi ulang tepat sebelum transaksi dikirim.",
    confirmBuyBtn: "Konfirmasi beli — {price}",
    cancelBtn: "Batal",
    approveUsdtPending: "Menyetujui (approve) {amount} untuk kontrak market… menunggu konfirmasi. ",
    buyingPending: "Membeli Pass #{id}… menunggu konfirmasi. ",
    buyDone:
      "✓ Pass #{id} berhasil dibeli seharga {price}. Pass kini ada di wallet Anda. ",
    buyFailed: "✗ Pembelian gagal: {err}",
    txLabel: "Transaksi: ",
    // -- pass saya (JS) --
    walletReadFailed:
      "Tidak bisa membaca status wallet dari BNB Chain. Periksa koneksi Anda dan coba lagi.",
    myPassesLoadFailed:
      "Tidak bisa memuat pass Anda dari BNB Chain. Periksa koneksi Anda dan coba lagi.",
    connectToSeePassesNote: "Hubungkan wallet untuk melihat pass Anda dan me-listingnya.",
    connectToSeePasses: "Hubungkan wallet untuk melihat pass Anda.",
    noPassNote:
      "Anda belum memiliki Mint Pass — mint di halaman sale, atau beli di marketplace ini.",
    noMintPass: "Anda belum memiliki Mint Pass.",
    scanningPassesChain: "Memindai pass Anda dari blockchain…",
    holdingPasses:
      "Anda memegang {n} pass. Listing bersifat non-custodial: pass tetap di wallet Anda, Anda hanya memberi approval ke kontrak market — dan tetap bisa klaim/refund kapan saja.",
    holdingPassesNotDeployed:
      "Anda memegang {n} pass. Listing dibuka setelah kontrak market di-deploy.",
    listingOpensAfterDeploy: "Listing dibuka setelah kontrak market di-deploy.",
    claimValueShort: "Klaim {value}",
    claimRefundLink: "Klaim / refund di halaman mint →",
    listedPrice: "Ter-listing: {price}",
    approvalStaleWarn:
      "Perhatian: approval pass ini ke market sudah tidak berlaku — listing tidak bisa dibeli sampai Anda approve ulang.",
    reapproveBtn: "Approve ulang",
    newPriceLabel: "Harga baru ({currency})",
    floorNote: "Floor {tier}: {floor} · Harga impas: {breakeven}",
    updatePriceBtn: "Ubah harga",
    cancelListingBtn: "Batalkan listing",
    sellPriceLabel: "Harga jual",
    pricePlaceholder: "cth: 2",
    floorNoteList:
      "Floor {tier}: {floor} · Harga impas (terima bersih = harga mint): {breakeven} · Potongan per penjualan: royalti 5% + fee 1%.",
    listPassBtn: "List pass",
    invalidPrice: "Harga tidak valid — isi angka, mis. 2 atau 1,5.",
    belowFloor: "Harga di bawah floor {tier}: minimum {min}.",
    passApprovedAlready: "Pass #{id} sudah di-approve ke kontrak market.",
    approvePending: "Approve Pass #{id} ke kontrak market… menunggu konfirmasi. ",
    approveDone: "✓ Pass #{id} sudah di-approve ke kontrak market. Listing Anda kini bisa dibeli. ",
    approveFailed: "✗ Approve gagal: {err}",
    listingPending: "Listing Pass #{id} seharga {price}… menunggu konfirmasi. ",
    listingDone:
      "✓ Pass #{id} ter-listing seharga {price}. Anda tetap memegang pass dan bisa klaim/refund kapan saja. ",
    listingFailed: "✗ Listing gagal: {err}",
    updatePricePending: "Mengubah harga Pass #{id} menjadi {price}… menunggu konfirmasi. ",
    updatePriceDone: "✓ Harga Pass #{id} diubah menjadi {price}. ",
    updatePriceFailed: "✗ Ubah harga gagal: {err}",
    cancelConfirm:
      "Batalkan listing Pass #{id}? Pass tetap di wallet Anda; pembatalan hanya menghapus listing (biaya gas saja).",
    cancelPending: "Membatalkan listing Pass #{id}… menunggu konfirmasi. ",
    cancelDone: "✓ Listing Pass #{id} dibatalkan. Pass tetap di wallet Anda. ",
    cancelFailed: "✗ Pembatalan gagal: {err}",
    // -- pesan error (JS) --
    errWrongNetwork:
      "Wallet Anda tidak di BNB Smart Chain (chain 56). Pindah jaringan dan coba lagi.",
    errListingStale:
      "Listing ini sudah tidak valid (pass dipindah, diklaim, atau approval dicabut).",
    errSelfPurchase: "Anda tidak bisa membeli listing Anda sendiri.",
    errDeployBlockMissing:
      "Blok deploy kontrak market belum diisi di konfigurasi — fallback RPC tidak bisa berjalan.",
    errUserRejected: "Transaksi ditolak di wallet. Tidak ada yang terkirim.",
    errInsufficientFunds: "BNB di wallet tidak cukup untuk gas (atau untuk pembayaran BNB).",
    errNoListing: "Listing tidak ditemukan — mungkin sudah terjual atau dibatalkan.",
    errNotSeller: "Hanya penjual yang bisa mengubah atau membatalkan listing ini.",
    errBelowFloor: "Harga di bawah floor tier pass ini.",
    errNotPassOwner: "Wallet ini bukan pemilik pass tersebut.",
    errOwnershipChanged: "Pass sudah berpindah pemilik sejak di-listing — listing ini sudah basi.",
    errNotApproved: "Pass belum di-approve ke kontrak market.",
    errIncorrectValue: "Jumlah BNB yang dikirim tidak tepat sama dengan harga listing.",
    errValueNotAllowed: "Pembelian USDT tidak boleh mengirim BNB.",
    errInvalidPrice: "Harga tidak valid.",
    errInvalidPaymentToken: "Mata uang pembayaran tidak valid (hanya USDT atau BNB).",
    errNotTreasury: "Hanya treasury yang bisa menarik fee yang terkumpul.",
    errNothingToSweep: "Tidak ada fee yang terkumpul untuk ditarik.",
    errPriceAboveMax:
      "Harga listing berubah sebelum transaksi diproses — pembelian dibatalkan otomatis oleh proteksi batas harga. Muat ulang listing dan coba lagi.",
    errAllowance:
      "Kontrak market belum di-approve untuk memakai USDT sebesar itu. Approve dulu, lalu beli.",
    errUsdtBalance: "Saldo USDT di wallet tidak cukup untuk pembelian ini.",
    errNoToken: "Pass tersebut sudah tidak ada (dibakar saat klaim/refund).",
    errNetwork: "Tidak bisa menjangkau BNB Chain. Periksa koneksi Anda dan coba lagi.",
    errGeneric: "Terjadi kesalahan. Silakan coba lagi.",
    // -- info statis (JS) --
    marketLabel: "KongMarket: ",
    marketNotDeployedLine:
      "KongMarket: belum di-deploy — alamat resmi akan tampil di sini setelah deploy mainnet.",
    notDeployedShort: "Belum di-deploy",
  },

  en: {
    // -- meta / header --
    pageTitle: "Marketplace $KONG — Kong Mint Pass",
    metaDescription:
      "Marketplace $KONG — buy and sell Kong Mint Pass on BNB Chain. Pay in USDT or BNB, royalty 5% to treasury, market fee 1%. Non-custodial: the pass stays in the seller's wallet.",
    ogDescription:
      "Buy and sell Kong Mint Pass (1 pass = 1 $KONG share). Pay in USDT or BNB. Floor = mint price per tier.",
    brandSub: "Buy and sell Kong Mint Pass — USDT or BNB",
    mintPageBtn: "← Mint page",
    testnetDemoBtn: "Try the testnet demo",
    langSelectLabel: "Choose language",
    // -- banners --
    networkWarnStrong: "Wrong network.",
    networkWarnText:
      "Your wallet is not on BNB Smart Chain (chain 56). Buying and listing require BSC.",
    switchNetworkBtn: "Switch to BSC",
    notDeployedStrong: "Marketplace not open yet.",
    notDeployedText:
      "The market contract is not deployed to mainnet yet. Deployment is scheduled after the sale opens on 1 December 2026 and the first pass exists. This page is ready — listings will appear automatically once the contract is live.",
    // -- hero --
    heroAria: "About the marketplace",
    heroImgAlt: "Kong Mint Pass — Tier 1 Gold artwork: King Kong dressed as a secret agent",
    heroTitle: "Trade passes, no middleman.",
    heroP1:
      "Every Mint Pass is one share of the $KONG sale. Here passes can be traded before they are claimed: pay in USDT or BNB, fixed price, and funds split automatically — seller 94%, royalty 5% to treasury, marketplace fee 1%.",
    heroP2:
      "Non-custodial: the pass stays in the seller's wallet while listed. The seller can still claim or refund at any time — a listing whose pass has been claimed automatically cannot be bought.",
    heroP3:
      "Listing prices cannot go below the tier floor (same as the mint price): 1 / 1.5 / 2 USDT.",
    // -- sale status --
    saleAria: "Sale status",
    saleTitle: "Sale status",
    sharesTitle: "Shares sold",
    sharesStatus: "{sold} / {total} shares",
    raisedNoteEmpty: "Total raised: —",
    raisedNote: "Total raised: {amount} (held in escrow until graduation)",
    countdownLabelUpcoming: "Sale opens in",
    countdownLabelLive: "Sale ends in",
    countdownLabelRefund: "Refund window ends in",
    countdownLabelStatus: "Sale status",
    countdownNoteInitial: "Sale opens 1 December 2026, 00:00 WIB.",
    countdownNoteUpcoming: "Sale opens {start}. The marketplace opens after the first pass exists.",
    saleStartDate: "1 December 2026, 00:00 WIB",
    countdownNoteLive:
      "Graduation deadline: if all 10,000 shares sell before this, the sale graduates and claiming opens.",
    countdownNoteRefund:
      "The sale did not sell out — pass holders can refund 100% USDT on the mint page.",
    countdownNoteGraduated: "The pool is live — passes can be claimed for $KONG on the mint page.",
    countdownNoteSoldout: "All shares sold — graduation opens the pool and claiming.",
    countdownNoteEnded: "The sale ended without selling out and the refund window has closed.",
    refundLabel: "Refund window",
    refundNoteInitial: "The 100% refund only opens if the sale does not sell out.",
    refundNote:
      "The 100% refund only opens if the sale does not sell out. The refund window closes {date}.",
    refundNoteActive:
      "100% USDT refund — burn your pass on the mint page before this window closes.",
    countdownGraduated: "Graduated ✓",
    countdownSoldout: "Sold out",
    durationZero: "0 sec",
    durationDays: {
      one: "{d} day",
      other: "{d} days",
    },
    durationHours: "{h} hr",
    durationMin: "{m} min",
    durationSec: "{s} sec",
    // -- listings (static) --
    listingsAria: "Listings",
    listingsTitle: "Listings",
    refreshListingsBtn: "Reload listings",
    listingsIntro:
      "Every listing is verified live before it is shown: the seller still owns the pass, the approval to the market is still valid, and the on-chain listing still matches. Listings that are no longer valid are hidden.",
    filterTier: "Tier",
    filterAllTiers: "All tiers",
    filterCurrency: "Currency",
    filterAll: "All",
    filterSort: "Sort by price",
    sortAsc: "Cheapest first",
    sortDesc: "Most expensive first",
    // -- my passes (static) --
    myPassesAria: "My passes",
    myPassesTitle: "My passes",
    scanningPasses: "Scanning your passes…",
    // -- how it works --
    howAria: "How it works",
    howTitle: "How it works",
    howListVerb: "List",
    howListText:
      " — approve the market contract for your pass, then set a price (USDT or BNB). The price cannot go below the tier floor. The pass stays in your wallet.",
    howBuyVerb: "Buy",
    howBuyText:
      " — for USDT listings, approve USDT for the price first; for BNB listings, BNB is sent with the buy transaction. Funds split automatically in one transaction: seller 94%, royalty 5% to treasury, fee 1% held in the market contract. Purchases are protected by a maximum price: if the listing price rises above the displayed price before the transaction is processed, the transaction is cancelled automatically.",
    howUpdateVerb: "Change / cancel",
    howUpdateText:
      " — the seller can change the price or cancel the listing at any time (gas only).",
    howClaimVerb: "Claim / refund",
    howClaimText:
      " — owners can claim (after graduation) or refund (if the sale fails) at any time, even while the pass is listed. A listing whose pass has been burned automatically cannot be bought.",
    floorTableTitle: "Price floor per tier",
    thTier: "Tier",
    thFloorUsdt: "USDT floor",
    thFloorBnb: "BNB floor (estimated)",
    thBreakeven: "Breakeven price*",
    tier1Usdt: "1 USDT",
    tier1Bnb: "~0.0017 BNB",
    tier1Be: "1.064 USDT",
    tier2Usdt: "1.5 USDT",
    tier2Bnb: "~0.00254 BNB",
    tier2Be: "1.596 USDT",
    tier3Usdt: "2 USDT",
    tier3Bnb: "~0.00339 BNB",
    tier3Be: "2.128 USDT",
    breakevenNote:
      "* Breakeven price: the sale price at which the seller nets exactly the mint price after the 6% cut (royalty 5% + fee 1%). The final BNB floor is set at deploy based on the BNB price then.",
    splitTableTitle: "Split example — a 2 USDT sale",
    thPart: "Part",
    thAmount: "Amount",
    thReceiver: "Receiver",
    splitRoyalty: "Royalty",
    splitRoyaltyAmt: "0.10 USDT",
    splitRoyaltyTo: "Treasury",
    splitFee: "Marketplace fee",
    splitFeeAmt: "0.02 USDT",
    splitFeeTo: "Held in the market contract",
    splitSeller: "Seller receives",
    splitSellerAmt: "1.88 USDT",
    splitSellerTo: "Seller",
    approvalWarnStrong: "Beware fake approvals.",
    approvalWarnText:
      "Only approve the official market contract address below. Never approve any other contract claiming to be the KONG marketplace — a fake approval can move your pass.",
    factPassLabel: "KongMintPass:",
    factSaleLabel: "KongSale:",
    factUsdtLabel: "USDT (BSC, 18 decimals):",
    factTreasuryLabel: "Treasury:",
    // -- footer --
    footerMarketLabel: "KongMarket:",
    footerSaleLabel: "KongSale:",
    footerPassLabel: "KongMintPass:",
    footerUsdtLabel: "USDT:",
    footerAbout:
      "The $KONG Marketplace is a static frontend with no server — all data is read directly from BNB Chain. The market contract is not deployed yet; this page will activate automatically after the mainnet deploy.",
    footerNote:
      "Not financial advice. $KONG has no guaranteed value; the secondary market can be thin and prices can move fast. The only guarantee in the contract is a 100% USDT refund if the sale does not sell out. Always check the contract address in your wallet before approving any transaction.",
    // -- wallet / network (JS) --
    walletNotFound: "No wallet found. Install MetaMask or Binance Wallet, then reload this page.",
    disconnectBtn: "Disconnect",
    connectBtn: "Connect wallet",
    networkOk: "BSC · Chain 56",
    networkWrong: "Wrong network (chain {chain})",
    rpcAllFailed: "All BSC RPC endpoints failed.",
    // -- sale status (JS) --
    saleLoadFailed:
      "Could not read the sale status from BNB Chain. Check your connection — the page retries automatically.",
    salePhaseLoading: "Loading…",
    salePhaseUpcoming: "Opening soon",
    salePhaseLive: "Sale live",
    salePhaseSoldout: "Sold out — awaiting graduation",
    salePhaseGraduated: "Graduated",
    salePhaseRefund: "Refund window open",
    salePhaseEnded: "Ended",
    // -- rates (JS) --
    ratesNoteLive:
      "Live rate (Binance US): 1 BNB ≈ {bnbUsdt} USDT.",
    ratesNoteFallback:
      "Reference rate of 19 Nov 2026 (price API unavailable): 1 BNB ≈ {bnbUsdt} USDT.",
    // -- listings (JS) --
    marketNotDeployedNote:
      "Listings will appear here after the market contract is deployed and passes are listed.",
    marketNotDeployedEmpty:
      "The marketplace is not open yet — the market contract is not deployed to mainnet. Deployment is scheduled after the sale opens on 1 December 2026 and the first pass exists.",
    loadingListings: "Loading listings from the blockchain…",
    listingsLoadFailed: "Listings could not be loaded: {err} Try reloading with the button above.",
    noListings: "No listings yet.",
    showingListings: "Showing {shown} of {total} active listings.",
    staleHidden: {
      one: "1 listing is hidden because it is no longer valid (pass claimed/moved or approval revoked).",
      other: "{n} listings are hidden because they are no longer valid (pass claimed/moved or approval revoked).",
    },
    rpcFallbackNote: "Listing data was fetched via RPC (BscScan unreachable) — it may be slower.",
    noListingsYet:
      "No passes are listed yet. Be the first — connect your wallet and list your pass below.",
    noFilterMatch: "No listings match this filter.",
    claimValue: "Claim {value} after graduation",
    sellerLabel: "Seller: {addr}",
    splitLine: "Split: seller 94% · royalty 5% to treasury · market fee 1%",
    viewBscScan: "View on BscScan",
    listingUnverified:
      "This listing could not be verified yet (RPC not responding) — the Buy button is disabled until verification succeeds.",
    connectToBuy: "Connect your wallet to buy.",
    ownListingHint: "This is your listing — manage it in the “My passes” section.",
    buyBtn: "Buy",
    listingStale:
      "Listing for Pass #{id} is no longer valid: {reason} The listing list has been reloaded.",
    cannotVerifyNow: "cannot be verified right now.",
    verifyFailed: "Failed to check the listing: {err}",
    staleUnknownCurrency: "Unknown listing currency.",
    staleTokenGone: "The pass no longer exists (burned/claimed).",
    staleNotOwner: "The seller no longer owns the pass.",
    staleApprovalRevoked: "The approval to the market was revoked by the seller.",
    staleChanged: "The on-chain listing has changed (different price/seller).",
    // -- buy confirmation (JS) --
    buyConfirmTitle: "Confirm purchase — Pass #{id} ({tier})",
    quotePrice: "Price you pay",
    quoteMaxPrice: "Maximum price limit (protection)",
    quoteSellerGets: "Seller receives (94%)",
    quoteRoyalty: "Royalty to treasury (5%)",
    quoteFee: "Marketplace fee (1%, held)",
    quoteClaim: "Claimable after graduation",
    quoteSeller: "Seller",
    payUsdtNote:
      "USDT payment: if your allowance is not enough yet, you will first be asked to approve USDT for the price — then the buy transaction follows. Both need confirmation in your wallet.",
    payBnbNote:
      "BNB payment: BNB for the price is sent with the buy transaction — no separate approval.",
    maxPriceWarn:
      "Your purchase is protected by a maximum price: if the listing price rises above the price above before the transaction is processed, the transaction is cancelled automatically and you do not pay more. The listing is re-verified right before the transaction is sent.",
    confirmBuyBtn: "Confirm buy — {price}",
    cancelBtn: "Cancel",
    approveUsdtPending:
      "Approving (approve) {amount} for the market contract… waiting for confirmation. ",
    buyingPending: "Buying Pass #{id}… waiting for confirmation. ",
    buyDone: "✓ Pass #{id} bought for {price}. The pass is now in your wallet. ",
    buyFailed: "✗ Purchase failed: {err}",
    txLabel: "Transaction: ",
    // -- my passes (JS) --
    walletReadFailed:
      "Could not read your wallet status from BNB Chain. Check your connection and try again.",
    myPassesLoadFailed:
      "Could not load your passes from BNB Chain. Check your connection and try again.",
    connectToSeePassesNote: "Connect your wallet to see your passes and list them.",
    connectToSeePasses: "Connect your wallet to see your passes.",
    noPassNote:
      "You don't have a Mint Pass yet — mint one on the sale page, or buy one in this marketplace.",
    noMintPass: "You do not own a Mint Pass yet.",
    scanningPassesChain: "Scanning your passes from the blockchain…",
    holdingPasses: {
      one: "You hold 1 pass. Listings are non-custodial: the pass stays in your wallet; you only approve the market contract — and you can still claim/refund at any time.",
      other: "You hold {n} passes. Listings are non-custodial: passes stay in your wallet; you only approve the market contract — and you can still claim/refund at any time.",
    },
    holdingPassesNotDeployed: {
      one: "You hold 1 pass. Listing opens after the market contract is deployed.",
      other: "You hold {n} passes. Listing opens after the market contract is deployed.",
    },
    listingOpensAfterDeploy: "Listing opens after the market contract is deployed.",
    claimValueShort: "Claim {value}",
    claimRefundLink: "Claim / refund on the mint page →",
    listedPrice: "Listed: {price}",
    approvalStaleWarn:
      "Warning: the approval of this pass to the market is no longer valid — the listing cannot be bought until you approve again.",
    reapproveBtn: "Approve again",
    newPriceLabel: "New price ({currency})",
    floorNote: "{tier} floor: {floor} · Breakeven price: {breakeven}",
    updatePriceBtn: "Change price",
    cancelListingBtn: "Cancel listing",
    sellPriceLabel: "Sale price",
    pricePlaceholder: "e.g. 2",
    floorNoteList:
      "{tier} floor: {floor} · Breakeven price (net received = mint price): {breakeven} · Cut per sale: royalty 5% + fee 1%.",
    listPassBtn: "List pass",
    invalidPrice: "Invalid price — enter a number, e.g. 2 or 1.5.",
    belowFloor: "Price below the {tier} floor: minimum {min}.",
    passApprovedAlready: "Pass #{id} is already approved to the market contract.",
    approvePending: "Approving Pass #{id} to the market contract… waiting for confirmation. ",
    approveDone:
      "✓ Pass #{id} is approved to the market contract. Your listing can now be bought. ",
    approveFailed: "✗ Approval failed: {err}",
    listingPending: "Listing Pass #{id} for {price}… waiting for confirmation. ",
    listingDone:
      "✓ Pass #{id} is listed for {price}. You keep holding the pass and can claim/refund at any time. ",
    listingFailed: "✗ Listing failed: {err}",
    updatePricePending: "Changing the price of Pass #{id} to {price}… waiting for confirmation. ",
    updatePriceDone: "✓ The price of Pass #{id} is now {price}. ",
    updatePriceFailed: "✗ Changing the price failed: {err}",
    cancelConfirm:
      "Cancel the listing for Pass #{id}? The pass stays in your wallet; cancelling only removes the listing (gas only).",
    cancelPending: "Cancelling the listing for Pass #{id}… waiting for confirmation. ",
    cancelDone: "✓ The listing for Pass #{id} is cancelled. The pass stays in your wallet. ",
    cancelFailed: "✗ Cancellation failed: {err}",
    // -- error messages (JS) --
    errWrongNetwork:
      "Your wallet is not on BNB Smart Chain (chain 56). Switch networks and try again.",
    errListingStale: "This listing is no longer valid (pass moved, claimed, or approval revoked).",
    errSelfPurchase: "You cannot buy your own listing.",
    errDeployBlockMissing:
      "The market contract's deploy block is not set in the configuration — the RPC fallback cannot run.",
    errUserRejected: "Transaction rejected in the wallet. Nothing was sent.",
    errInsufficientFunds: "Not enough BNB in the wallet for gas (or for a BNB payment).",
    errNoListing: "Listing not found — it may already be sold or cancelled.",
    errNotSeller: "Only the seller can change or cancel this listing.",
    errBelowFloor: "Price below this pass tier's floor.",
    errNotPassOwner: "This wallet does not own that pass.",
    errOwnershipChanged: "The pass changed owners since it was listed — this listing is stale.",
    errNotApproved: "The pass is not approved to the market contract yet.",
    errIncorrectValue: "The BNB sent does not exactly match the listing price.",
    errValueNotAllowed: "A USDT purchase must not send BNB.",
    errInvalidPrice: "Invalid price.",
    errInvalidPaymentToken: "Invalid payment currency (USDT or BNB only).",
    errNotTreasury: "Only the treasury can withdraw the accumulated fees.",
    errNothingToSweep: "There are no accumulated fees to withdraw.",
    errPriceAboveMax:
      "The listing price changed before the transaction was processed — the purchase was cancelled automatically by the max-price protection. Reload the listings and try again.",
    errAllowance:
      "The market contract is not approved to use that much USDT yet. Approve first, then buy.",
    errUsdtBalance: "Your USDT balance is not enough for this purchase.",
    errNoToken: "That pass no longer exists (burned when claimed/refunded).",
    errNetwork: "Could not reach BNB Chain. Check your connection and try again.",
    errGeneric: "Something went wrong. Please try again.",
    // -- static info (JS) --
    marketLabel: "KongMarket: ",
    marketNotDeployedLine:
      "KongMarket: not deployed yet — the official address will appear here after the mainnet deploy.",
    notDeployedShort: "Not deployed",
  },

  zh: {
    // -- 元信息 / 页眉 --
    pageTitle: "$KONG 市场——Kong Mint 通行证",
    metaDescription:
      "$KONG 市场——在 BNB Chain 买卖 Kong Mint 通行证。支持 USDT 或 BNB 支付，版税 5% 归财库，市场手续费 1%。非托管：通行证仍在卖家钱包中。",
    ogDescription: "买卖 Kong Mint 通行证（1 个通行证 = 1 份 $KONG）。支持 USDT 或 BNB 支付。底价 = 各等级铸造价。",
    brandSub: "买卖 Kong Mint 通行证——USDT 或 BNB",
    mintPageBtn: "← 铸造页",
    testnetDemoBtn: "体验测试网演示",
    langSelectLabel: "选择语言",
    // -- 横幅 --
    networkWarnStrong: "网络错误。",
    networkWarnText: "您的钱包不在 BNB 智能链（链 56）。购买和上架需要 BSC。",
    switchNetworkBtn: "切换到 BSC",
    notDeployedStrong: "市场尚未开放。",
    notDeployedText: "市场合约尚未部署到主网。计划在发售于 2026 年 12 月 1 日开启且首个通行证出现后部署。本页已就绪——合约上线后挂单将自动出现。",
    // -- 主视觉 --
    heroAria: "关于市场",
    heroImgAlt: "Kong Mint 通行证——一级金卡艺术图：化装成特工的金刚",
    heroTitle: "买卖通行证，无需中间人。",
    heroP1:
      "每个 Mint 通行证就是一份 $KONG 发售份额。在这里，通行证可以在领取前交易：支持 USDT 或 BNB 支付，价格固定，资金自动分配——卖家 94%、版税 5% 归财库、市场手续费 1%。",
    heroP2: "非托管：挂单期间通行证仍在卖家钱包中。卖家随时仍可领取或退款——通行证已被领取的挂单将自动无法购买。",
    heroP3: "挂单价格不得低于该等级的底价（与铸造价相同）：1 / 1.5 / 2 USDT。",
    // -- 发售状态 --
    saleAria: "发售状态",
    saleTitle: "发售状态",
    sharesTitle: "已售份额",
    sharesStatus: "{sold} / {total} 份",
    raisedNoteEmpty: "已筹集：—",
    raisedNote: "已筹集：{amount}（毕业前由托管持有）",
    countdownLabelUpcoming: "发售开始倒计时",
    countdownLabelLive: "发售结束倒计时",
    countdownLabelRefund: "退款窗口关闭倒计时",
    countdownLabelStatus: "发售状态",
    countdownNoteInitial: "发售将于 2026 年 12 月 1 日 00:00 WIB 开始。",
    countdownNoteUpcoming: "发售开始于 {start}。首个通行证出现后市场开放。",
    saleStartDate: "2026年12月1日 00:00 WIB",
    countdownNoteLive: "毕业截止：若在此之前全部 10,000 份售罄，发售即毕业并开放领取。",
    countdownNoteRefund: "发售未售罄——通行证持有者可在铸造页退回 100% USDT。",
    countdownNoteGraduated: "流动性池已上线——通行证可在铸造页领取 $KONG。",
    countdownNoteSoldout: "全部份额已售罄——毕业将开放流动性池和领取。",
    countdownNoteEnded: "发售已结束且未售罄，退款窗口已关闭。",
    refundLabel: "退款窗口",
    refundNoteInitial: "仅当发售未售罄时才开放 100% 退款。",
    refundNote: "仅当发售未售罄时才开放 100% 退款。退款窗口将于 {date} 关闭。",
    refundNoteActive: "100% USDT 退款——请在窗口关闭前于铸造页销毁您的通行证。",
    countdownGraduated: "已毕业 ✓",
    countdownSoldout: "已售罄",
    durationZero: "0 秒",
    durationDays: "{d} 天",
    durationHours: "{h} 小时",
    durationMin: "{m} 分",
    durationSec: "{s} 秒",
    // -- 挂单（静态） --
    listingsAria: "挂单",
    listingsTitle: "挂单",
    refreshListingsBtn: "重新加载挂单",
    listingsIntro: "每个挂单在展示前都会实时验证：卖家仍持有该通行证、给市场的授权仍然有效、链上挂单仍然一致。不再有效的挂单会被隐藏。",
    filterTier: "等级",
    filterAllTiers: "全部等级",
    filterCurrency: "货币",
    filterAll: "全部",
    filterSort: "按价格排序",
    sortAsc: "价格从低到高",
    sortDesc: "价格从高到低",
    // -- 我的通行证（静态） --
    myPassesAria: "我的通行证",
    myPassesTitle: "我的通行证",
    scanningPasses: "正在扫描您的通行证……",
    // -- 使用方法 --
    howAria: "使用方法",
    howTitle: "使用方法",
    howListVerb: "上架",
    howListText: "——先授权市场合约使用您的通行证，然后设定价格（USDT 或 BNB）。价格不得低于该等级的底价。通行证仍在您的钱包中。",
    howBuyVerb: "购买",
    howBuyText:
      "——USDT 挂单需先授权相应金额的 USDT；BNB 挂单则随购买交易一并发送 BNB。资金在单笔交易中自动分配：卖家 94%、版税 5% 归财库、手续费 1% 暂存于市场合约。购买受最高价保护：若挂单价格在交易处理前涨至高于显示价格，交易将自动取消。",
    howUpdateVerb: "改价 / 取消",
    howUpdateText: "——卖家可随时改价或取消挂单（仅需 Gas）。",
    howClaimVerb: "领取 / 退款",
    howClaimText: "——持有者可随时领取（毕业后）或退款（发售失败时），即使通行证正在挂单中。通行证已被销毁的挂单将自动无法购买。",
    floorTableTitle: "各等级价格底价",
    thTier: "等级",
    thFloorUsdt: "USDT 底价",
    thFloorBnb: "BNB 底价（估算）",
    thBreakeven: "保本价*",
    tier1Usdt: "1 USDT",
    tier1Bnb: "~0.0017 BNB",
    tier1Be: "1.064 USDT",
    tier2Usdt: "1.5 USDT",
    tier2Bnb: "~0.00254 BNB",
    tier2Be: "1.596 USDT",
    tier3Usdt: "2 USDT",
    tier3Bnb: "~0.00339 BNB",
    tier3Be: "2.128 USDT",
    breakevenNote:
      "* 保本价：扣除 6%（版税 5% + 手续费 1%）后，卖家净收入恰好等于铸造价的售价。最终 BNB 底价在部署时根据当时 BNB 价格确定。",
    splitTableTitle: "分配示例——2 USDT 的一笔销售",
    thPart: "部分",
    thAmount: "金额",
    thReceiver: "接收方",
    splitRoyalty: "版税",
    splitRoyaltyAmt: "0.10 USDT",
    splitRoyaltyTo: "财库",
    splitFee: "市场手续费",
    splitFeeAmt: "0.02 USDT",
    splitFeeTo: "暂存于市场合约",
    splitSeller: "卖家实收",
    splitSellerAmt: "1.88 USDT",
    splitSellerTo: "卖家",
    approvalWarnStrong: "谨防虚假授权。",
    approvalWarnText: "只授权下方官方市场合约地址。切勿授权任何冒充 KONG 市场的其他合约——虚假授权可能转移您的通行证。",
    factPassLabel: "KongMintPass：",
    factSaleLabel: "KongSale：",
    factUsdtLabel: "USDT（BSC，18 位小数）：",
    factTreasuryLabel: "财库：",
    // -- 页脚 --
    footerMarketLabel: "KongMarket：",
    footerSaleLabel: "KongSale：",
    footerPassLabel: "KongMintPass：",
    footerUsdtLabel: "USDT：",
    footerAbout: "$KONG 市场是纯静态前端，没有服务器，所有数据直接从 BNB Chain 读取。市场合约尚未部署；主网部署后本页将自动激活。",
    footerNote:
      "不构成财务建议。$KONG 没有保底价值；二级市场可能冷清，价格可能快速波动。合约中唯一的保证是：若发售未售罄，可退回 100% USDT。批准任何交易前，请务必在钱包中核对合约地址。",
    // -- 钱包 / 网络（JS） --
    walletNotFound: "未找到钱包。请安装 MetaMask 或 Binance Wallet，然后重新加载本页。",
    disconnectBtn: "断开连接",
    connectBtn: "连接钱包",
    networkOk: "BSC · 链 56",
    networkWrong: "网络错误（链 {chain}）",
    rpcAllFailed: "所有 BSC RPC 节点均无响应。",
    // -- 发售状态（JS） --
    saleLoadFailed: "无法从 BNB Chain 读取发售状态。请检查网络连接——页面会自动重试。",
    salePhaseLoading: "加载中…",
    salePhaseUpcoming: "即将开始",
    salePhaseLive: "发售进行中",
    salePhaseSoldout: "已售罄——等待毕业",
    salePhaseGraduated: "已毕业",
    salePhaseRefund: "退款窗口已开放",
    salePhaseEnded: "已结束",
    // -- 汇率（JS） --
    ratesNoteLive:
      "实时汇率（Binance US）：1 BNB ≈ {bnbUsdt} USDT。",
    ratesNoteFallback:
      "2026 年 11 月 19 日参考汇率（价格 API 不可用）：1 BNB ≈ {bnbUsdt} USDT。",
    // -- 挂单（JS） --
    marketNotDeployedNote: "市场合约部署并有通行证上架后，挂单将出现在这里。",
    marketNotDeployedEmpty: "市场尚未开放——市场合约尚未部署到主网。计划在发售于 2026 年 12 月 1 日开启且首个通行证出现后部署。",
    loadingListings: "正在从区块链加载挂单……",
    listingsLoadFailed: "无法加载挂单：{err} 请使用上方按钮重新加载。",
    noListings: "暂无挂单。",
    showingListings: "显示 {shown} / {total} 个在售挂单。",
    staleHidden: "{n} 个挂单因不再有效而被隐藏（通行证已被领取/转移或授权被撤销）。",
    rpcFallbackNote: "挂单数据通过 RPC 获取（BscScan 无法访问）——可能较慢。",
    noListingsYet: "暂无通行证挂单。成为第一个——连接钱包并在下方上架您的通行证。",
    noFilterMatch: "没有符合该筛选条件的挂单。",
    claimValue: "毕业后可领取 {value}",
    sellerLabel: "卖家：{addr}",
    splitLine: "分配：卖家 94% · 版税 5% 归财库 · 市场手续费 1%",
    viewBscScan: "在 BscScan 查看",
    listingUnverified: "该挂单暂无法验证（RPC 无响应）——验证成功前购买按钮不可用。",
    connectToBuy: "连接钱包以购买。",
    ownListingHint: "这是您的挂单——请在“我的通行证”部分管理。",
    buyBtn: "购买",
    listingStale: "通行证 #{id} 的挂单已失效：{reason} 挂单列表已重新加载。",
    cannotVerifyNow: "暂时无法验证。",
    verifyFailed: "检查挂单失败：{err}",
    staleUnknownCurrency: "挂单货币未知。",
    staleTokenGone: "通行证已不存在（已销毁/已领取）。",
    staleNotOwner: "卖家已不再拥有该通行证。",
    staleApprovalRevoked: "卖家已撤销给市场的授权。",
    staleChanged: "链上挂单已变更（价格/卖家不同）。",
    // -- 购买确认（JS） --
    buyConfirmTitle: "确认购买——通行证 #{id}（{tier}）",
    quotePrice: "您需支付的价格",
    quoteMaxPrice: "最高价上限（保护）",
    quoteSellerGets: "卖家实收（94%）",
    quoteRoyalty: "版税归财库（5%）",
    quoteFee: "市场手续费（1%，暂存）",
    quoteClaim: "毕业后可领取",
    quoteSeller: "卖家",
    payUsdtNote: "USDT 支付：如授权额度不足，您将先被要求授权相应金额的 USDT，然后再发起购买交易。两者都需要在钱包中确认。",
    payBnbNote: "BNB 支付：相应金额的 BNB 随购买交易一并发送——无需单独授权。",
    maxPriceWarn: "您的购买受最高价保护：若挂单价格在交易处理前涨至高于上方价格，交易将自动取消，您不会多付。交易发送前会再次验证挂单。",
    confirmBuyBtn: "确认购买——{price}",
    cancelBtn: "取消",
    approveUsdtPending: "正在授权（approve）{amount} 给市场合约……等待确认。",
    buyingPending: "正在购买通行证 #{id}……等待确认。",
    buyDone: "✓ 通行证 #{id} 已以 {price} 成功购买。通行证已在您的钱包中。",
    buyFailed: "✗ 购买失败：{err}",
    txLabel: "交易：",
    // -- 我的通行证（JS） --
    walletReadFailed: "无法从 BNB Chain 读取您的钱包状态。请检查网络连接并重试。",
    myPassesLoadFailed: "无法从 BNB Chain 加载您的通行证。请检查网络连接并重试。",
    connectToSeePassesNote: "连接钱包以查看您的通行证并上架。",
    connectToSeePasses: "连接钱包以查看您的通行证。",
    noPassNote: "您还没有 Mint 通行证——请在发售页铸造，或在本市场购买。",
    noMintPass: "您尚未拥有 Mint 通行证。",
    scanningPassesChain: "正在从区块链扫描您的通行证……",
    holdingPasses: "您持有 {n} 个通行证。挂单是非托管的：通行证仍在您的钱包中，您只需授权市场合约——且随时仍可领取/退款。",
    holdingPassesNotDeployed: "您持有 {n} 个通行证。市场合约部署后即可上架。",
    listingOpensAfterDeploy: "市场合约部署后即可上架。",
    claimValueShort: "可领取 {value}",
    claimRefundLink: "在铸造页领取 / 退款 →",
    listedPrice: "已上架：{price}",
    approvalStaleWarn: "注意：该通行证给市场的授权已失效——重新授权前挂单无法被购买。",
    reapproveBtn: "重新授权",
    newPriceLabel: "新价格（{currency}）",
    floorNote: "{tier} 底价：{floor}· 保本价：{breakeven}",
    updatePriceBtn: "改价",
    cancelListingBtn: "取消挂单",
    sellPriceLabel: "售价",
    pricePlaceholder: "例如：2",
    floorNoteList:
      "{tier} 底价：{floor}· 保本价（净收入 = 铸造价）：{breakeven} · 每笔销售扣除：版税 5% + 手续费 1%。",
    listPassBtn: "上架通行证",
    invalidPrice: "价格无效——请输入数字，例如 2 或 1.5。",
    belowFloor: "价格低于 {tier} 底价：最低 {min}。",
    passApprovedAlready: "通行证 #{id} 已授权给市场合约。",
    approvePending: "正在授权通行证 #{id} 给市场合约……等待确认。",
    approveDone: "✓ 通行证 #{id} 已授权给市场合约。您的挂单现在可以被购买了。",
    approveFailed: "✗ 授权失败：{err}",
    listingPending: "正在以 {price} 上架通行证 #{id}……等待确认。",
    listingDone: "✓ 通行证 #{id} 已以 {price} 上架。通行证仍由您持有，且随时可以领取/退款。",
    listingFailed: "✗ 上架失败：{err}",
    updatePricePending: "正在将通行证 #{id} 的价格改为 {price}……等待确认。",
    updatePriceDone: "✓ 通行证 #{id} 的价格已改为 {price}。",
    updatePriceFailed: "✗ 改价失败：{err}",
    cancelConfirm: "取消通行证 #{id} 的挂单？通行证仍在您的钱包中；取消仅删除挂单（仅需 Gas）。",
    cancelPending: "正在取消通行证 #{id} 的挂单……等待确认。",
    cancelDone: "✓ 通行证 #{id} 的挂单已取消。通行证仍在您的钱包中。",
    cancelFailed: "✗ 取消失败：{err}",
    // -- 错误信息（JS） --
    errWrongNetwork: "您的钱包不在 BNB 智能链（链 56）。请切换网络后重试。",
    errListingStale: "该挂单已失效（通行证被转移、领取或授权被撤销）。",
    errSelfPurchase: "您不能购买自己的挂单。",
    errDeployBlockMissing: "配置中未填写市场合约的部署区块——RPC 备用方案无法运行。",
    errUserRejected: "交易在钱包中被拒绝。没有任何交易发出。",
    errInsufficientFunds: "钱包中的 BNB 不足以支付 Gas（或 BNB 付款）。",
    errNoListing: "未找到挂单——可能已售出或已取消。",
    errNotSeller: "只有卖家可以修改或取消该挂单。",
    errBelowFloor: "价格低于该通行证等级的底价。",
    errNotPassOwner: "该钱包并不拥有此通行证。",
    errOwnershipChanged: "该通行证自上架以来已更换主人——此挂单已失效。",
    errNotApproved: "通行证尚未授权给市场合约。",
    errIncorrectValue: "发送的 BNB 金额与挂单价格不完全一致。",
    errValueNotAllowed: "USDT 购买不得发送 BNB。",
    errInvalidPrice: "价格无效。",
    errInvalidPaymentToken: "支付货币无效（仅支持 USDT 或 BNB）。",
    errNotTreasury: "只有财库可以提取已累积的手续费。",
    errNothingToSweep: "没有可提取的已累积手续费。",
    errPriceAboveMax: "挂单价格在交易处理前发生了变化——购买已被最高价保护自动取消。请重新加载挂单后重试。",
    errAllowance: "市场合约尚未获得使用该金额 USDT 的授权。请先授权，再购买。",
    errUsdtBalance: "您的 USDT 余额不足以完成本次购买。",
    errNoToken: "该通行证已不存在（领取/退款时已销毁）。",
    errNetwork: "无法连接 BNB Chain。请检查网络连接并重试。",
    errGeneric: "发生错误。请重试。",
    // -- 静态信息（JS） --
    marketLabel: "KongMarket：",
    marketNotDeployedLine: "KongMarket：尚未部署——主网部署后官方地址将显示在这里。",
    notDeployedShort: "未部署",
  },
};

// ---------------------------------------------------------------------------
// State bahasa + helper
// ---------------------------------------------------------------------------

let currentLang = DEFAULT_LANG;

export function getLang() {
  return currentLang;
}

/** Locale angka untuk bahasa aktif (dipakai fmtInt/fmtUsdt/dst.). */
export function numLocale() {
  return NUM_LOCALES[currentLang];
}

/** Ambil string terjemahan; {nama} diganti dari `vars`.
 *  Bila nilainya objek {one, other}, pilih bentuk tunggal saat n === 1.
 *  Fallback: bahasa aktif -> id -> kunci itu sendiri (tidak pernah
 *  mengembalikan undefined, supaya UI tidak pernah menampilkan "undefined"). */
export function t(key, vars = {}) {
  let value = I18N[currentLang]?.[key] ?? I18N[DEFAULT_LANG]?.[key] ?? key;
  if (value && typeof value === "object") {
    value = vars.n === 1 ? value.one ?? value.other : value.other ?? value.one;
  }
  return String(value).replace(/\{(\w+)\}/g, (_, name) =>
    vars[name] === undefined ? `{${name}}` : String(vars[name])
  );
}

function readStoredLang() {
  try {
    if (typeof window !== "undefined" && window.localStorage) {
      const stored = window.localStorage.getItem(STORAGE_KEY);
      if (stored && LANGS.includes(stored)) return stored;
    }
  } catch {
    // Mode privat dll. — pakai bahasa bawaan.
  }
  return DEFAULT_LANG;
}

function applyDocumentLang() {
  if (typeof document !== "undefined") {
    document.documentElement.lang = HTML_LANG[currentLang];
  }
}

/** Baca preferensi tersimpan (dipanggil sekali saat init). */
export function initLang() {
  currentLang = readStoredLang();
  applyDocumentLang();
  return currentLang;
}

/** Ganti bahasa aktif + simpan preferensi. Mengembalikan true bila berubah. */
export function setLang(lang) {
  if (!LANGS.includes(lang) || lang === currentLang) return false;
  currentLang = lang;
  try {
    if (typeof window !== "undefined" && window.localStorage) {
      window.localStorage.setItem(STORAGE_KEY, lang);
    }
  } catch {
    // Mode privat dll. — bahasa tetap berubah untuk sesi ini.
  }
  applyDocumentLang();
  return true;
}

/** Terapkan terjemahan ke elemen statis HTML:
 *  - data-i18n="kunci"            -> textContent = t(kunci)
 *  - data-i18n-attr="attr:kunci"  -> setAttribute(attr, t(kunci));
 *    beberapa pasangan dipisah koma, mis. "aria-label:heroAria,alt:heroImgAlt".
 *  Elemen dengan data-i18n HARUS berisi teks murni (tanpa anak elemen
 *  interaktif) — textContent menimpa seluruh isi elemen. */
export function applyStaticI18n() {
  if (typeof document === "undefined") return;
  for (const el of document.querySelectorAll("[data-i18n]")) {
    el.textContent = t(el.getAttribute("data-i18n"));
  }
  for (const el of document.querySelectorAll("[data-i18n-attr]")) {
    for (const pair of el.getAttribute("data-i18n-attr").split(",")) {
      const [attr, key] = pair.split(":").map((s) => s.trim());
      if (attr && key) el.setAttribute(attr, t(key));
    }
  }
}
