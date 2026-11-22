// i18n — halaman demo testnet marketplace $KONG (/market-testnet).
//
// Tiga bahasa: id (bawaan), en, zh. Semua teks antarmuka (statis di
// index.html maupun dinamis di market-testnet.js) hidup di kamus I18N
// di bawah; tidak ada lagi string Bahasa Indonesia hardcoded di kode UI.
//
// Cara pakai:
//   t("connectBtn")                    -> "Hubungkan wallet" / "Connect wallet" / "连接钱包"
//   t("passRemaining", { n: 29 })      -> interpolasi {n}; bila nilainya
//                                        objek {one, other}, pilih bentuk
//                                        tunggal bila n === 1.
//   setLang("en")                      -> ganti bahasa + simpan preferensi
//                                        (localStorage kong-testnet:lang)
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
const STORAGE_KEY = "kong-testnet:lang";
const NUM_LOCALES = { id: "id-ID", en: "en-US", zh: "zh-CN" };
const HTML_LANG = { id: "id", en: "en", zh: "zh-CN" };

export const I18N = {
  id: {
    // -- meta / header --
    pageTitle: "Marketplace $KONG — Demo Testnet",
    metaDescription:
      "Marketplace $KONG — DEMO TESTNET. Coba jual beli Kong Mint Pass di BSC Testnet tanpa uang sungguhan: klaim test pass gratis, mint test USDT, lalu list dan beli.",
    ogDescription:
      "Coba marketplace Kong Mint Pass di BSC Testnet: test pass gratis, test USDT gratis, tanpa uang sungguhan.",
    brandSub: "Demo testnet — BSC Testnet (chain 97), tanpa uang sungguhan",
    mainnetMarketBtn: "Marketplace mainnet →",
    langSelectLabel: "Pilih bahasa",

    // -- banner --
    warnBannerStrong: "DEMO TESTNET — semua token di halaman ini tidak bernilai.",
    warnBannerText:
      "tBNB, test USDT, dan test pass di sini hanya untuk mencoba alur marketplace (list / beli / ubah harga / batal). Tidak ada sale, graduation, klaim $KONG, atau refund di testnet. Jangan kirim aset mainnet ke alamat testnet mana pun.",
    networkWarnStrong: "Jaringan salah.",
    networkWarnText:
      "Wallet Anda tidak di BSC Testnet (chain 97). Membeli dan me-listing di demo ini butuh BSC Testnet.",
    switchNetworkBtn: "Pindah ke BSC Testnet",
    notDeployedStrong: "Marketplace belum dibuka.",
    notDeployedText:
      "Kontrak market belum di-deploy. Halaman ini akan aktif otomatis setelah kontrak aktif.",

    // -- hero --
    heroAria: "Tentang demo testnet",
    heroImgAlt:
      "Kong Mint Pass — artwork Tier 1 Gold: King Kong berpakaian agen rahasia",
    heroTitle: "Coba marketplace-nya, gratis.",
    heroP1: "Demo ini memakai kontrak marketplace $KONG yang sama persis dengan versi mainnet — hanya saja berjalan di BSC Testnet dengan token test. Ambil tBNB dari faucet, mint test USDT, klaim satu test pass gratis, lalu coba jual beli seperti di mainnet nanti.",
    heroP2: "Non-custodial: pass tetap di wallet penjual selama ter-listing. Dana terbagi otomatis — penjual 94%, royalti 5% ke treasury, fee marketplace 1%.",
    heroP3: "Harga listing tidak boleh di bawah floor tier-nya (sama dengan harga mint): 1 / 1,5 / 2 test USDT.",

    // -- token test --
    testTokensAria: "Token test",
    testTokensTitle: "Token test — 3 langkah sebelum mencoba",
    step1Title: "1. tBNB (gas)",
    step1Note:
      "Klaim tBNB gratis di faucet resmi BNB Chain. Syarat faucet: alamat Anda harus punya saldo mainnet ≥0,002 BNB + selesaikan captcha.",
    faucetBtn: "Buka faucet tBNB →",
    step2Title: "2. Test USDT",
    step2Note:
      "Test USDT di-mint langsung dari kontrak mock (publik, siapa pun boleh). 100 test USDT per klik — cukup untuk banyak percobaan beli.",
    mintUsdtBtn: "Mint 100 test USDT",
    step3Title: "3. Test pass",
    step3NotePrefix: "Satu test pass gratis per wallet dari dispenser. ",
    step3NoteSuffix: " · Tier-nya acak (Gold / Silver / Bronze).",

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
    ratesNote:
      "Semua harga di halaman ini dalam test USDT / tBNB — token test tanpa nilai.",

    // -- pass saya (statis) --
    myPassesAria: "Pass saya",
    myPassesTitle: "Pass saya",
    scanningPasses: "Memindai pass Anda…",

    // -- cara kerja --
    howAria: "Cara kerja",
    howTitle: "Cara kerja",
    howListVerb: "List",
    howListText:
      " — approve kontrak market atas pass Anda, lalu tentukan harga (test USDT atau tBNB). Harga tidak boleh di bawah floor tier-nya. Pass tetap di wallet Anda.",
    howBuyVerb: "Beli",
    howBuyText:
      " — untuk listing test USDT, approve test USDT sebesar harga dulu; untuk listing tBNB, tBNB dikirim bersama transaksi beli. Dana terbagi otomatis dalam satu transaksi: penjual 94%, royalti 5% ke treasury, fee 1% ditampung di kontrak market. Pembelian dilindungi batas harga maksimum: bila harga listing naik di atas harga yang ditampilkan sebelum transaksi diproses, transaksi dibatalkan otomatis.",
    howUpdateVerb: "Ubah / batal",
    howUpdateText:
      " — penjual bisa mengubah harga atau membatalkan listing kapan saja (biaya gas tBNB saja).",
    howNoClaimVerb: "Tidak ada klaim / refund di testnet",
    howNoClaimText:
      " — test pass tidak bisa diklaim menjadi $KONG dan tidak ada refund. Di mainnet nanti, pemilik bisa klaim (setelah graduation) atau refund (bila sale gagal) kapan saja, bahkan saat pass ter-listing.",
    floorTableTitle: "Floor harga per tier (testnet — sama dengan mainnet)",
    thTier: "Tier",
    thFloorUsdt: "Floor test USDT",
    thFloorBnb: "Floor tBNB (live)",
    thBreakeven: "Harga impas*",
    tier1Usdt: "1 test USDT",
    tier1Bnb: "~0,001826 tBNB",
    tier1Be: "1,064 test USDT",
    tier2Usdt: "1,5 test USDT",
    tier2Bnb: "~0,002739 tBNB",
    tier2Be: "1,596 test USDT",
    tier3Usdt: "2 test USDT",
    tier3Bnb: "~0,003652 tBNB",
    tier3Be: "2,128 test USDT",
    breakevenNote:
      "* Harga impas: harga jual agar penjual terima bersih sebesar harga mint setelah potongan 6% (royalti 5% + fee 1%). Floor tBNB mengikuti harga Chainlink secara live.",
    splitTableTitle: "Contoh pembagian — penjualan 2 test USDT",
    thPart: "Bagian",
    thAmount: "Besaran",
    thReceiver: "Penerima",
    splitRoyalty: "Royalti",
    splitRoyaltyAmt: "0,10 test USDT",
    splitRoyaltyTo: "Treasury (testnet)",
    splitFee: "Fee marketplace",
    splitFeeAmt: "0,02 test USDT",
    splitFeeTo: "Ditampung di kontrak market",
    splitSeller: "Penjual terima",
    splitSellerAmt: "1,88 test USDT",
    splitSellerTo: "Penjual",
    approvalWarnStrong: "Hati-hati approval palsu.",
    approvalWarnText:
      "Hanya approve alamat kontrak market resmi di bawah ini. Jangan pernah approve kontrak lain yang mengatasnamakan marketplace KONG — approval palsu bisa memindahkan pass Anda.",
    factPassLabel: "KongMintPass (mock testnet):",
    factUsdtLabel: "MockUSDT (testnet):",
    factDispenserLabel: "Dispenser test pass:",
    factTreasuryLabel: "Treasury (testnet):",

    // -- footer --
    footerMarketLabel: "KongMarket (testnet):",
    footerPassLabel: "KongMintPass (mock):",
    footerUsdtLabel: "MockUSDT:",
    footerDispenserLabel: "Dispenser:",
    footerAbout:
      "Demo testnet marketplace $KONG — frontend statis tanpa server, semua data dibaca langsung dari BSC Testnet. Versi mainnet (uang sungguhan) ada di ",
    footerMainnetLink: "marketplace mainnet",
    footerAboutEnd: ".",
    footerNote:
      "Bukan nasihat keuangan. Semua token di halaman ini adalah token test tanpa nilai. Selalu periksa alamat kontrak di wallet sebelum menyetujui transaksi apa pun.",

    // -- wallet / jaringan (JS) --
    walletNotFound:
      "Wallet tidak ditemukan. Pasang MetaMask atau Binance Wallet, lalu muat ulang halaman ini.",
    disconnectBtn: "Putuskan",
    connectBtn: "Hubungkan wallet",
    networkOk: "BSC Testnet · Chain 97",
    networkWrong: "Jaringan salah (chain {chain})",
    rpcAllFailed: "Semua endpoint RPC BSC gagal.",

    // -- panel testnet (JS) --
    passRemaining: "{n} pass tersisa",
    connectToSeeBalance: "Hubungkan wallet untuk melihat saldo.",
    connectToClaimPass: "Hubungkan wallet untuk klaim test pass.",
    alreadyClaimedPass: "✓ Anda sudah klaim test pass (1 per wallet).",
    notClaimedPass: "Anda belum klaim test pass.",
    stockEmptyBtn: "Stok test pass habis",
    claimedBtn: "Test pass sudah diklaim",
    claimBtn: "Klaim test pass gratis",
    mintUsdtPending: "Mint 100 test USDT… menunggu konfirmasi. ",
    mintUsdtDone:
      "✓ 100 test USDT sudah masuk ke wallet Anda. Test USDT ini tidak bernilai — hanya untuk mencoba marketplace testnet. ",
    mintUsdtFailed: "✗ Mint test USDT gagal: {err}",
    claimPending: "Klaim test pass… menunggu konfirmasi. ",
    claimDoneWithId:
      "✓ Test pass #{id} sudah masuk ke wallet Anda. Sekarang Anda bisa me-listingnya di bawah. ",
    claimDone:
      "✓ Test pass sudah masuk ke wallet Anda. Cek di bagian “Pass saya”. ",
    claimFailed: "✗ Klaim test pass gagal: {err}",
    txLabel: "Transaksi: ",

    // -- listing (JS) --
    marketNotDeployedNote:
      "Listing akan muncul di sini setelah kontrak market di-deploy dan ada pass yang di-listing.",
    marketNotDeployedEmpty:
      "Marketplace testnet belum dibuka — kontrak market belum di-deploy ke BSC Testnet.",
    loadingListings: "Memuat listing dari blockchain…",
    listingsLoadFailed:
      "Listing tidak bisa dimuat: {err} Coba muat ulang dengan tombol di atas.",
    noListings: "Belum ada listing.",
    showingListings: "Menampilkan {shown} dari {total} listing aktif.",
    staleHidden:
      "{n} listing disembunyikan karena sudah tidak valid (pass diklaim/dipindah atau approval dicabut).",
    rpcFallbackNote:
      "Data listing diambil lewat RPC (BscScan tidak bisa dijangkau) — bisa lebih lambat.",
    noListingsYet:
      "Belum ada pass yang di-listing. Jadilah yang pertama — hubungkan wallet dan list pass Anda di bawah.",
    noFilterMatch: "Tidak ada listing yang cocok dengan filter ini.",
    testnetNoValue: "Testnet — token tanpa nilai",
    claimValueSim: "Nilai klaim (simulasi): {value}",
    sellerLabel: "Penjual: {addr}",
    splitLine: "Pembagian: penjual 94% · royalti 5% ke treasury · fee market 1%",
    viewBscScan: "Lihat di BscScan",
    listingUnverified:
      "Listing ini belum bisa diverifikasi (RPC tidak menjawab) — tombol Beli dinonaktifkan sampai verifikasi berhasil.",
    connectToBuy: "Hubungkan wallet untuk membeli.",
    ownListingHint: "Ini listing Anda — kelola di bagian “Pass saya”.",
    buyBtn: "Beli",
    listingStale:
      "Listing Pass #{id} sudah tidak valid: {reason} Daftar listing dimuat ulang.",
    cannotVerifyNow: "tidak bisa diverifikasi saat ini.",
    verifyFailed: "Gagal memeriksa listing: {err}",

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
    approveUsdtPending:
      "Menyetujui (approve) {amount} untuk kontrak market… menunggu konfirmasi. ",
    buyingPending: "Membeli Pass #{id}… menunggu konfirmasi. ",
    buyDone:
      "✓ Pass #{id} berhasil dibeli seharga {price}. Pass kini ada di wallet Anda. ",
    buyFailed: "✗ Pembelian gagal: {err}",

    // -- pass saya (JS) --
    walletReadFailed:
      "Tidak bisa membaca status wallet dari BSC Testnet. Periksa koneksi Anda dan coba lagi.",
    myPassesLoadFailed:
      "Tidak bisa memuat pass Anda dari BSC Testnet. Periksa koneksi Anda dan coba lagi.",
    connectToSeePassesNote:
      "Hubungkan wallet untuk melihat pass Anda dan me-listingnya.",
    connectToSeePasses: "Hubungkan wallet untuk melihat pass Anda.",
    noTestPassNote:
      "Anda belum memiliki test pass — klaim gratis di bagian “Token test” di atas, atau beli listing di marketplace ini.",
    noMintPass: "Anda belum memiliki Mint Pass.",
    scanningPassesChain: "Memindai pass Anda dari blockchain…",
    holdingPasses:
      "Anda memegang {n} test pass. Listing bersifat non-custodial: pass tetap di wallet Anda, Anda hanya memberi approval ke kontrak market — sampai terjual.",
    holdingPassesNotDeployed:
      "Anda memegang {n} pass. Listing dibuka setelah kontrak market di-deploy.",
    listingOpensAfterDeploy: "Listing dibuka setelah kontrak market di-deploy.",
    getFreeTestPass: "Dapatkan test pass gratis ↑",
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
    approveDone:
      "✓ Pass #{id} sudah di-approve ke kontrak market. Listing Anda kini bisa dibeli. ",
    approveFailed: "✗ Approve gagal: {err}",
    listingPending: "Listing Pass #{id} seharga {price}… menunggu konfirmasi. ",
    listingDone:
      "✓ Pass #{id} ter-listing seharga {price}. Anda tetap memegang pass sampai terjual. ",
    listingFailed: "✗ Listing gagal: {err}",
    updatePricePending:
      "Mengubah harga Pass #{id} menjadi {price}… menunggu konfirmasi. ",
    updatePriceDone: "✓ Harga Pass #{id} diubah menjadi {price}. ",
    updatePriceFailed: "✗ Ubah harga gagal: {err}",
    cancelConfirm:
      "Batalkan listing Pass #{id}? Pass tetap di wallet Anda; pembatalan hanya menghapus listing (biaya gas saja).",
    cancelPending: "Membatalkan listing Pass #{id}… menunggu konfirmasi. ",
    cancelDone: "✓ Listing Pass #{id} dibatalkan. Pass tetap di wallet Anda. ",
    cancelFailed: "✗ Pembatalan gagal: {err}",

    // -- pesan error (JS) --
    errWrongNetwork:
      "Wallet Anda tidak di BSC Testnet (chain 97). Pindah jaringan dan coba lagi.",
    errListingStale:
      "Listing ini sudah tidak valid (pass dipindah, diklaim, atau approval dicabut).",
    errSelfPurchase: "Anda tidak bisa membeli listing Anda sendiri.",
    errDeployBlockMissing:
      "Blok deploy kontrak market belum diisi di konfigurasi — fallback RPC tidak bisa berjalan.",
    errUserRejected: "Transaksi ditolak di wallet. Tidak ada yang terkirim.",
    errInsufficientFunds:
      "tBNB di wallet tidak cukup untuk gas (atau untuk pembayaran tBNB). Klaim tBNB gratis di faucet testnet.",
    errNoListing: "Listing tidak ditemukan — mungkin sudah terjual atau dibatalkan.",
    errNotSeller: "Hanya penjual yang bisa mengubah atau membatalkan listing ini.",
    errBelowFloor: "Harga di bawah floor tier pass ini.",
    errNotPassOwner: "Wallet ini bukan pemilik pass tersebut.",
    errOwnershipChanged:
      "Pass sudah berpindah pemilik sejak di-listing — listing ini sudah basi.",
    errNotApproved: "Pass belum di-approve ke kontrak market.",
    errIncorrectValue:
      "Jumlah BNB yang dikirim tidak tepat sama dengan harga listing.",
    errValueNotAllowed: "Pembelian USDT tidak boleh mengirim BNB.",
    errInvalidPrice: "Harga tidak valid.",
    errInvalidPaymentToken:
      "Mata uang pembayaran tidak valid (hanya USDT atau BNB).",
    errNotTreasury: "Hanya treasury yang bisa menarik fee yang terkumpul.",
    errNothingToSweep: "Tidak ada fee yang terkumpul untuk ditarik.",
    errPriceAboveMax:
      "Harga listing berubah sebelum transaksi diproses — pembelian dibatalkan otomatis oleh proteksi batas harga. Muat ulang listing dan coba lagi.",
    errAllowance:
      "Kontrak market belum di-approve untuk memakai USDT sebesar itu. Approve dulu, lalu beli.",
    errUsdtBalance: "Saldo USDT di wallet tidak cukup untuk pembelian ini.",
    errNoToken: "Pass tersebut sudah tidak ada.",
    errAlreadyClaimed: "Wallet ini sudah klaim test pass (1 per wallet).",
    errOutOfStock:
      "Stok test pass habis — dispenser berikutnya akan diumumkan di channel Kong Alpha.",
    errNetwork:
      "Tidak bisa menjangkau BSC Testnet. Periksa koneksi Anda dan coba lagi.",
    errGeneric: "Terjadi kesalahan. Silakan coba lagi.",

    // -- info statis (JS) --
    marketLabel: "KongMarket: ",
    marketNotDeployedLine:
      "KongMarket: belum di-deploy ke BSC Testnet — alamat resmi akan tampil di sini setelah deploy testnet.",
    notDeployedShort: "Belum di-deploy",
  },

  en: {
    // -- meta / header --
    pageTitle: "Marketplace $KONG — Testnet Demo",
    metaDescription:
      "Marketplace $KONG — TESTNET DEMO. Try buying and selling Kong Mint Pass on BSC Testnet with no real money: claim a free test pass, mint test USDT, then list and buy.",
    ogDescription:
      "Try the Kong Mint Pass marketplace on BSC Testnet: free test pass, free test USDT, no real money.",
    brandSub: "Testnet demo — BSC Testnet (chain 97), no real money",
    mainnetMarketBtn: "Mainnet marketplace →",
    langSelectLabel: "Choose language",

    // -- banners --
    warnBannerStrong: "TESTNET DEMO — every token on this page is worthless.",
    warnBannerText:
      "tBNB, test USDT, and test passes here are only for trying the marketplace flow (list / buy / change price / cancel). There is no sale, graduation, $KONG claim, or refund on testnet. Never send mainnet assets to any testnet address.",
    networkWarnStrong: "Wrong network.",
    networkWarnText:
      "Your wallet is not on BSC Testnet (chain 97). Buying and listing in this demo require BSC Testnet.",
    switchNetworkBtn: "Switch to BSC Testnet",
    notDeployedStrong: "Marketplace not open yet.",
    notDeployedText:
      "The market contract is not deployed yet. This page will activate automatically once the contract is live.",

    // -- hero --
    heroAria: "About the testnet demo",
    heroImgAlt:
      "Kong Mint Pass — Tier 1 Gold artwork: King Kong dressed as a secret agent",
    heroTitle: "Try the marketplace, free.",
    heroP1: "This demo uses the exact same $KONG marketplace contracts as the mainnet version — only running on BSC Testnet with test tokens. Get tBNB from the faucet, mint test USDT, claim one free test pass, then try buying and selling just like on mainnet.",
    heroP2: "Non-custodial: the pass stays in the seller's wallet while listed. Funds split automatically — seller 94%, royalty 5% to treasury, marketplace fee 1%.",
    heroP3: "Listing prices cannot go below the tier floor (same as the mint price): 1 / 1.5 / 2 test USDT.",

    // -- test tokens --
    testTokensAria: "Test tokens",
    testTokensTitle: "Test tokens — 3 steps before trying",
    step1Title: "1. tBNB (gas)",
    step1Note:
      "Claim free tBNB from the official BNB Chain faucet. Faucet requirement: your address must hold a mainnet balance of ≥0.002 BNB + complete a captcha.",
    faucetBtn: "Open tBNB faucet →",
    step2Title: "2. Test USDT",
    step2Note:
      "Test USDT is minted directly from the mock contract (public, anyone may mint). 100 test USDT per click — enough for many buy attempts.",
    mintUsdtBtn: "Mint 100 test USDT",
    step3Title: "3. Test pass",
    step3NotePrefix: "One free test pass per wallet from the dispenser. ",
    step3NoteSuffix: " · Random tier (Gold / Silver / Bronze).",

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
    ratesNote:
      "All prices on this page are in test USDT / tBNB — worthless test tokens.",

    // -- my passes (static) --
    myPassesAria: "My passes",
    myPassesTitle: "My passes",
    scanningPasses: "Scanning your passes…",

    // -- how it works --
    howAria: "How it works",
    howTitle: "How it works",
    howListVerb: "List",
    howListText:
      " — approve the market contract for your pass, then set a price (test USDT or tBNB). The price cannot go below the tier floor. The pass stays in your wallet.",
    howBuyVerb: "Buy",
    howBuyText:
      " — for test USDT listings, approve test USDT for the price first; for tBNB listings, tBNB is sent with the buy transaction. Funds split automatically in one transaction: seller 94%, royalty 5% to treasury, fee 1% held in the market contract. Purchases are protected by a maximum price: if the listing price rises above the displayed price before the transaction is processed, the transaction is cancelled automatically.",
    howUpdateVerb: "Change / cancel",
    howUpdateText:
      " — the seller can change the price or cancel the listing at any time (tBNB gas only).",
    howNoClaimVerb: "No claim / refund on testnet",
    howNoClaimText:
      " — test passes cannot be claimed for $KONG and there is no refund. On mainnet, owners can claim (after graduation) or refund (if the sale fails) at any time, even while the pass is listed.",
    floorTableTitle: "Price floor per tier (testnet — same as mainnet)",
    thTier: "Tier",
    thFloorUsdt: "Test USDT floor",
    thFloorBnb: "tBNB floor (live)",
    thBreakeven: "Breakeven price*",
    tier1Usdt: "1 test USDT",
    tier1Bnb: "~0.001826 tBNB",
    tier1Be: "1.064 test USDT",
    tier2Usdt: "1.5 test USDT",
    tier2Bnb: "~0.002739 tBNB",
    tier2Be: "1.596 test USDT",
    tier3Usdt: "2 test USDT",
    tier3Bnb: "~0.003652 tBNB",
    tier3Be: "2.128 test USDT",
    breakevenNote:
      "* Breakeven price: the sale price at which the seller nets exactly the mint price after the 6% cut (royalty 5% + fee 1%). tBNB floors track the live Chainlink price.",
    splitTableTitle: "Split example — a 2 test USDT sale",
    thPart: "Part",
    thAmount: "Amount",
    thReceiver: "Receiver",
    splitRoyalty: "Royalty",
    splitRoyaltyAmt: "0.10 test USDT",
    splitRoyaltyTo: "Treasury (testnet)",
    splitFee: "Marketplace fee",
    splitFeeAmt: "0.02 test USDT",
    splitFeeTo: "Held in the market contract",
    splitSeller: "Seller receives",
    splitSellerAmt: "1.88 test USDT",
    splitSellerTo: "Seller",
    approvalWarnStrong: "Beware fake approvals.",
    approvalWarnText:
      "Only approve the official market contract address below. Never approve any other contract claiming to be the KONG marketplace — a fake approval can move your pass.",
    factPassLabel: "KongMintPass (mock testnet):",
    factUsdtLabel: "MockUSDT (testnet):",
    factDispenserLabel: "Test pass dispenser:",
    factTreasuryLabel: "Treasury (testnet):",

    // -- footer --
    footerMarketLabel: "KongMarket (testnet):",
    footerPassLabel: "KongMintPass (mock):",
    footerUsdtLabel: "MockUSDT:",
    footerDispenserLabel: "Dispenser:",
    footerAbout:
      "The $KONG marketplace testnet demo — a static frontend with no server; all data is read directly from BSC Testnet. The mainnet version (real money) is at the ",
    footerMainnetLink: "mainnet marketplace",
    footerAboutEnd: ".",
    footerNote:
      "Not financial advice. All tokens on this page are worthless test tokens. Always check the contract address in your wallet before approving any transaction.",

    // -- wallet / network (JS) --
    walletNotFound:
      "No wallet found. Install MetaMask or Binance Wallet, then reload this page.",
    disconnectBtn: "Disconnect",
    connectBtn: "Connect wallet",
    networkOk: "BSC Testnet · Chain 97",
    networkWrong: "Wrong network (chain {chain})",
    rpcAllFailed: "All BSC RPC endpoints failed.",

    // -- testnet panel (JS) --
    passRemaining: {
      one: "1 pass remaining",
      other: "{n} passes remaining",
    },
    connectToSeeBalance: "Connect your wallet to see your balance.",
    connectToClaimPass: "Connect your wallet to claim a test pass.",
    alreadyClaimedPass: "✓ You have already claimed a test pass (1 per wallet).",
    notClaimedPass: "You have not claimed a test pass yet.",
    stockEmptyBtn: "Test pass stock empty",
    claimedBtn: "Test pass already claimed",
    claimBtn: "Claim free test pass",
    mintUsdtPending: "Minting 100 test USDT… waiting for confirmation. ",
    mintUsdtDone:
      "✓ 100 test USDT is now in your wallet. This test USDT is worthless — only for trying the testnet marketplace. ",
    mintUsdtFailed: "✗ Minting test USDT failed: {err}",
    claimPending: "Claiming test pass… waiting for confirmation. ",
    claimDoneWithId:
      "✓ Test pass #{id} is now in your wallet. You can list it below. ",
    claimDone: "✓ The test pass is now in your wallet. Check the “My passes” section. ",
    claimFailed: "✗ Claiming the test pass failed: {err}",
    txLabel: "Transaction: ",

    // -- listings (JS) --
    marketNotDeployedNote:
      "Listings will appear here after the market contract is deployed and passes are listed.",
    marketNotDeployedEmpty:
      "The testnet marketplace is not open yet — the market contract is not deployed to BSC Testnet.",
    loadingListings: "Loading listings from the blockchain…",
    listingsLoadFailed:
      "Listings could not be loaded: {err} Try reloading with the button above.",
    noListings: "No listings yet.",
    showingListings: "Showing {shown} of {total} active listings.",
    staleHidden: {
      one: "1 listing is hidden because it is no longer valid (pass claimed/moved or approval revoked).",
      other:
        "{n} listings are hidden because they are no longer valid (pass claimed/moved or approval revoked).",
    },
    rpcFallbackNote:
      "Listing data was fetched via RPC (BscScan unreachable) — it may be slower.",
    noListingsYet:
      "No passes are listed yet. Be the first — connect your wallet and list your pass below.",
    noFilterMatch: "No listings match this filter.",
    testnetNoValue: "Testnet — worthless tokens",
    claimValueSim: "Claim value (simulated): {value}",
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

    // -- my passes (JS) --
    walletReadFailed:
      "Could not read your wallet status from BSC Testnet. Check your connection and try again.",
    myPassesLoadFailed:
      "Could not load your passes from BSC Testnet. Check your connection and try again.",
    connectToSeePassesNote: "Connect your wallet to see your passes and list them.",
    connectToSeePasses: "Connect your wallet to see your passes.",
    noTestPassNote:
      "You do not have a test pass yet — claim one free in the “Test tokens” section above, or buy a listing in this marketplace.",
    noMintPass: "You do not own a Mint Pass yet.",
    scanningPassesChain: "Scanning your passes from the blockchain…",
    holdingPasses: {
      one: "You hold 1 test pass. Listings are non-custodial: the pass stays in your wallet; you only approve the market contract — until it sells.",
      other:
        "You hold {n} test passes. Listings are non-custodial: passes stay in your wallet; you only approve the market contract — until they sell.",
    },
    holdingPassesNotDeployed: {
      one: "You hold 1 pass. Listing opens after the market contract is deployed.",
      other: "You hold {n} passes. Listing opens after the market contract is deployed.",
    },
    listingOpensAfterDeploy: "Listing opens after the market contract is deployed.",
    getFreeTestPass: "Get a free test pass ↑",
    listedPrice: "Listed: {price}",
    approvalStaleWarn:
      "Warning: the approval of this pass to the market is no longer valid — the listing cannot be bought until you approve again.",
    reapproveBtn: "Approve again",
    newPriceLabel: "New price ({currency})",
    floorNote: "Floor {tier}: {floor} · Breakeven price: {breakeven}",
    updatePriceBtn: "Change price",
    cancelListingBtn: "Cancel listing",
    sellPriceLabel: "Sale price",
    pricePlaceholder: "e.g. 2",
    floorNoteList:
      "Floor {tier}: {floor} · Breakeven price (net received = mint price): {breakeven} · Cut per sale: royalty 5% + fee 1%.",
    listPassBtn: "List pass",
    invalidPrice: "Invalid price — enter a number, e.g. 2 or 1.5.",
    belowFloor: "Price below the {tier} floor: minimum {min}.",
    passApprovedAlready: "Pass #{id} is already approved to the market contract.",
    approvePending:
      "Approving Pass #{id} to the market contract… waiting for confirmation. ",
    approveDone:
      "✓ Pass #{id} is approved to the market contract. Your listing can now be bought. ",
    approveFailed: "✗ Approval failed: {err}",
    listingPending: "Listing Pass #{id} for {price}… waiting for confirmation. ",
    listingDone:
      "✓ Pass #{id} is listed for {price}. You keep holding the pass until it sells. ",
    listingFailed: "✗ Listing failed: {err}",
    updatePricePending:
      "Changing the price of Pass #{id} to {price}… waiting for confirmation. ",
    updatePriceDone: "✓ The price of Pass #{id} is now {price}. ",
    updatePriceFailed: "✗ Changing the price failed: {err}",
    cancelConfirm:
      "Cancel the listing for Pass #{id}? The pass stays in your wallet; cancelling only removes the listing (gas only).",
    cancelPending: "Cancelling the listing for Pass #{id}… waiting for confirmation. ",
    cancelDone: "✓ The listing for Pass #{id} is cancelled. The pass stays in your wallet. ",
    cancelFailed: "✗ Cancellation failed: {err}",

    // -- error messages (JS) --
    errWrongNetwork:
      "Your wallet is not on BSC Testnet (chain 97). Switch networks and try again.",
    errListingStale:
      "This listing is no longer valid (pass moved, claimed, or approval revoked).",
    errSelfPurchase: "You cannot buy your own listing.",
    errDeployBlockMissing:
      "The market contract's deploy block is not set in the configuration — the RPC fallback cannot run.",
    errUserRejected: "Transaction rejected in the wallet. Nothing was sent.",
    errInsufficientFunds:
      "Not enough tBNB in the wallet for gas (or for a tBNB payment). Claim free tBNB from the testnet faucet.",
    errNoListing: "Listing not found — it may already be sold or cancelled.",
    errNotSeller: "Only the seller can change or cancel this listing.",
    errBelowFloor: "Price below this pass tier's floor.",
    errNotPassOwner: "This wallet does not own that pass.",
    errOwnershipChanged:
      "The pass changed owners since it was listed — this listing is stale.",
    errNotApproved: "The pass is not approved to the market contract yet.",
    errIncorrectValue:
      "The BNB sent does not exactly match the listing price.",
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
    errNoToken: "That pass no longer exists.",
    errAlreadyClaimed: "This wallet has already claimed a test pass (1 per wallet).",
    errOutOfStock:
      "Test pass stock is empty — the next dispenser will be announced in the Kong Alpha channel.",
    errNetwork: "Could not reach BSC Testnet. Check your connection and try again.",
    errGeneric: "Something went wrong. Please try again.",

    // -- static info (JS) --
    marketLabel: "KongMarket: ",
    marketNotDeployedLine:
      "KongMarket: not deployed to BSC Testnet yet — the official address will appear here after the testnet deploy.",
    notDeployedShort: "Not deployed",
  },

  zh: {
    // -- meta / header --
    pageTitle: "$KONG 市场——测试网演示",
    metaDescription:
      "$KONG 市场——测试网演示。在 BSC 测试网免费体验 Kong Mint 通行证买卖，无需真金白银：免费领取测试通行证、铸造测试 USDT，然后上架和购买。",
    ogDescription:
      "在 BSC 测试网体验 Kong Mint 通行证市场：免费测试通行证、免费测试 USDT，无需真金白银。",
    brandSub: "测试网演示——BSC 测试网（链 97），不涉及真金白银",
    mainnetMarketBtn: "主网市场 →",
    langSelectLabel: "选择语言",

    // -- banner --
    warnBannerStrong: "测试网演示——本页所有代币均无价值。",
    warnBannerText:
      "这里的 tBNB、测试 USDT 和测试通行证仅用于体验市场流程（上架 / 购买 / 改价 / 取消）。测试网没有发售、毕业、$KONG 领取或退款。请勿向任何测试网地址发送主网资产。",
    networkWarnStrong: "网络错误。",
    networkWarnText:
      "您的钱包不在 BSC 测试网（链 97）。本演示的购买和上架需要 BSC 测试网。",
    switchNetworkBtn: "切换到 BSC 测试网",
    notDeployedStrong: "市场尚未开放。",
    notDeployedText: "市场合约尚未部署。合约上线后，本页将自动激活。",

    // -- hero --
    heroAria: "关于测试网演示",
    heroImgAlt: "Kong Mint 通行证——一级金卡艺术图：化装成特工的金刚",
    heroTitle: "免费体验市场。",
    heroP1: "本演示使用的 $KONG 市场合约与主网版本完全相同——只不过运行在 BSC 测试网，使用测试代币。从水龙头领取 tBNB，铸造测试 USDT，免费领取 1 个测试通行证，然后像在主网一样体验买卖。",
    heroP2: "非托管：挂单期间通行证仍在卖家钱包中。资金自动分配——卖家 94%、版税 5% 归财库、市场手续费 1%。",
    heroP3: "挂单价格不得低于该等级的底价（与铸造价相同）：1 / 1.5 / 2 测试 USDT。",

    // -- 测试代币 --
    testTokensAria: "测试代币",
    testTokensTitle: "测试代币——体验前的 3 个步骤",
    step1Title: "1. tBNB（Gas）",
    step1Note:
      "在 BNB Chain 官方水龙头免费领取 tBNB。水龙头要求：您的地址须持有主网余额 ≥0.002 BNB，并完成验证码。",
    faucetBtn: "打开 tBNB 水龙头 →",
    step2Title: "2. 测试 USDT",
    step2Note:
      "测试 USDT 直接从模拟合约铸造（公开，任何人都可以）。每次点击铸造 100 测试 USDT——足够多次购买尝试。",
    mintUsdtBtn: "铸造 100 测试 USDT",
    step3Title: "3. 测试通行证",
    step3NotePrefix: "每个钱包可从分发器免费领取 1 个测试通行证。",
    step3NoteSuffix: " · 等级随机（金 / 银 / 铜）。",

    // -- 挂单（静态） --
    listingsAria: "挂单",
    listingsTitle: "挂单",
    refreshListingsBtn: "重新加载挂单",
    listingsIntro:
      "每个挂单在展示前都会实时验证：卖家仍持有该通行证、给市场的授权仍然有效、链上挂单仍然一致。不再有效的挂单会被隐藏。",
    filterTier: "等级",
    filterAllTiers: "全部等级",
    filterCurrency: "货币",
    filterAll: "全部",
    filterSort: "按价格排序",
    sortAsc: "价格从低到高",
    sortDesc: "价格从高到低",
    ratesNote: "本页所有价格均为测试 USDT / tBNB——无价值的测试代币。",

    // -- 我的通行证（静态） --
    myPassesAria: "我的通行证",
    myPassesTitle: "我的通行证",
    scanningPasses: "正在扫描您的通行证……",

    // -- 使用方法 --
    howAria: "使用方法",
    howTitle: "使用方法",
    howListVerb: "上架",
    howListText:
      "——先授权市场合约使用您的通行证，然后设定价格（测试 USDT 或 tBNB）。价格不得低于该等级的底价。通行证仍在您的钱包中。",
    howBuyVerb: "购买",
    howBuyText:
      "——测试 USDT 挂单需先授权相应金额的测试 USDT；tBNB 挂单则随购买交易一并发送 tBNB。资金在单笔交易中自动分配：卖家 94%、版税 5% 归财库、手续费 1% 暂存于市场合约。购买受最高价保护：若挂单价格在交易处理前涨至高于显示价格，交易将自动取消。",
    howUpdateVerb: "改价 / 取消",
    howUpdateText: "——卖家可随时改价或取消挂单（仅需 tBNB Gas）。",
    howNoClaimVerb: "测试网没有领取 / 退款",
    howNoClaimText:
      "——测试通行证无法领取 $KONG，也没有退款。主网上线后，持有者可随时领取（毕业后）或退款（发售失败时），即使通行证正在挂单中。",
    floorTableTitle: "各等级价格底价（测试网——与主网相同）",
    thTier: "等级",
    thFloorUsdt: "测试 USDT 底价",
    thFloorBnb: "tBNB 底价（实时）",
    thBreakeven: "保本价*",
    tier1Usdt: "1 测试 USDT",
    tier1Bnb: "~0.001826 tBNB",
    tier1Be: "1.064 测试 USDT",
    tier2Usdt: "1.5 测试 USDT",
    tier2Bnb: "~0.002739 tBNB",
    tier2Be: "1.596 测试 USDT",
    tier3Usdt: "2 测试 USDT",
    tier3Bnb: "~0.003652 tBNB",
    tier3Be: "2.128 测试 USDT",
    breakevenNote:
      "* 保本价：扣除 6%（版税 5% + 手续费 1%）后，卖家净收入恰好等于铸造价的售价。tBNB 底价实时跟随 Chainlink 价格。",
    splitTableTitle: "分配示例——2 测试 USDT 的一笔销售",
    thPart: "部分",
    thAmount: "金额",
    thReceiver: "接收方",
    splitRoyalty: "版税",
    splitRoyaltyAmt: "0.10 测试 USDT",
    splitRoyaltyTo: "财库（测试网）",
    splitFee: "市场手续费",
    splitFeeAmt: "0.02 测试 USDT",
    splitFeeTo: "暂存于市场合约",
    splitSeller: "卖家实收",
    splitSellerAmt: "1.88 测试 USDT",
    splitSellerTo: "卖家",
    approvalWarnStrong: "谨防虚假授权。",
    approvalWarnText:
      "只授权下方官方市场合约地址。切勿授权任何冒充 KONG 市场的其他合约——虚假授权可能转移您的通行证。",
    factPassLabel: "KongMintPass（测试网模拟版）：",
    factUsdtLabel: "MockUSDT（测试网）：",
    factDispenserLabel: "测试通行证分发器：",
    factTreasuryLabel: "财库（测试网）：",

    // -- 页脚 --
    footerMarketLabel: "KongMarket（测试网）：",
    footerPassLabel: "KongMintPass（模拟版）：",
    footerUsdtLabel: "MockUSDT：",
    footerDispenserLabel: "分发器：",
    footerAbout:
      "$KONG 市场测试网演示——纯静态前端，没有服务器，所有数据直接从 BSC 测试网读取。主网版本（真金白银）请见",
    footerMainnetLink: "主网市场",
    footerAboutEnd: "。",
    footerNote:
      "不构成财务建议。本页所有代币均为无价值的测试代币。批准任何交易前，请务必在钱包中核对合约地址。",

    // -- 钱包 / 网络（JS） --
    walletNotFound: "未找到钱包。请安装 MetaMask 或 Binance Wallet，然后重新加载本页。",
    disconnectBtn: "断开连接",
    connectBtn: "连接钱包",
    networkOk: "BSC 测试网 · 链 97",
    networkWrong: "网络错误（链 {chain}）",
    rpcAllFailed: "所有 BSC RPC 节点均无响应。",

    // -- 测试网面板（JS） --
    passRemaining: "剩余 {n} 个通行证",
    connectToSeeBalance: "连接钱包以查看余额。",
    connectToClaimPass: "连接钱包以领取测试通行证。",
    alreadyClaimedPass: "✓ 您已领取测试通行证（每个钱包 1 个）。",
    notClaimedPass: "您尚未领取测试通行证。",
    stockEmptyBtn: "测试通行证已领完",
    claimedBtn: "测试通行证已领取",
    claimBtn: "免费领取测试通行证",
    mintUsdtPending: "正在铸造 100 测试 USDT……等待确认。",
    mintUsdtDone:
      "✓ 100 测试 USDT 已到账您的钱包。该测试 USDT 无价值——仅用于体验测试网市场。",
    mintUsdtFailed: "✗ 铸造测试 USDT 失败：{err}",
    claimPending: "正在领取测试通行证……等待确认。",
    claimDoneWithId: "✓ 测试通行证 #{id} 已到账您的钱包。您可以在下方上架它。",
    claimDone: "✓ 测试通行证已到账您的钱包。请查看“我的通行证”部分。",
    claimFailed: "✗ 领取测试通行证失败：{err}",
    txLabel: "交易：",

    // -- 挂单（JS） --
    marketNotDeployedNote: "市场合约部署并有通行证上架后，挂单将出现在这里。",
    marketNotDeployedEmpty: "测试网市场尚未开放——市场合约尚未部署到 BSC 测试网。",
    loadingListings: "正在从区块链加载挂单……",
    listingsLoadFailed: "无法加载挂单：{err} 请使用上方按钮重新加载。",
    noListings: "暂无挂单。",
    showingListings: "显示 {shown} / {total} 个在售挂单。",
    staleHidden: "{n} 个挂单因不再有效而被隐藏（通行证已被领取/转移或授权被撤销）。",
    rpcFallbackNote: "挂单数据通过 RPC 获取（BscScan 无法访问）——可能较慢。",
    noListingsYet: "暂无通行证挂单。成为第一个——连接钱包并在下方上架您的通行证。",
    noFilterMatch: "没有符合该筛选条件的挂单。",
    testnetNoValue: "测试网——代币无价值",
    claimValueSim: "可领取价值（模拟）：{value}",
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

    // -- 购买确认（JS） --
    buyConfirmTitle: "确认购买——通行证 #{id}（{tier}）",
    quotePrice: "您需支付的价格",
    quoteMaxPrice: "最高价上限（保护）",
    quoteSellerGets: "卖家实收（94%）",
    quoteRoyalty: "版税归财库（5%）",
    quoteFee: "市场手续费（1%，暂存）",
    quoteClaim: "毕业后可领取",
    quoteSeller: "卖家",
    payUsdtNote:
      "USDT 支付：如授权额度不足，您将先被要求授权相应金额的 USDT，然后再发起购买交易。两者都需要在钱包中确认。",
    payBnbNote: "BNB 支付：相应金额的 BNB 随购买交易一并发送——无需单独授权。",
    maxPriceWarn:
      "您的购买受最高价保护：若挂单价格在交易处理前涨至高于上方价格，交易将自动取消，您不会多付。交易发送前会再次验证挂单。",
    confirmBuyBtn: "确认购买——{price}",
    cancelBtn: "取消",
    approveUsdtPending: "正在授权（approve）{amount} 给市场合约……等待确认。",
    buyingPending: "正在购买通行证 #{id}……等待确认。",
    buyDone: "✓ 通行证 #{id} 已以 {price} 成功购买。通行证已在您的钱包中。",
    buyFailed: "✗ 购买失败：{err}",

    // -- 我的通行证（JS） --
    walletReadFailed: "无法从 BSC 测试网读取您的钱包状态。请检查网络连接并重试。",
    myPassesLoadFailed: "无法从 BSC 测试网加载您的通行证。请检查网络连接并重试。",
    connectToSeePassesNote: "连接钱包以查看您的通行证并上架。",
    connectToSeePasses: "连接钱包以查看您的通行证。",
    noTestPassNote: "您还没有测试通行证——请在上方“测试代币”部分免费领取，或在本市场购买挂单。",
    noMintPass: "您尚未拥有 Mint 通行证。",
    scanningPassesChain: "正在从区块链扫描您的通行证……",
    holdingPasses:
      "您持有 {n} 个测试通行证。挂单是非托管的：通行证仍在您的钱包中，您只需授权市场合约——直到售出。",
    holdingPassesNotDeployed: "您持有 {n} 个通行证。市场合约部署后即可上架。",
    listingOpensAfterDeploy: "市场合约部署后即可上架。",
    getFreeTestPass: "免费领取测试通行证 ↑",
    listedPrice: "已上架：{price}",
    approvalStaleWarn: "注意：该通行证给市场的授权已失效——重新授权前挂单无法被购买。",
    reapproveBtn: "重新授权",
    newPriceLabel: "新价格（{currency}）",
    floorNote: "{tier} 底价：{floor} · 保本价：{breakeven}",
    updatePriceBtn: "改价",
    cancelListingBtn: "取消挂单",
    sellPriceLabel: "售价",
    pricePlaceholder: "例如：2",
    floorNoteList:
      "{tier} 底价：{floor} · 保本价（净收入 = 铸造价）：{breakeven} · 每笔销售扣除：版税 5% + 手续费 1%。",
    listPassBtn: "上架通行证",
    invalidPrice: "价格无效——请输入数字，例如 2 或 1.5。",
    belowFloor: "价格低于 {tier} 底价：最低 {min}。",
    passApprovedAlready: "通行证 #{id} 已授权给市场合约。",
    approvePending: "正在授权通行证 #{id} 给市场合约……等待确认。",
    approveDone: "✓ 通行证 #{id} 已授权给市场合约。您的挂单现在可以被购买了。",
    approveFailed: "✗ 授权失败：{err}",
    listingPending: "正在以 {price} 上架通行证 #{id}……等待确认。",
    listingDone: "✓ 通行证 #{id} 已以 {price} 上架。售出前通行证仍由您持有。",
    listingFailed: "✗ 上架失败：{err}",
    updatePricePending: "正在将通行证 #{id} 的价格改为 {price}……等待确认。",
    updatePriceDone: "✓ 通行证 #{id} 的价格已改为 {price}。",
    updatePriceFailed: "✗ 改价失败：{err}",
    cancelConfirm:
      "取消通行证 #{id} 的挂单？通行证仍在您的钱包中；取消仅删除挂单（仅需 Gas）。",
    cancelPending: "正在取消通行证 #{id} 的挂单……等待确认。",
    cancelDone: "✓ 通行证 #{id} 的挂单已取消。通行证仍在您的钱包中。",
    cancelFailed: "✗ 取消失败：{err}",

    // -- 错误信息（JS） --
    errWrongNetwork: "您的钱包不在 BSC 测试网（链 97）。请切换网络后重试。",
    errListingStale: "该挂单已失效（通行证被转移、领取或授权被撤销）。",
    errSelfPurchase: "您不能购买自己的挂单。",
    errDeployBlockMissing: "配置中未填写市场合约的部署区块——RPC 备用方案无法运行。",
    errUserRejected: "交易在钱包中被拒绝。没有任何交易发出。",
    errInsufficientFunds:
      "钱包中的 tBNB 不足以支付 Gas（或 tBNB 付款）。请在测试网水龙头免费领取 tBNB。",
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
    errPriceAboveMax:
      "挂单价格在交易处理前发生了变化——购买已被最高价保护自动取消。请重新加载挂单后重试。",
    errAllowance: "市场合约尚未获得使用该金额 USDT 的授权。请先授权，再购买。",
    errUsdtBalance: "您的 USDT 余额不足以完成本次购买。",
    errNoToken: "该通行证已不存在。",
    errAlreadyClaimed: "该钱包已领取测试通行证（每个钱包 1 个）。",
    errOutOfStock: "测试通行证已领完——下一个分发器将在 Kong Alpha 频道公告。",
    errNetwork: "无法连接 BSC 测试网。请检查网络连接并重试。",
    errGeneric: "发生错误。请重试。",

    // -- 静态信息（JS） --
    marketLabel: "KongMarket：",
    marketNotDeployedLine:
      "KongMarket：尚未部署到 BSC 测试网——测试网部署后官方地址将显示在这里。",
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
