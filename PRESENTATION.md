# BensinKu — Naskah Presentasi Teknis

> Dokumen ini adalah **panduan ngomong** saat demo arsitektur ke pewawancara/penonton.
> Disusun dari sumber kebenaran: kode di repo ini (lihat [`ARCHITECTURE.md`](ARCHITECTURE.md) untuk detail lengkap).
>
> **Aturan main saat presentasi:** jujur soal teknologi yang dipakai. App ini **tidak pakai BLoC/Riverpod** — dan itu keputusan sadar, bukan kekurangan. Kalau ditanya BLoC, jawab dengan alasan di [Slide 2](#slide-2--otak-aplikasi-state-management). Jangan ngaku pakai yang nggak dipakai; pewawancara teknis pasti buka kodenya.

---

## Alur Presentasi (5 babak)

| # | Babak | Durasi | Tujuan |
|---|---|---|---|
| 0 | Pembuka — apa & kenapa | 1 menit | Bikin penonton paham masalah yang dipecahkan |
| 1 | Struktur folder (layered architecture) | 2 menit | Buktikan mikirin maintainability |
| 2 | Otak aplikasi (state management) | 3 menit | Jawab keraguan soal performa |
| 3 | Jalur ke backend (integrasi + DI) | 2 menit | Tunjukkan loose coupling & keamanan |
| 4 | Flex point (solusi tercerdas) | 3 menit | Buktikan kamu **arsiteknya**, bukan cuma nempel kode |

Total ~11 menit. Sisakan waktu buat tanya jawab.

---

## Slide 0 — Pembuka: Apa & Kenapa

**Yang ditampilkan:** app jalan di HP (live demo singkat — buka Beranda, tunjukkan prediksi bensin).

**Cara ngejelasinnya:**
> "BensinKu itu pencatat bahan bakar pribadi. Bedanya dari sekadar buku catatan digital: dia **memprediksi kapan saya harus isi bensin lagi** berdasarkan pola pengisian saya, dan punya **input cepat lewat suara atau scan struk** pakai AI. Dibangun full-stack sendiri: Flutter di depan, Supabase self-hosted di belakang."

**Tiga pilar yang gua bangun (sebut ini, nanti dibedah):**
1. **Adaptive prediction** — prediksi yang makin akurat seiring data bertambah.
2. **AI input shortcut** — voice + OCR struk, biar nyatat nggak ribet.
3. **GPS trip recorder** — rekam rute + jarak otomatis.

**Stack singkat:** Flutter (Dart) · Supabase (Postgres + Auth + Edge Functions) · OpenStreetMap · LLM via Edge Function.

---

## Slide 1 — Struktur Folder (Layered Architecture)

**Yang ditampilkan:** sidebar editor, expand folder `lib/`.

**Cara ngejelasinnya:**
> "Saya nggak nyampur semua kode di satu tempat. Saya pisah berdasarkan **tanggung jawab**: ada layer UI (tampilan), layer service (logic), dan layer data (akses database). Jadi kalau aplikasi membesar, kodenya nggak jadi spaghetti."

```
lib/
├── main.dart            ← Entry point: bootstrap (splash, locale, Supabase init)
├── app/                 ← Shell aplikasi
│   ├── app.dart         ← MaterialApp + Auth Gate (routing berdasarkan status login)
│   └── theme.dart       ← Design system terpusat (warna, font, radius)
├── config/
│   └── app_config.dart  ← Loader env var (URL Supabase, client ID Google)
├── data/                ← ── LAYER DATA ──
│   ├── models.dart      ← Tipe data + enum (Vehicle, Refuel, Trip, …)
│   └── repository.dart  ← SATU-SATUNYA pintu ke database
├── features/            ← ── LAYER UI (per fitur) ──
│   ├── auth/            ← Login, daftar, lupa password
│   ├── onboarding/     ← Welcome → profil → kendaraan → preferensi
│   ├── home/           ← Dashboard, analisa, arsip, profil, maintenance
│   └── trip/           ← Perekam GPS + replay rute
├── services/            ← ── LAYER LOGIC ──
│   ├── trip_service.dart        ← Streaming GPS + auto-stop
│   ├── prediction_service.dart  ← Mesin prediksi (pure logic)
│   ├── refuel_parser_service.dart ← Client AI parser
│   └── google_auth_service.dart ← Native Google sign-in
└── widgets/             ← Komponen reusable lintas fitur
```

**Poin kunci yang harus disebut:**
- **`features/` dipecah per-fitur**, bukan per-tipe-file. Jadi semua yang berkaitan dengan "trip" ada di satu tempat — gampang dicari, gampang dihapus.
- **`data/` dan `services/` terpisah dari UI.** UI nggak tahu cara kerja database. Dia cuma manggil method.
- **`theme.dart` terpusat.** Ganti satu warna → seluruh app ikut berubah. Nggak ada warna hardcoded berserakan.

**Kenapa ini penting (kalimat penutup babak):**
> "Ini membuktikan saya mikirin maintainability sejak awal, bukan cuma ngejar fitur jadi."

---

## Slide 2 — Otak Aplikasi (State Management)

> **PENTING — baca dulu sebelum presentasi:** app ini pakai **StatefulWidget + FutureBuilder + ChangeNotifier**, BUKAN BLoC/Riverpod. Jangan ngaku BLoC. Justru jadikan ini cerita: "saya pilih tool sesuai skala masalah."

**Cara ngejelasinnya (kalau ditanya kenapa nggak BLoC):**
> "Saya sengaja nggak pakai BLoC atau Riverpod di sini. Untuk skala aplikasi ini, itu malah over-engineering — nambah boilerplate tanpa manfaat nyata. Saya pakai tiga pola bawaan Flutter yang tepat guna: `FutureBuilder` untuk data sekali-ambil, dan `ChangeNotifier` untuk state yang berubah terus-menerus seperti GPS. Memilih tool sesuai skala masalah itu sendiri sebuah keputusan arsitektur."

### Pola A — `FutureBuilder` untuk data sekali-ambil

Dipakai di dashboard, analisa, profil. Ambil data, render, selesai.

```dart
// lib/features/home/summary_tab.dart
FutureBuilder<List<Vehicle>>(
  future: _repo.listVehicles(),       // ambil data dari repository
  builder: (context, snap) {
    if (snap.hasError) return _CenteredError(...);   // state: error
    if (snap.data == null) return _CenteredLoading(); // state: loading
    final vehicles = snap.data!;                       // state: sukses
    return ListView(...);
  },
)
```

**Cara ngejelasinnya:**
> "`FutureBuilder` ini otomatis nangani tiga kondisi: loading, error, dan sukses. UI saya deklaratif — dia cuma menggambarkan 'kalau lagi loading tampilkan ini, kalau error tampilkan itu'. Saya nggak perlu manual `setState` buat tiap kondisi."

### Pola B — `ChangeNotifier` untuk state real-time (yang paling penting)

Ini "otak" fitur paling kompleks: **perekam GPS**. State-nya berubah tiap detik (posisi baru masuk terus).

```dart
// lib/services/trip_service.dart
class TripService extends ChangeNotifier {
  final List<Position> _positions = [];
  double _distanceMeters = 0.0;

  void _onPosition(Position pos) {
    // ... hitung jarak, simpan posisi ...
    _positions.add(pos);
    notifyListeners();   // ← kabari SEMUA UI yang mendengarkan
  }
}
```

UI-nya cuma "mendengarkan" dan rebuild otomatis saat ada perubahan:

```dart
// lib/features/trip/trip_map_screen.dart
svc.addListener(_onServiceUpdate);   // daftar jadi pendengar
// ... saat _onServiceUpdate dipanggil → setState → peta + telemetri update
```

**Cara ngejelasinnya:**
> "Untuk perekaman rute, posisi GPS masuk tiap beberapa detik. Saya pakai `ChangeNotifier`: logic-nya saya taruh di `TripService` — terpisah dari UI. Saat ada posisi baru, dia panggil `notifyListeners()`, dan UI yang mendengarkan otomatis menggambar ulang polyline rute. Jadi **UI saya 'bodoh'** — dia murni nunggu perintah dari service, nggak nyimpen logic apa pun."

**Poin performa (jawab keraguan soal lemot):**
> "Yang penting buat performa: logic berat — hitung jarak Haversine, batching ke database — semua di service, bukan di `build` method UI. Jadi widget tree-nya tetap ringan. Plus, data GPS saya **batch tiap 30 detik** sebelum kirim ke server, bukan tiap titik — hemat memori dan network."

```dart
// lib/services/trip_service.dart — batching biar hemat
_flushTimer = Timer.periodic(const Duration(seconds: 30), (_) => _flushWaypoints());
```

**Kenapa ini penting (penutup babak):**
> "Pemisahan UI ↔ logic ini yang bikin app tetap responsif walau GPS streaming jalan terus di background."

---

## Slide 3 — Jalur ke Backend (Integrasi + Dependency Injection)

**Yang ditampilkan:** buka [`lib/data/repository.dart`](lib/data/repository.dart).

**Cara ngejelasinnya:**
> "Aplikasi saya **nggak pernah** nembak database langsung dari UI. Semua lewat satu kelas perantara: `SupabaseRepository`. Ini namanya Repository Pattern. Kalau suatu hari saya migrasi dari Supabase ke backend lain, saya cuma ganti kode di **satu file ini** — seluruh UI aman, nggak perlu disentuh."

### Repository sebagai satu-satunya pintu

```dart
// lib/data/repository.dart
class SupabaseRepository {
  SupabaseRepository(this._client) : _db = _client.schema(_schemaName);

  static const String _schemaName = 'bensinku';   // semua tabel di schema ini
  final SupabaseClient _client;
  final SupabaseQuerySchema _db;
  // ...
}
```

**Cara ngejelasinnya:**
> "Perhatikan `_client.schema('bensinku')`. Database Supabase ini saya pakai bareng beberapa aplikasi lain. Tiap aplikasi punya schema-nya sendiri biar nggak rebutan namespace. Jadi semua query saya otomatis ter-scope ke schema BensinKu — aman dari tabrakan nama tabel."

### Dependency Injection (constructor injection)

```dart
// Repository menerima client dari luar — tidak bikin sendiri.
SupabaseRepository(this._client) : _db = _client.schema(_schemaName);

// Shortcut buat pemakaian normal:
static SupabaseRepository ofDefaultClient() =>
    SupabaseRepository(Supabase.instance.client);
```

**Cara ngejelasinnya:**
> "Repository ini nerima client database dari luar lewat constructor — dia nggak bikin sendiri. Ini Dependency Injection. Manfaatnya: saat testing, saya bisa suntik client palsu (mock) buat nguji logic tanpa nyentuh database asli. Ini yang disebut **loose coupling**."

### Bonus: error teknis diterjemahkan jadi pesan manusiawi

```dart
// lib/data/repository.dart
StateError? _mapPostgrestException(PostgrestException e) {
  final looksLikeMissingTable = e.code == 'PGRST205' || ...;
  if (!looksLikeMissingTable) return null;
  return StateError('Backend belum siap: tabel ... belum ada. Jalankan schema.sql ...');
}
```

**Cara ngejelasinnya:**
> "Saya juga bungkus tiap operasi database dalam error handler. Kode error Postgres yang asing seperti `PGRST205` saya terjemahkan jadi pesan bahasa Indonesia yang actionable — user (atau saya pas debug) langsung tahu harus ngapain."

**Keamanan (sebut singkat):**
> "Keamanan dijaga di level database pakai **Row Level Security**: tiap baris di-tag `user_id`, dan aturan database memastikan user cuma bisa baca data miliknya sendiri. Jadi walau ada bug di app, data user lain tetap nggak bisa bocor."

**Kenapa ini penting (penutup babak):**
> "Pola ini bikin sistem saya fleksibel dan aman — gampang dimigrasi, gampang dites, dan data tiap user terisolasi."

---

## Slide 4 — Flex Point: Solusi Paling Cerdas

> Pilih **SATU** dari tiga ini sesuai audiens. Kalau audiens suka matematika/produk → pilih **A**. Kalau suka sistem/edge case → pilih **B**. Kalau suka integrasi → pilih **C**.

### Flex A — Prediksi adaptif tanpa cold-start (REKOMENDASI utama)

**Masalah yang dipecahkan:**
> "Tantangan terbesar app tracker: hari pertama install, sistem belum tahu apa-apa soal user. Prediksi awal pasti ngawur. Kebanyakan app nampilin '—' sampai user ngumpulin data berminggu-minggu."

**Solusi cerdasnya — Bayesian blending:**
> "Saya gabungkan dua sumber: **prior** (tebakan dari spec kendaraan + kota) dan **data nyata** (pengukuran dari tiap pengisian). Pakai rata-rata tertimbang yang otomatis bergeser percaya ke data nyata seiring data bertambah."

```dart
// lib/services/prediction_service.dart
// posterior = (α·prior + Σ samples) / (α + n)
final posterior = (_priorWeightAlpha * prior + sampleSum) / (_priorWeightAlpha + n);
```

**Cara ngejelasinnya:**
> "`α` ini bobot kepercayaan ke tebakan awal, saya set setara 8 pengukuran. Saat data user masih kosong, hasilnya = tebakan awal. Setelah 8 kali isi, tebakan dan data nyata seimbang. Setelah 24 kali, data nyata yang dominan. Jadi dari hari pertama user langsung dapat angka masuk akal, dan makin lama makin personal — tanpa perlu klik 'kalibrasi' apa pun."

**Plot twist yang bikin makin keren (sebut ini kalau mau nendang):**
> "Tapi waktu saya pakai sendiri 3 minggu, prediksi tanggalnya kurang akurat. Saya analisa: ternyata buat menjawab 'kapan harus isi bensin', km/L itu sinyal yang lemah. Sinyal terkuat justru **pola interval pengisian itu sendiri** — saya selalu isi tiap ~8 hari. Jadi saya ubah: prediksi tanggal sekarang pakai median jarak antar-pengisian dari riwayat transaksi. Itu meniru cara user mikir, dan jauh lebih akurat."

```dart
// lib/services/prediction_service.dart
// Prediksi tanggal = tanggal isi terakhir + median interval pengisian
predictedDate = lastRefuel.refuelDate.add(Duration(hours: (interval * 24).round()));
```

**Kenapa ini "flex":** menunjukkan kamu bukan cuma nempel rumus — kamu **uji di dunia nyata, nemu kelemahan, dan perbaiki berdasarkan data.** Itu cara berpikir arsitek/engineer sungguhan.

---

### Flex B — GPS auto-stop yang tahan bug jam

**Masalah:**
> "Perekam rute harus berhenti otomatis kalau user lupa matiin — misal udah sampai tujuan tapi tracking masih jalan. Saya set auto-stop kalau idle 30 menit, dan waktu idle-nya harus dipotong dari total durasi."

**Bug yang saya temukan:**
> "Awalnya auto-stop nggak pernah jalan, padahal udah idle sejam. Setelah saya bedah: saya bandingkan timestamp dari GPS dengan jam device — dan ternyata package GPS kadang ngasih timestamp di zona waktu beda. Hasilnya selisih waktu jadi **negatif**, jadi syarat '≥30 menit' nggak pernah kepenuhan."

**Solusinya:**
```dart
// lib/services/trip_service.dart
// SEBELUM (bug): bandingkan jam GPS vs jam device → bisa negatif
// SESUDAH: pakai jam device konsisten + deteksi gerak via anchor
final idleDuration = DateTime.now().difference(_lastMovementWallTime);
if (idleDuration >= _idleTimeout) _performAutoStop();
```

> "Saya ganti jadi konsisten pakai jam device, dan deteksi 'bergerak' pakai titik jangkar dengan threshold 50 meter — biar jitter GPS pas parkir nggak terus-terusan nge-reset timer. Plus saya kasih dua pemicu: timer berkala DAN tiap ada GPS fix masuk, karena timer bisa di-suspend OS saat layar mati."

**Kenapa ini "flex":** menunjukkan kemampuan **debugging sistematis** — nemu akar masalah yang halus (clock mismatch), bukan nambal gejala.

---

### Flex C — Native Google Sign-In ke Supabase self-hosted

**Masalah:**
> "Saya mau login Google, tapi Supabase saya self-hosted di server sendiri lewat Cloudflare Tunnel. Cara OAuth redirect biasa butuh setup redirect URL yang ribet."

**Solusinya — native sign-in (token-based):**
```dart
// lib/services/google_auth_service.dart
final account = await googleSignIn.signIn();          // dialog native di HP
final auth = await account.authentication;            // dapat idToken dari Google
await Supabase.instance.client.auth.signInWithIdToken( // server verifikasi token
  provider: OAuthProvider.google,
  idToken: auth.idToken!,
  accessToken: auth.accessToken,
);
```

**Cara ngejelasinnya:**
> "Daripada OAuth redirect, saya pakai native sign-in: dialog Google jalan di HP, dapat token, lalu token-nya saya kirim ke Supabase buat diverifikasi. Server cukup tahu daftar client ID yang sah. Ini lebih cocok buat self-hosted dan nggak butuh redirect URL publik."

**Kenapa ini "flex":** menunjukkan kamu paham **alur autentikasi token** dan bisa adaptasi solusi ke kendala infrastruktur nyata (self-hosted, bukan layanan managed).

---

## Penutup Presentasi

**Kalimat penutup:**
> "Jadi singkatnya: saya nggak cuma bikin aplikasi yang jalan. Saya merancang **strukturnya supaya gampang dirawat**, milih **tool sesuai skala masalah**, jaga **keamanan di level database**, dan pas nemu masalah di dunia nyata, saya **perbaiki berdasarkan data**. Saya arsiteknya — AI cuma bantu ngetik boilerplate, logika tingkat tingginya saya yang pegang."

---

## Lampiran — Cheat Sheet Tanya Jawab

| Pertanyaan mungkin | Jawaban singkat |
|---|---|
| "Kenapa nggak pakai BLoC/Riverpod?" | Over-engineering buat skala ini. FutureBuilder + ChangeNotifier udah cukup & lebih sedikit boilerplate. Memilih tool sesuai skala = keputusan arsitektur. |
| "Gimana kalau data-nya banyak banget?" | Repository pakai pagination (`limit`/`range`), trip waypoint di-batch, dan query di-scope per-vehicle. |
| "Aman nggak datanya?" | Row Level Security di Postgres — tiap baris di-scope `user_id = auth.uid()`. Anon key aman di client; service_role key nggak pernah masuk app. |
| "Kalau backend ganti gimana?" | Cuma `repository.dart` yang disentuh. UI nggak tahu soal Supabase. |
| "AI-nya jalan di mana?" | Di Supabase Edge Function (Deno), bukan di client. API key aman di server. Voice di-transcribe on-device dulu biar hemat token. |
| "Ini pakai AI buat coding ya?" | Iya, buat boilerplate. Tapi arsitektur, pemilihan pola, dan perbaikan logika berbasis data nyata — itu keputusan saya. (lalu tunjukkan Flex A plot-twist) |
