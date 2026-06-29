# BensinKu — Arsitektur Detail

> Dokumen ini melengkapi [`README.md`](README.md). Tiap cuplikan kode disertai penjelasan baris-per-baris dalam bahasa sehari-hari supaya mudah dipahami meski belum biasa coding.
>
> **Cara baca:** Tiap blok kode diikuti kotak "Penjelasan" yang menjabarkan kegunaan setiap baris. Kalau bagian terlalu teknis, anggap saja sebagai mesin yang mengerjakan tugas tertentu — yang penting kamu paham _kenapa_ dan _kapan_ baris itu dipakai, bukan detail sintaksisnya.

---

## Daftar Isi

1. [Ringkasan Sistem](#1-ringkasan-sistem)
2. [Tech Stack & Dependencies](#2-tech-stack--dependencies)
3. [Diagram Arsitektur Tinggi](#3-diagram-arsitektur-tinggi)
4. [Struktur Folder](#4-struktur-folder)
5. [App Bootstrap & Auth Gate](#5-app-bootstrap--auth-gate)
6. [Data Layer (Models + Repository)](#6-data-layer-models--repository)
7. [Service Layer](#7-service-layer)
   - 7.1 [TripService — GPS streaming](#71-tripservice--gps-streaming)
   - 7.2 [PredictionService — Bayesian km/L](#72-predictionservice--bayesian-kml)
   - 7.3 [RefuelParserService — AI parser client](#73-refuelparserservice--ai-parser-client)
   - 7.4 [NotificationService](#74-notificationservice)
   - 7.5 [HomeWidgetService + WidgetLaunchIntent](#75-homewidgetservice--widgetlaunchintent)
   - 7.6 [VehicleAssets](#76-vehicleassets)
8. [Feature Modules (UI)](#8-feature-modules-ui)
9. [Backend — Supabase](#9-backend--supabase)
   - 9.1 [Schema & RLS](#91-schema--rls)
   - 9.2 [Migrations Strategy](#92-migrations-strategy)
   - 9.3 [Edge Functions (Deno + OpenAI)](#93-edge-functions-deno--openai)
10. [Map & Rute (OpenStreetMap)](#10-map--rute-openstreetmap)
11. [Native Integrations (Android Widget)](#11-native-integrations-android-widget)
12. [Aliran Data End-to-End](#12-aliran-data-end-to-end)
13. [Theme & Visual System](#13-theme--visual-system)
14. [Lampiran — File Index](#lampiran--file-index-untuk-navigasi-cepat)

---

## 1. Ringkasan Sistem

BensinKu adalah aplikasi pencatat bahan bakar pribadi dengan tiga karakteristik utama:

1. **Adaptive prediction** — estimasi km/L pakai Bayesian blend antara prior (spec kendaraan + konteks user) dan ground-truth dari full-tank cycle.
2. **AI input shortcut** — dua jalur cepat: scan struk SPBU (vision LLM) dan voice command (transcribe on-device + LLM parsing).
3. **Trip recorder** — GPS background tracker dengan foreground service Android dan `allowBackgroundLocationUpdates` di iOS, plus auto-stop saat idle 30 menit.

Frontend = Flutter single-codebase. Backend = Supabase (Auth + Postgres dengan RLS + Edge Functions Deno). Maps = OpenStreetMap tile publik.

Istilah singkat:

| Istilah | Arti praktis |
|---|---|
| **Flutter** | Framework dari Google untuk bikin app Android & iOS pakai satu kode (bahasa Dart). |
| **Supabase** | Backend instan: database PostgreSQL + sistem login + serverless function. |
| **RLS (Row Level Security)** | Aturan di database yang memastikan tiap user cuma bisa lihat data miliknya sendiri. |
| **Edge Function** | Fungsi server kecil yang dipanggil lewat HTTP, dijalankan di edge network Supabase. |
| **OSM (OpenStreetMap)** | Sumber peta gratis, alternatif Google Maps. |
| **Bayesian blend** | Cara matematis menggabungkan tebakan awal dengan data nyata, makin banyak data makin akurat. |

---

## 2. Tech Stack & Dependencies

Sumber: [`pubspec.yaml`](pubspec.yaml)

| Kategori | Package | Versi | Fungsi |
|---|---|---|---|
| Backend client | `supabase_flutter` | `^2.12.2` | Auth, Postgres REST, Edge Functions, Storage |
| Postgres builder | `postgrest` | `^2.6.0` | Query builder per schema (`bensinku`) |
| Maps | `flutter_map` | `^7.0.2` | Renderer tile + polyline + marker |
| Maps coordinate | `latlong2` | `^0.9.1` | Tipe `LatLng` |
| GPS | `geolocator` | `^13.0.2` | Position stream + permission handler |
| Voice | `speech_to_text` | `^7.0.0` | Transcribe on-device untuk dikirim ke llm (Harus di transcribe dulu on device agar yang dikirim ke llm bentuk text agar penggunaan token bisa lebih hemat) |
| Camera | `image_picker` | `^1.1.2` | Ambil foto / pilih galeri |
| Notifikasi | `flutter_local_notifications` | `^18.0.1` | Notif auto-stop trip setelah idle selama 30menit |
| Home widget | `home_widget` | `^0.7.0` | Bridge ke Android widget |
| Permission | `permission_handler` | `^11.3.1` | Permission OS-level (Kamera, Location (Harus Always On), dan Notification) |
| Splash | `flutter_native_splash` | `^2.4.3` | Splash screen |
| SVG | `flutter_svg` | `^2.0.17` | Render asset SVG |
| Localization | `intl` | `^0.20.2` | Format tanggal Bahasa Indonesia |
| Typography | `google_fonts` | `^6.3.0` | IBM Plex Mono + Sans |

**Cara baca tabel:** "package" itu pustaka kode siap-pakai yang di-download otomatis saat `flutter pub get`. Tanda `^` di depan versi artinya "versi ini atau yang lebih baru tapi tetap di major version yang sama" (mis. `^2.12.2` boleh upgrade ke `2.x.x` apa saja, tapi bukan `3.x`).

---

## 3. Diagram Arsitektur

```
┌────────────────────────────────────────────────────────────────────┐
│                          FLUTTER CLIENT                            │
│                                                                    │
│  main.dart ─▶ AppConfig.fromEnv ─▶ SupabaseBootstrap.tryInitialize │
│                                                                    │
│  BensinKuApp                                                       │
│   └─ _AuthGate (listen onAuthStateChange)                          │
│       ├─ no session  ─▶  SignInPage                                │
│       └─ has session ─▶  _RegisteredGate                           │
│                          ├─ no name        ─▶ WelcomePage          │
│                          ├─ no vehicle     ─▶ AddVehiclePage       │
│                          ├─ vehicle incomp ─▶ CompleteVehicleData  │
│                          ├─ no prefs       ─▶ SetupPreferencesPage │
│                          └─ all good       ─▶ HomeShell            │
│                                                                    │
│  HomeShell (5 tabs: Beranda, Analisa, +, Arsip, Rute)              │
│   ├─ SummaryTab                                                    │
│   ├─ AnalyticsTab                                                  │   
│   ├─ FAB Button #Voice, Manual Add, OCR                            │
│   ├─ HistoryTab                                                    │
│   └─ TripMapScreen (FlutterMap + GPS stream)                       │
│                                                                    │
│  Services (singleton-ish):                                         │
│   • SupabaseRepository  (DB I/O ke schema bensinku)                │
│   • TripService         (GPS stream + waypoint batch)              │
│   • PredictionService   (stateless static, Bayesian km/L)          │
│   • RefuelParserService (panggil edge functions)                   │
│   • HomeWidgetService   (push data ke widget Android)              │
│   • NotificationService (notif lokal auto-stop)                    │
└────────────────────────────────────────────────────────────────────┘
                │                       │                  │
    REST (RLS) Database           Edge Functions      Tile request
                ▼                       ▼                  ▼
┌──────────────────────┐  ┌──────────────────────┐  ┌──────────────┐
│  Supabase Postgres   │  │  Supabase Edge (Deno)│  │  OSM Tiles   │
│  schema: bensinku    │  │  parse-fuel-receipt  │  │(free, no key)│
│  • vehicles          │  │  parse-fuel-voice    │  └──────────────┘
│  • refuels           │  └──────────┬───────────┘
│  • trips             │             │
│  • trip_waypoints    │             ▼
│  • fuel_products     │  ┌───────────────────────┐  #Routing dengan 9router (Open Source)
│  • fuel_prices       │  │   OpenAI Vision/Chat  │   dengan Output API OpenRouter compatible
│  • fuel_efficiency_  │  │(gemini 3.5 flash lite)│  #Gemini Free Tier Account x 4 Account 
│    samples           │  └───────────────────────┘  
│  RLS: user_id =      │
│       auth.uid()     │
└──────────────────────┘
```

**Cara baca diagram:** Kotak besar di atas = aplikasi yang berjalan di HP user. Tiga kotak di bawah = layanan eksternal yang dihubungi via internet. Panah menunjukkan arah komunikasi. Tiga jalur keluar dari Flutter:

- **REST (RLS)** — komunikasi langsung ke database Supabase untuk CRUD (create-read-update-delete) data.
- **Edge Functions** — panggilan ke fungsi server saat user pakai voice atau scan struk.
- **Tile request** — download gambar peta dari OpenStreetMap.


---

## 4. Struktur Folder

```
bensinku/
├── lib/                          ← Flutter Dart code
│   ├── main.dart                 ← Entry point
│   ├── app/
│   │   ├── app.dart              ← MaterialApp + Auth Gate routing
│   │   └── theme.dart            ← AppEditorial palette + typography
│   ├── config/
│   │   └── app_config.dart       ← Env var loader (SUPABASE_URL/ANON_KEY)
│   ├── data/
│   │   ├── models.dart           ← Dart models + enum (Vehicle, Refuel, Trip…)
│   │   └── repository.dart       ← SupabaseRepository (semua DB I/O)
│   ├── features/
│   │   ├── auth/                 ← Sign in / sign up / forgot / verify
│   │   ├── onboarding/           ← Welcome, profile, vehicle, preferences
│   │   ├── home/                 ← Dashboard, analisa, arsip, profil, sheets
│   │   └── trip/                 ← Trip GPS recorder + replay detail
│   ├── services/                 ← Logic modules (DB-agnostic-ish)
│   └── widgets/
│       └── vehicle_cover.dart    ← Komponen reusable
│
├── supabase/                     ← Backend
│   ├── schema.sql                ← Initial schema (referensi)
│   ├── seed.sql                  ← Seed master fuel_products
│   ├── upgrade_2026_04_13.sql    ← Patch lama (sudah disuperseded migrations)
│   ├── migrations/               ← Forward-only migrations
│   │   ├── 20260514120000_move_to_bensinku_schema.sql
│   │   └── 20260515090000_predictions_v2.sql
│   └── functions/                ← Deno Edge Functions
│       ├── parse-fuel-receipt/
│       └── parse-fuel-voice/
│
├── android/                      ← Native Android (Kotlin)
│   └── app/src/main/kotlin/com/temanlabs/bensinku/
│       ├── MainActivity.kt       ← Method channel + deeplink handler
│       └── BensinKuWidgetProvider.kt  ← Home widget 4×2
│
├── ios/, macos/, linux/, windows/, web/   ← Platform projects (default)
│
├── assets/
│   ├── illustrations/            ← Editorial scene illustrations
│   ├── vehicles/                 ← Vehicle photo assets
│   └── icon.png
│
├── server/                       ← Self-host Supabase scripts
├── pubspec.yaml                  ← Flutter dependencies
├── supabase.defines.example.json ← Template env config
└── supabase.json                 ← Supabase CLI link config
```

**Cara baca:** Folder `lib/` itu otak app — semua kode UI dan logic Dart ada di sini. Folder `supabase/` adalah backend (database schema + edge function). Folder `android/` & `ios/` & teman-temannya adalah project native untuk tiap platform; biasanya hanya disentuh saat butuh fitur platform-specific (mis. home widget Android di `BensinKuWidgetProvider.kt`).

---

## 5. App Bootstrap & Auth Gate

"Bootstrap" = proses booting/penyiapan saat app baru dibuka. "Auth gate" = pintu yang menentukan user mau diarahkan ke mana berdasarkan status login.

### 5.1 Entry point — [`lib/main.dart`](lib/main.dart)

Ini file pertama yang dieksekusi saat app dibuka. Tugasnya: siapkan semua infra (splash, status bar, locale, Supabase, notifikasi) sebelum menampilkan UI pertama.

```dart
// lib/main.dart
Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  SystemChrome.setSystemUIOverlayStyle( /* ... status bar ikon gelap ... */ );
  await initializeDateFormatting('id_ID', null);

  try { await NotificationService.instance.init(); } catch (_) {}

  final config = AppConfig.fromEnv();
  final supabaseReady = await SupabaseBootstrap.tryInitialize(config);

  FlutterNativeSplash.remove();
  runApp(BensinKuApp(config: config, supabaseReady: supabaseReady));
}
```

**Penjelasan baris demi baris:**

- `Future<void> main() async {` — Mendeklarasikan fungsi utama. `Future` artinya operasi yang butuh waktu (asinkron). `async` menandai fungsi ini boleh memakai kata kunci `await`.
- `final binding = WidgetsFlutterBinding.ensureInitialized();` — Memastikan engine Flutter siap sebelum kita panggil hal lain. Tanpa ini, plugin native belum bisa dipakai.
- `FlutterNativeSplash.preserve(widgetsBinding: binding);` — Menahan splash screen tetap tampil. Tanpa baris ini, splash hilang terlalu cepat dan user lihat layar kosong.
- `SystemChrome.setSystemUIOverlayStyle(...)` — Mengatur tampilan status bar HP (jam, baterai, sinyal). Di sini disetel transparan dengan ikon gelap supaya kontras dengan background cream.
- `await initializeDateFormatting('id_ID', null);` — Memuat data lokalisasi tanggal Indonesia. Setelah ini, format `'EEEE, d MMM yyyy'` bisa hasilkan "Senin, 26 Mei 2026".
- `try { await NotificationService.instance.init(); } catch (_) {}` — Inisialisasi sistem notifikasi. Dibungkus `try/catch` supaya kalau user tolak permission, app tetap jalan, hanya saja notifikasi tidak muncul.
- `final config = AppConfig.fromEnv();` — Baca konfigurasi (URL Supabase + anon key) yang di-set saat compile via `--dart-define`.
- `final supabaseReady = await SupabaseBootstrap.tryInitialize(config);` — Coba sambung ke Supabase. Hasilnya `true`/`false`.
- `FlutterNativeSplash.remove();` — Setelah semua siap, hilangkan splash supaya UI utama bisa muncul.
- `runApp(BensinKuApp(...));` — Jalankan widget root aplikasi. Ini titik di mana Flutter mulai render UI.

Tiga fail-safe penting:

- **Splash dipertahankan** sampai semua init selesai supaya user tidak melihat layar putih.
- **Notification init dibungkus try/catch** — kalau permission ditolak, app tetap jalan tanpa notif.
- **Supabase init bisa gagal** tanpa crash — `tryInitialize` return `bool`, dan kalau `false` UI menampilkan halaman _ConfigMissingPage_ alih-alih HomeShell.

### 5.2 Config loader — [`lib/config/app_config.dart`](lib/config/app_config.dart)

```dart
factory AppConfig.fromEnv() {
  const url = String.fromEnvironment('SUPABASE_URL');
  const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  return AppConfig(
    supabaseUrl: url.trim().isEmpty ? null : url.trim(),
    supabaseAnonKey: anonKey.trim().isEmpty ? null : anonKey.trim(),
  );
}
```

**Penjelasan baris demi baris:**

- `factory AppConfig.fromEnv() {` — `factory` adalah jenis constructor di Dart yang boleh memilih instance mana yang dikembalikan. Di sini namanya `fromEnv` artinya "buat dari environment variable".
- `const url = String.fromEnvironment('SUPABASE_URL');` — `String.fromEnvironment` membaca variabel saat **compile time**. Kalau saat build dijalankan `--dart-define=SUPABASE_URL=https://abc.supabase.co`, isi variabel itu langsung tertanam di binary. `const` menandakan nilainya konstan dan diketahui saat kompilasi.
- `const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');` — Sama untuk anon key (kunci public yang dipakai untuk autentikasi anonim ke Supabase).
- `return AppConfig(...)` — Bikin objek `AppConfig` dengan dua field.
- `url.trim().isEmpty ? null : url.trim()` — `.trim()` menghapus spasi di depan/belakang. `? null : ...` adalah operator ternary: kalau setelah trim string-nya kosong, isi `null`; selain itu pakai versi trim. Ini bikin URL kosong di-treat sama dengan tidak diset.

Disarankan pakai file daripada flag manual:

```bash
flutter run --dart-define-from-file=supabase.defines.json
```

`supabase.defines.json` (sudah di-`.gitignore`) berisi:

```json
{ "SUPABASE_URL": "https://xxx.supabase.co", "SUPABASE_ANON_KEY": "eyJ..." }
```

### 5.3 Supabase bootstrap — [`lib/services/supabase_bootstrap.dart`](lib/services/supabase_bootstrap.dart)

```dart
class SupabaseBootstrap {
  static Future<bool> tryInitialize(AppConfig config) async {
    if (!config.hasSupabase) return false;
    try {
      await Supabase.initialize(
        url: config.supabaseUrl!,
        anonKey: config.supabaseAnonKey!,
      );
      return true;
    } catch (_) { return false; }
  }
}
```

**Penjelasan baris demi baris:**

- `class SupabaseBootstrap {` — Mendefinisikan kelas utility dengan satu method static.
- `static Future<bool> tryInitialize(AppConfig config) async {` — Method static (dipanggil tanpa bikin instance). `Future<bool>` = fungsi async yang akhirnya menghasilkan boolean.
- `if (!config.hasSupabase) return false;` — Kalau config tidak punya URL+anon key (mis. user lupa set `--dart-define`), langsung balik `false`.
- `await Supabase.initialize(...)` — Inisialisasi client Supabase global. Setelah ini, `Supabase.instance.client` bisa dipakai di mana saja.
- `url: config.supabaseUrl!,` — Tanda `!` adalah _bang operator_: "saya jamin ini tidak null". Karena di baris atasnya kita sudah cek `hasSupabase`, kita yakin nilainya bukan null.
- `return true;` — Kalau initialize sukses tanpa exception, balik `true`.
- `} catch (_) { return false; }` — Kalau initialize gagal (mis. URL salah, network error), tangkap exception, balik `false`. Karakter `_` artinya "tidak peduli detail exception-nya".

### 5.4 Auth Gate — [`lib/app/app.dart`](lib/app/app.dart)

`_AuthGate` mendengarkan perubahan status login. Kalau user logout (entah karena tap tombol Logout atau session expired), semua route yang terlanjur ke-push akan di-pop sampai root supaya tidak ada UI stale di atas SignInPage:

```dart
// lib/app/app.dart
if (wasSignedIn && !nowSignedIn) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    final nav = Navigator.of(context, rootNavigator: true);
    nav.popUntil((r) => r.isFirst);
  });
}
```

**Penjelasan baris demi baris:**

- `if (wasSignedIn && !nowSignedIn) {` — Cek transisi: tadinya logged-in, sekarang tidak. Artinya barusan logout.
- `WidgetsBinding.instance.addPostFrameCallback((_) { ... });` — Jadwalkan callback dijalankan **setelah frame UI berikutnya selesai render**. Tanpa ini, kita mencoba navigasi sambil widget masih rebuild dan hasilnya bisa crash.
- `if (!mounted) return;` — Cek apakah widget masih hidup. Kalau user keburu close app, jangan lanjut.
- `final nav = Navigator.of(context, rootNavigator: true);` — Ambil navigator paling atas (root). `rootNavigator: true` penting karena dialog/modal punya navigator sendiri.
- `nav.popUntil((r) => r.isFirst);` — Pop semua route sampai cuma tersisa route paling pertama. Hasilnya: layar kembali ke SignInPage tanpa peninggalan UI sebelumnya.

### 5.5 Onboarding flow — `_RegisteredGate`

Ini "single source of truth" untuk routing onboarding. Tiap boot, gate ini eksekusi 4 cek berurutan:

```dart
// lib/app/app.dart — _RegisteredGate.build
if (!_hasName(client))                        return WelcomePage();
final vehicles = await repo.listVehicles();
if (vehicles.isEmpty)                          return AddVehiclePage(...);
if (anyVehicleIncompleteRefData)               return CompleteVehicleDataPage(...);
if (!_hasRequiredPreferences(client))          return SetupPreferencesPage(...);
return HomeShell();
```

**Penjelasan baris demi baris:**

- `if (!_hasName(client)) return WelcomePage();` — Cek apakah user sudah isi nama tampilan di profilnya. Kalau belum, lempar ke halaman selamat datang.
- `final vehicles = await repo.listVehicles();` — Ambil daftar kendaraan dari database. `await` artinya tunggu sampai data datang sebelum lanjut.
- `if (vehicles.isEmpty) return AddVehiclePage(...);` — Belum ada satu pun kendaraan? Suruh user tambah dulu.
- `if (anyVehicleIncompleteRefData) return CompleteVehicleDataPage(...);` — Ada kendaraan tapi datanya belum komplet (CC, tahun, transmisi, dll)? Lengkapi dulu — ini wajib karena algoritma prediksi butuh data ini.
- `if (!_hasRequiredPreferences(client)) return SetupPreferencesPage(...);` — Belum isi profil pakai (komuter/weekend/dll) dan kota utama? Setup dulu.
- `return HomeShell();` — Semua syarat lulus, masuk ke dashboard utama.

Konsekuensi: kalau user kill app di tengah onboarding, boot berikutnya auto-resume di langkah yang belum selesai. `_refresh()` (bump `_refreshKey`) memaksa FutureBuilder re-fetch setelah user submit form.

`hasCompleteReferenceData` ada di model extension — semua field detail mesin wajib; body_type wajib khusus mobil:

```dart
// lib/data/models.dart
extension VehicleCompleteness on Vehicle {
  bool get hasCompleteReferenceData {
    if (tankCapacityLiters == null) return false;
    if (engineCc == null) return false;
    if (manufacturingYear == null) return false;
    if (transmission == null) return false;
    if (type == VehicleType.mobil && bodyType == null) return false;
    return true;
  }
}
```

**Penjelasan baris demi baris:**

- `extension VehicleCompleteness on Vehicle {` — Extension Dart: nempelin method baru ke kelas `Vehicle` tanpa modifikasi kelas itu. Berguna saat kelas asal mau dijaga tetap minimal (cuma data) tapi butuh logic turunan.
- `bool get hasCompleteReferenceData {` — Getter (property) yang menghitung sesuatu setiap kali diakses. Dari luar kelihatan seperti `vehicle.hasCompleteReferenceData`, padahal di belakang ada logic.
- `if (tankCapacityLiters == null) return false;` — Cek satu per satu field wajib. Ada satu yang null → kendaraan dianggap belum lengkap.
- `if (type == VehicleType.mobil && bodyType == null) return false;` — Khusus mobil: body_type wajib (sedan/MPV/SUV/dll). Motor tidak punya body_type jadi field ini null untuk motor adalah normal.
- `return true;` — Semua cek lewat, kendaraan ini lengkap.


---

## 6. Data Layer (Models + Repository)

"Data layer" = lapisan kode yang ngurus tipe data (model) dan komunikasi ke database. UI tidak ngomong langsung ke Supabase — UI lewat repository, yang lewat model, yang akhirnya translate ke SQL.

### 6.1 Models — [`lib/data/models.dart`](lib/data/models.dart)

Tipe utama dengan padanan kolom Postgres-nya:

| Class | Tabel Postgres | Field penting |
|---|---|---|
| `Vehicle` | `bensinku.vehicles` | `id`, `type`, `name`, `tankCapacityLiters`, `engineCc`, `manufacturingYear`, `bodyType`, `transmission`, `recommendedRon`, `makeModel` |
| `Refuel` | `bensinku.refuels` | `id`, `vehicleId`, `fuelProductId`, `refuelDate`, `odometerKm`, `totalRp`, `pricePerLiterSnapshot`, `liters`, `isFullTank` |
| `Trip` | `bensinku.trips` | `id`, `vehicleId`, `startedAt`, `endedAt`, `distanceKm`, `note` |
| `TripWaypoint` | `bensinku.trip_waypoints` | `tripId`, `lat`, `lng`, `recordedAt` |
| `FuelProduct` | `bensinku.fuel_products` | `id`, `brand`, `name` |
| `FuelPrice` | `bensinku.fuel_prices` | `pricePerLiter` |
| `EfficiencySample` | `bensinku.fuel_efficiency_samples` | `id`, `vehicleId`, `kmTraveled`, `litersFilled`, `kmPerLiter`, `measuredAt` |
| `ParsedRefuel` | (response edge function) | Hasil parsing AI sebelum dikonfirmasi user |

Enum-enum bersifat self-documenting — tiap value carry `dbValue` string yang persis match dengan CHECK constraint Postgres:

```dart
// lib/data/models.dart
enum VehicleType { motor('motor'), mobil('mobil'); ... }
enum BodyType { sedan, hatchback, mpv, suv, pickup, sport; ... }
enum Transmission { manual, at, cvt, dct; ... }
enum UsageProfile { dailyCommute('daily_commute', 'Komuter harian'), ... }
enum PrimaryCity { jakarta, bandung, surabaya, midSized, rural; ... }
```

**Penjelasan baris demi baris:**

- `enum VehicleType { motor('motor'), mobil('mobil'); ... }` — Enum dengan parameter konstruktor. `motor('motor')` artinya value `motor` di Dart memetakan ke string `'motor'` di database. Penyamaan persis ini bikin Dart enum & Postgres CHECK constraint sinkron — nggak akan ada typo silent.
- `enum BodyType { sedan, hatchback, mpv, suv, pickup, sport; ... }` — Daftar enum nilainya: sedan/hatchback/MPV/SUV/pickup/sport. Setiap nama berfungsi sebagai konstanta yang bisa dipakai di seluruh kode (mis. `BodyType.suv`).
- `enum Transmission { manual, at, cvt, dct; ... }` — Empat jenis transmisi yang dikenali sistem. `at` = automatic transmission konvensional, `cvt` = continuously variable, `dct` = dual-clutch.
- `enum UsageProfile { dailyCommute('daily_commute', 'Komuter harian'), ... }` — Enum dengan dua field: nilai DB + label Indo siap-tampil. Ini bikin tidak perlu mapping manual antara value DB dan tulisan UI.

Octane rating divalidasi lewat helper class `OctaneRating` (RON 88/90/92/95/98 — nilai di luar itu ditolak Postgres CHECK constraint).

### 6.2 Repository — [`lib/data/repository.dart`](lib/data/repository.dart)

`SupabaseRepository` adalah satu-satunya tempat yang ngomong langsung ke Supabase REST. Semua feature widget masuk lewat sini — gak ada `Supabase.instance.client.from(...)` tersebar di feature folder.

Pola kunci: pakai `_client.schema('bensinku')` supaya semua `.from('vehicles')` otomatis resolve ke `bensinku.vehicles`:

```dart
// lib/data/repository.dart
class SupabaseRepository {
  SupabaseRepository(this._client) : _db = _client.schema(_schemaName);

  static const String _schemaName = 'bensinku';
  final SupabaseClient _client;
  final SupabaseQuerySchema _db;

  static SupabaseRepository ofDefaultClient() {
    return SupabaseRepository(Supabase.instance.client);
  }
  ...
}
```

**Penjelasan baris demi baris:**

- `class SupabaseRepository {` — Kelas yang membungkus semua akses database.
- `SupabaseRepository(this._client) : _db = _client.schema(_schemaName);` — Constructor yang menerima Supabase client lalu langsung "lock" ke schema `bensinku`. Singkatan `this._client` artinya parameter ini langsung disimpan ke field `_client`. Setelah titik dua, `_db` di-init dari `_client.schema(_schemaName)`.
- `static const String _schemaName = 'bensinku';` — Konstanta nama schema. Underscore di depan = field privat (tidak bisa diakses dari luar file).
- `final SupabaseClient _client;` — Field menyimpan client mentah. `final` artinya hanya boleh di-assign sekali.
- `final SupabaseQuerySchema _db;` — Field menyimpan query builder yang sudah ter-scope ke schema bensinku. Dari sini kita panggil `_db.from('vehicles')` dan otomatis itu jadi `bensinku.vehicles`.
- `static SupabaseRepository ofDefaultClient() {` — Factory method shortcut. Biasanya kode lain panggil `SupabaseRepository.ofDefaultClient()` daripada bikin instance manual setiap kali.
- `return SupabaseRepository(Supabase.instance.client);` — Bikin repository pakai client default global.

#### Error mapping — `_run()`

Setiap operasi DB dibungkus `_run`. Kalau Postgres balas `PGRST205` ("table not found in schema cache"), repository transform jadi pesan Bahasa Indonesia yang actionable:

```dart
// lib/data/repository.dart
StateError? _mapPostgrestException(PostgrestException e) {
  final looksLikeMissingTable =
      e.code == 'PGRST205' ||
      e.message.contains('schema cache') ||
      e.message.contains("Could not find the table");
  if (!looksLikeMissingTable) return null;
  return StateError(
    'Backend belum siap: tabel ... belum ada di database Supabase.\n'
    'Jalankan `supabase/schema.sql` lalu `supabase/seed.sql` di Supabase Studio → SQL Editor.\n'
    ...
  );
}
```

**Penjelasan baris demi baris:**

- `StateError? _mapPostgrestException(PostgrestException e) {` — Fungsi privat yang menerima exception dari Postgres dan mungkin (tanda `?`) mengembalikan StateError baru. Tanda `?` artinya hasilnya bisa null kalau tidak match pola.
- `final looksLikeMissingTable = e.code == 'PGRST205' || ...` — Cek dengan tiga heuristik apakah error ini soal "table not found". `||` adalah OR logical: cukup salah satu true.
- `if (!looksLikeMissingTable) return null;` — Kalau bukan error tabel hilang, kembalikan null (artinya: biarkan error asli dilempar apa adanya).
- `return StateError('Backend belum siap...');` — Bikin error baru dengan pesan Bahasa Indonesia yang menjelaskan apa yang salah dan apa yang harus dilakukan. Pesan teknis Postgres yang asing diubah jadi instruksi yang bisa diikuti.

#### Side effect: auto-recording efficiency sample

Ini bagian penting buat feature prediksi. Setiap kali `createRefuel` dengan `is_full_tank=true`, repository cari refuel full-tank sebelumnya dan otomatis insert satu row di `fuel_efficiency_samples`:

```dart
// lib/data/repository.dart — createRefuel
if (created.isFullTank) {
  try {
    await _maybeRecordFullTankCycle(created);
  } catch (_) { /* swallow — opportunistic */ }
}
```

**Penjelasan baris demi baris:**

- `if (created.isFullTank) {` — Kalau pengisian yang barusan disimpan ditandai sebagai full tank. Hanya full-tank → full-tank yang punya makna untuk pengukuran efisiensi.
- `await _maybeRecordFullTankCycle(created);` — Jalankan logic pencatatan sample. `await` artinya tunggu selesai sebelum lanjut.
- `} catch (_) { /* swallow — opportunistic */ }` — Kalau pencatatan sample gagal (misal koneksi putus), abaikan saja. Refuel-nya sendiri sudah berhasil disimpan, sample efisiensi sifatnya bonus — gagal pun tidak fatal.

Logic `_maybeRecordFullTankCycle`:

1. Cari refuel full-tank sebelumnya untuk vehicle yang sama.
2. Hitung km traveled — **prefer odometer delta** (`curOdo - prevOdo`).
3. Fallback: jumlahkan `distance_km` dari trips di interval itu.
4. Kalau masih nol, skip.
5. Insert sample. Unique index `(vehicle_id, from_refuel_id, to_refuel_id)` bikin operasi idempotent (kalau dipanggil ulang, error 23505 di-swallow).

```dart
// lib/data/repository.dart — recordEfficiencySample
} on PostgrestException catch (e) {
  if (e.code == '23505') return null;  // unique_violation — sudah ada
  rethrow;
}
```

**Penjelasan baris demi baris:**

- `} on PostgrestException catch (e) {` — Tangkap khusus exception dari Postgres. `on` adalah cara Dart untuk catch tipe error tertentu saja.
- `if (e.code == '23505') return null;` — Code `23505` adalah kode standar Postgres untuk pelanggaran unique constraint. Artinya: row dengan kombinasi yang sama sudah ada di database. Karena unique constraint kita pasang sengaja untuk idempotency, ini bukan error sungguhan — return null saja.
- `rethrow;` — Kalau error-nya bukan unique violation, lempar lagi ke pemanggil supaya ditangani lebih atas.

#### Trip insertion

`createTrip`/`endTrip` dan batch `addWaypoints` adalah method yang dipanggil `TripService` (lihat [§7.1](#71-tripservice--gps-streaming)):

```dart
// lib/data/repository.dart
Future<Trip> createTrip({required String vehicleId}) async { ... }
Future<Trip> endTrip({required String tripId, required double distanceKm,
                       DateTime? endedAt}) async { ... }
Future<void> addWaypoints(List<TripWaypoint> waypoints) async {
  if (waypoints.isEmpty) return;
  await _db.from('trip_waypoints').insert(waypoints.map((w) => w.toJson()).toList());
}
```

**Penjelasan baris demi baris (`addWaypoints`):**

- `Future<void> addWaypoints(List<TripWaypoint> waypoints) async {` — Method async yang menerima list waypoint dan tidak mengembalikan apa-apa berarti (`Future<void>`).
- `if (waypoints.isEmpty) return;` — Kalau list kosong (tidak ada waypoint baru), keluar tanpa hit DB. Hemat round-trip network.
- `await _db.from('trip_waypoints').insert(waypoints.map((w) => w.toJson()).toList());` — Tulis ke tabel `trip_waypoints`. `waypoints.map((w) => w.toJson())` mengubah tiap waypoint menjadi map JSON, lalu `.toList()` ubah jadi list. `insert(...)` Supabase menerima list = batch insert sekali jalan.


---

## 7. Service Layer

"Service" di sini bukan service backend, tapi modul Dart yang membungkus logic kompleks supaya UI tetap tipis.

### 7.1 TripService — GPS streaming

File: [`lib/services/trip_service.dart`](lib/services/trip_service.dart)

Tanggung jawab:

1. Minta location permission (escalate `whileInUse` → `always`).
2. Buka `Geolocator.getPositionStream` dengan **platform-specific settings**.
3. Akumulasi waypoint, hitung distance, push batch ke Supabase tiap 30 detik.
4. Auto-stop kalau idle > 30 menit.
5. Notify host (`ChangeNotifier`) supaya UI re-render.

#### Permission flow — `requestPermission()`

```dart
// lib/services/trip_service.dart
static Future<LocationPermissionStatus> requestPermission() async {
  LocationPermission perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
  }
  if (perm == LocationPermission.deniedForever) return permanentlyDenied;
  if (perm == LocationPermission.denied)         return denied;

  // Step 2: try escalate to "Always"
  if (perm == _permWhileInUse) {
    final upgraded = await Geolocator.requestPermission();
    if (upgraded == _permAlways) return alwaysGranted;
    return whileInUseOnly;
  }
  return alwaysGranted;
}
```

**Penjelasan baris demi baris:**

- `static Future<LocationPermissionStatus> requestPermission() async {` — Method static yang akhirnya menghasilkan status permission (enum dengan 4 nilai).
- `LocationPermission perm = await Geolocator.checkPermission();` — Cek permission saat ini tanpa nge-prompt user. Hasil bisa: `denied`, `whileInUse`, `always`, atau `deniedForever`.
- `if (perm == LocationPermission.denied) {` — Belum pernah ditanya / user tolak: kita prompt sekarang.
- `perm = await Geolocator.requestPermission();` — Tampilkan dialog OS minta permission. User klik allow/deny → hasilnya tersimpan di variabel sama.
- `if (perm == LocationPermission.deniedForever) return permanentlyDenied;` — User pilih "Don't ask again". Satu-satunya cara reset = lewat Settings OS.
- `if (perm == LocationPermission.denied) return denied;` — User klik tolak biasa, masih bisa diminta lagi nanti.
- `if (perm == _permWhileInUse) {` — Dapat permission "while using app" tapi belum "always". Coba upgrade.
- `final upgraded = await Geolocator.requestPermission();` — Trigger dialog kedua untuk minta "always". Di Android 11+, OS lempar user ke Settings page.
- `if (upgraded == _permAlways) return alwaysGranted;` — Berhasil di-upgrade → return status terbaik.
- `return whileInUseOnly;` — User tetap pilih while-in-use saja → ini fallback. Tracking jalan tapi pause saat layar mati.

`LocationPermissionStatus` enum dengan empat case (`denied` / `permanentlyDenied` / `whileInUseOnly` / `alwaysGranted`) supaya UI bisa tampilkan UX yang berbeda — `whileInUseOnly` masih bisa rekam tapi akan berhenti saat layar mati, dan UI menampilkan badge "IZIN BG".

#### Platform-aware location settings — `_trackingLocationSettings()`

Tanpa konfigurasi yang benar, GPS akan stop ngirim update saat layar mati. Solusi per platform:

```dart
// lib/services/trip_service.dart
LocationSettings _trackingLocationSettings() {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 15,
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'BensinKu sedang mencatat rute',
        notificationText: 'Tracking GPS berjalan. Tap untuk kembali ke aplikasi.',
        enableWakeLock: true,
        setOngoing: true,
      ),
    );
  }
  if (defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    return AppleSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 15,
      allowBackgroundLocationUpdates: true,
      pauseLocationUpdatesAutomatically: false,
      showBackgroundLocationIndicator: true,
      activityType: ActivityType.automotiveNavigation,
    );
  }
  ...
}
```

**Penjelasan baris demi baris:**

- `LocationSettings _trackingLocationSettings() {` — Method yang return objek setting GPS, beda untuk tiap platform.
- `if (defaultTargetPlatform == TargetPlatform.android) {` — Cek platform runtime. Android dapat config sendiri.
- `return AndroidSettings(` — Setting khusus Android.
- `accuracy: LocationAccuracy.high,` — Akurasi tinggi pakai GPS hardware (bukan cuma WiFi/cell tower). Boros baterai tapi presisinya bagus untuk tracking rute.
- `distanceFilter: 15,` — Hanya kirim update kalau user bergerak ≥15 meter sejak update terakhir. Mencegah membanjiri DB dengan titik saat berhenti di lampu merah.
- `foregroundNotificationConfig: const ForegroundNotificationConfig(` — Konfigurasi notifikasi persisten. Tanpa ini, Android matikan GPS stream saat layar mati.
- `notificationTitle: 'BensinKu sedang mencatat rute',` — Judul notif yang muncul di shade.
- `notificationText: 'Tracking GPS berjalan. Tap untuk kembali ke aplikasi.',` — Body notif.
- `enableWakeLock: true,` — Cegah CPU masuk deep-sleep selama tracking. Kalau false, OS bisa freeze proses dan GPS stream berhenti.
- `setOngoing: true,` — Notif tidak bisa di-swipe oleh user. Memastikan tracking tidak ke-kill tidak sengaja.
- `if (defaultTargetPlatform == TargetPlatform.iOS || ...)` — Cek iOS atau macOS.
- `return AppleSettings(...)` — Setting khusus Apple platform.
- `allowBackgroundLocationUpdates: true,` — Beri tahu iOS bahwa app butuh location update di background. Wajib bareng dengan `UIBackgroundModes: location` di Info.plist.
- `pauseLocationUpdatesAutomatically: false,` — Default iOS akan auto-pause saat user diam, tapi ini bikin trip recorder kita kehilangan titik. Set false supaya jangan di-pause.
- `showBackgroundLocationIndicator: true,` — Tampilkan indikator biru di status bar saat tracking. Penting untuk transparansi privasi.
- `activityType: ActivityType.automotiveNavigation,` — Beri hint ke iOS bahwa context-nya adalah berkendara. iOS optimasi power management based on this hint.

#### Position handler — `_onPosition()`

```dart
// lib/services/trip_service.dart
void _onPosition(Position pos) {
  if (_positions.isNotEmpty) {
    final delta = Geolocator.distanceBetween(
      _positions.last.latitude, _positions.last.longitude,
      pos.latitude, pos.longitude,
    );
    _distanceMeters += delta;
    if (delta > 30) _lastMovingWaypointTime = pos.timestamp;
  }
  _positions.add(pos);
  _pendingWaypoints.add(TripWaypoint(...));
  notifyListeners();
}
```

**Penjelasan baris demi baris:**

- `void _onPosition(Position pos) {` — Callback yang dipanggil tiap kali GPS kasih update posisi baru. Parameter `pos` punya lat, lng, accuracy, timestamp, dll.
- `if (_positions.isNotEmpty) {` — Hanya hitung delta kalau sudah ada minimal 1 posisi sebelumnya.
- `final delta = Geolocator.distanceBetween(...)` — Hitung jarak antara titik terakhir dan titik baru pakai rumus Haversine (yang memperhitungkan kelengkungan bumi).
- `_distanceMeters += delta;` — Tambahkan jarak ini ke akumulator total.
- `if (delta > 30) _lastMovingWaypointTime = pos.timestamp;` — Kalau pergerakan signifikan (>30 m), reset idle timer. Threshold 30 m mengabaikan jitter GPS saat parkir (HP diam tapi koordinat bergeser ±5 m karena multipath dll).
- `_positions.add(pos);` — Simpan posisi ke list lokal untuk render polyline di UI.
- `_pendingWaypoints.add(TripWaypoint(...));` — Tambahkan ke buffer yang akan di-flush ke DB nanti.
- `notifyListeners();` — Karena class ini extend `ChangeNotifier`, panggilan ini bikin semua widget yang listen rebuild dengan data terbaru.

Perhatikan: distance di-akumulasi dari delta posisi consecutive (Haversine). Threshold 30m dipakai untuk reset idle timer — supaya jitter GPS saat parkir tidak bikin idle timer terus-terusan reset.

#### Batched flush

Daripada satu insert per waypoint (mahal di network + bisa rate-limit Supabase), waypoint di-buffer dan flush per 30 detik:

```dart
// lib/services/trip_service.dart
_flushTimer = Timer.periodic(const Duration(seconds: 30), (_) => _flushWaypoints());

Future<void> _flushWaypoints() async {
  if (_pendingWaypoints.isEmpty || _activeTrip == null) return;
  final batch = List<TripWaypoint>.from(_pendingWaypoints);
  _pendingWaypoints.clear();
  try {
    await _repo.addWaypoints(batch);
  } catch (_) {
    _pendingWaypoints.insertAll(0, batch);  // re-queue on failure
  }
}
```

**Penjelasan baris demi baris:**

- `_flushTimer = Timer.periodic(const Duration(seconds: 30), (_) => _flushWaypoints());` — Bikin timer yang fire callback tiap 30 detik. Tiap fire, panggil `_flushWaypoints`. Variabel `_flushTimer` disimpan supaya bisa dimatikan (`.cancel()`) saat trip selesai.
- `Future<void> _flushWaypoints() async {` — Method untuk push buffer ke DB.
- `if (_pendingWaypoints.isEmpty || _activeTrip == null) return;` — Kalau buffer kosong atau sudah tidak ada trip aktif, skip.
- `final batch = List<TripWaypoint>.from(_pendingWaypoints);` — Buat copy snapshot dari pending list. Penting karena saat insert ke DB jalan, GPS bisa kasih update baru ke `_pendingWaypoints` — kita tidak mau diganggu.
- `_pendingWaypoints.clear();` — Kosongkan buffer. Update GPS yang masuk setelah ini akan masuk batch berikutnya.
- `await _repo.addWaypoints(batch);` — Kirim ke Supabase.
- `} catch (_) { _pendingWaypoints.insertAll(0, batch); }` — Kalau gagal (network error, dll), masukkan kembali batch ke awal pending list. Flush berikutnya akan retry. Ini bikin sistem tahan terhadap koneksi terputus sementara.

Kalau insert gagal (sinyal hilang, dll), batch di-prepend balik ke pending — flush berikutnya akan retry.

#### Auto-stop saat idle 30 menit

```dart
// lib/services/trip_service.dart
static const Duration _idleTimeout = Duration(minutes: 30);

void _checkIdle() {
  if (!isTracking) return;
  final lastMove = _lastMovingWaypointTime;
  if (lastMove == null) return;
  if (DateTime.now().difference(lastMove) >= _idleTimeout) {
    _performAutoStop(lastMove);
  }
}
```

**Penjelasan baris demi baris:**

- `static const Duration _idleTimeout = Duration(minutes: 30);` — Konstanta: berapa lama harus diam sebelum auto-stop. 30 menit ditentukan dari uji empiris — terlalu singkat → false trigger di lampu merah panjang; terlalu panjang → user lupa stop dan trip log "kotor".
- `void _checkIdle() {` — Method dipanggil tiap 60 detik oleh timer.
- `if (!isTracking) return;` — Kalau trip sudah tidak aktif, abaikan.
- `final lastMove = _lastMovingWaypointTime;` — Ambil timestamp terakhir kali user bergerak >30 m.
- `if (lastMove == null) return;` — Belum pernah bergerak, belum bisa nilai apakah idle.
- `if (DateTime.now().difference(lastMove) >= _idleTimeout) {` — Selisih antara sekarang dan timestamp terakhir bergerak ≥ 30 menit?
- `_performAutoStop(lastMove);` — Eksekusi auto-stop dengan cutoff = waktu bergerak terakhir. Ini bikin idle tail (30 menit yang user diam) tidak masuk ke distance/duration.

Saat auto-stop fire:

1. Cancel semua stream.
2. Flush waypoint sisa.
3. **Hitung ulang distance** hanya sampai `cutoffTime` — idle tail dipotong dari distance & duration.
4. Update trip dengan `ended_at = cutoffTime`.
5. Trigger notif via `NotificationService.notifyAutoStop`.
6. Panggil callback `onAutoStopped` supaya UI tampilkan dialog summary.


### 7.2 PredictionService — Bayesian km/L

File: [`lib/services/prediction_service.dart`](lib/services/prediction_service.dart)

**Stateless, semua method static.** Tidak ada DB call, tidak ada I/O — pure function. Konsumen pass list `EfficiencySample` yang sudah di-fetch dari repo.

#### Kontrak utama

```dart
// lib/services/prediction_service.dart
class FuelEconomyEstimate {
  final double kmPerLiter;
  final String source;     // 'PRIOR' | 'MIXED' | 'DATA-DRIVEN'
  final int sampleCount;
}

static FuelEconomyEstimate posteriorKmPerLiter({
  required Vehicle vehicle,
  required List<EfficiencySample> samples,
  PrimaryCity? primaryCity,
  UsageProfile? usageProfile,
});
```

**Penjelasan baris demi baris:**

- `class FuelEconomyEstimate {` — Kelas hasil prediksi. Bukan database row, hanya wadah hasil komputasi.
- `final double kmPerLiter;` — Estimasi efisiensi (kilometer per liter).
- `final String source;` — Label provenance: dari mana angka ini berasal. UI menampilkan badge "PRIOR" / "MIXED" / "DATA-DRIVEN" untuk transparansi.
- `final int sampleCount;` — Berapa sample asli yang ikut dipakai. Berguna untuk informasi ke user ("dihitung dari N pengukuran").
- `static FuelEconomyEstimate posteriorKmPerLiter({` — Method utama. Static = tidak butuh instance. Kurung kurawal `{}` di awal parameter artinya semua argument harus di-name (mis. `posteriorKmPerLiter(vehicle: v, samples: s)`), bukan posisi.
- `required Vehicle vehicle,` — Parameter wajib: kendaraan yang mau diprediksi.
- `required List<EfficiencySample> samples,` — Parameter wajib: data ground truth (boleh kosong).
- `PrimaryCity? primaryCity,` — Optional. Tanda `?` artinya boleh null. Dipakai untuk faktor congestion.
- `UsageProfile? usageProfile,` — Optional. Dipakai untuk faktor matic-di-macet.

#### Step 1 — Prior

```dart
// lib/services/prediction_service.dart
static double priorKmPerLiter({...}) {
  double base = _baseKmPerLiter(vehicle);
  base *= _ageFactor(vehicle.manufacturingYear);
  base *= _transmissionFactor(vehicle.transmission, primaryCity, usageProfile);
  base *= _cityFactor(primaryCity);
  return base.clamp(_kmLLowerSanity, _kmLUpperSanity);
}
```

**Penjelasan baris demi baris:**

- `static double priorKmPerLiter({...}) {` — Hitung "tebakan awal" tanpa data nyata, hanya berdasarkan spec kendaraan + konteks user.
- `double base = _baseKmPerLiter(vehicle);` — Ambil angka dasar dari tabel referensi. Mis. motor 110cc → 55 km/L; SUV 1500cc → 10 km/L.
- `base *= _ageFactor(vehicle.manufacturingYear);` — Kalikan dengan faktor umur. Mobil tua boros 15-25%, jadi factor ~0.75-0.85.
- `base *= _transmissionFactor(...);` — Kalikan dengan faktor transmisi (matic di macet bocor). Hanya aktif kalau context-nya mendukung (kota macet atau commute harian).
- `base *= _cityFactor(primaryCity);` — Kalikan faktor kota. Jakarta → 0.80 (lebih boros 20%); rural → 1.05 (lebih hemat 5%).
- `return base.clamp(_kmLLowerSanity, _kmLUpperSanity);` — Pastikan hasil di range masuk akal (2-100 km/L). `clamp` adalah method yang batasi nilai dalam range — kalau kurang dari min, pakai min; kalau lebih dari max, pakai max.

Base km/L per kategori (motor pakai CC, mobil pakai body × ccFactor):

| Vehicle | Base km/L |
|---|---|
| Motor ≤110cc (Beat, Mio) | 55 |
| Motor 111-125 (Vario, NMax) | 48 |
| Motor 126-160 (PCX, ADV) | 40 |
| Motor 250cc | 32 |
| Hatchback | 14 |
| Sedan | 13 |
| MPV | 12 |
| SUV | 10 |
| Pickup | 9 |
| Sport | 8 |

Multiplier:

| Faktor | Range |
|---|---|
| `_ageFactor` | 1.0 di umur ≤5; turun 1.5%/tahun; lantai 0.75 di umur ≥15 |
| `_transmissionFactor` | AT 0.90, CVT 0.95, DCT 0.92 — **hanya aktif** di kota macet (`jakarta`/`bandung`/`surabaya`) atau profil `daily_commute` |
| `_cityFactor` | jakarta 0.80, bandung 0.88, surabaya 0.90, midSized 0.95, rural 1.05 |

Catatan: tidak ada penalti per RON. Alasan didokumentasi inline:

> RON / octane penalty intentionally omitted — Indonesian fuel quality is inconsistent and pump labelling is unreliable, so any per-RON adjustment would be noise more often than signal.

#### Step 2 — Posterior (Bayesian update)

```dart
// lib/services/prediction_service.dart
static const double _priorWeightAlpha = 8.0;

final clean = samples.where((s) =>
    s.kmPerLiter >= _kmLLowerSanity && s.kmPerLiter <= _kmLUpperSanity
).toList();

final sampleSum = clean.fold<double>(0, (s, x) => s + x.kmPerLiter);
final n = clean.length;
final posterior = (_priorWeightAlpha * prior + sampleSum) / (_priorWeightAlpha + n);
```

**Penjelasan baris demi baris:**

- `static const double _priorWeightAlpha = 8.0;` — "Bobot" prior dalam satuan "effective measurement". Artinya: prior dianggap sekuat 8 sample asli. Setelah ada 8 sample, prior dan data baru sama-sama berbobot 50%. Setelah 24 sample, prior tinggal 25%.
- `final clean = samples.where((s) => s.kmPerLiter >= _kmLLowerSanity && s.kmPerLiter <= _kmLUpperSanity).toList();` — Buang outlier. `.where(...)` di-list = filter yang lolos kondisi. Sample dengan km/L < 2 atau > 100 dianggap rusak (typo, parser salah, dll) dan tidak ikut hitung.
- `final sampleSum = clean.fold<double>(0, (s, x) => s + x.kmPerLiter);` — `fold` adalah cara menjumlahkan semua nilai. Mulai dari 0, tiap iterasi tambah `x.kmPerLiter` ke akumulator `s`. Hasilnya total km/L dari semua sample bersih.
- `final n = clean.length;` — Hitung jumlah sample valid.
- `final posterior = (_priorWeightAlpha * prior + sampleSum) / (_priorWeightAlpha + n);` — Rumus utama Bayesian-style weighted mean. Pembilang = bobot prior × nilai prior + total nilai sample. Penyebut = total bobot. Hasilnya = rata-rata tertimbang yang konvergen ke rata-rata sample saat n besar.

Source label:

```dart
final sampleWeight = n / (_priorWeightAlpha + n);
final source = sampleWeight < 0.25 ? 'MIXED'
              : (sampleWeight < 0.75 ? 'MIXED' : 'DATA-DRIVEN');
```

**Penjelasan baris demi baris:**

- `final sampleWeight = n / (_priorWeightAlpha + n);` — Hitung porsi bobot yang dipegang sample. n=0 → 0; n=8 → 0.5; n=72 → ~0.9.
- `final source = sampleWeight < 0.25 ? 'MIXED' : (sampleWeight < 0.75 ? 'MIXED' : 'DATA-DRIVEN');` — Konvert ke label string. Kurang dari 25% → MIXED tipis. Antara 25-75% → MIXED proper. >75% → DATA-DRIVEN. Note: kalau n=0 sebetulnya path ini tidak terjangkau karena kita early-return PRIOR di atas.

Konvergensi:

- `n=0` → posterior = prior, badge `PRIOR`.
- `n=4` → bobot prior ~67%, bobot sampel ~33%, badge `MIXED`.
- `n=24` → bobot sampel ~75%, badge `DATA-DRIVEN`.

#### Daily km estimate

Priority: **trip data** > **weekly_km user pref** > **usage_profile mapping** > **default 10 km/hari**:

```dart
// lib/services/prediction_service.dart
if (recent.length >= 5 && tripKm >= 30) {
  return DailyKmEstimate(kmPerDay: tripKm / 30, source: 'data 30 hari');
}
if (weeklyKmPref is num && weeklyKmPref > 0) { ... source: 'preferensi' ... }
if (usageProfile != null) { ... source: 'profil pakai' ... }
return DailyKmEstimate(kmPerDay: 10.0, source: 'default');
```

**Penjelasan baris demi baris:**

- `if (recent.length >= 5 && tripKm >= 30) {` — Kalau ada minimal 5 trip GPS di 30 hari terakhir DAN total km ≥ 30, kita anggap data trip cukup signifikan untuk dijadikan basis.
- `return DailyKmEstimate(kmPerDay: tripKm / 30, source: 'data 30 hari');` — Bagi total km dengan 30 hari → estimasi km harian. Source label "data 30 hari" supaya UI bisa kasih tahu user ini dari data nyata.
- `if (weeklyKmPref is num && weeklyKmPref > 0) {` — Cek apakah user kasih input manual tentang km mingguan. `is num` = type check dengan promote ke num kalau lulus.
- `if (usageProfile != null) {` — Fallback berikutnya: kalau user pilih profil pakai (komuter/weekend/dll), pakai mapping kasar yang sudah disiapkan.
- `return DailyKmEstimate(kmPerDay: 10.0, source: 'default');` — Last resort: 10 km/hari. Supaya UI tetap punya angka untuk tampilkan, tidak blank.

UI menampilkan label "sumber: <source>" supaya user paham angka itu datang dari mana.


### 7.3 RefuelParserService — AI parser client

File: [`lib/services/refuel_parser_service.dart`](lib/services/refuel_parser_service.dart)

Wrapper tipis di atas `Supabase.functions.invoke(...)` untuk dua endpoint:

- `parse-fuel-voice` — terima transcript text, balas `ParsedRefuel`
- `parse-fuel-receipt` — terima image bytes (base64), balas `ParsedRefuel`

```dart
// lib/services/refuel_parser_service.dart
Future<ParsedRefuel> parseVoice(String transcript) async {
  final clean = transcript.trim();
  if (clean.isEmpty) throw StateError('Ucapan kosong, coba bicara lebih jelas.');
  final res = await _client.functions.invoke(
    'parse-fuel-voice',
    body: {'transcript': clean},
  );
  return _decode(res);
}

Future<ParsedRefuel> parseReceiptBytes(Uint8List bytes, String mime) async {
  if (bytes.length > 5 * 1024 * 1024) {
    throw StateError('Foto terlalu besar (...). Coba foto ulang dengan resolusi lebih rendah.');
  }
  final base64Image = base64Encode(bytes);
  final res = await _client.functions.invoke(
    'parse-fuel-receipt',
    body: {'image_base64': base64Image, 'mime': mime},
  );
  return _decode(res);
}
```

**Penjelasan baris demi baris (`parseVoice`):**

- `Future<ParsedRefuel> parseVoice(String transcript) async {` — Fungsi async menerima string transcript, return ParsedRefuel.
- `final clean = transcript.trim();` — Hilangkan whitespace di pinggir. `final` artinya variable tidak diganti lagi.
- `if (clean.isEmpty) throw StateError('Ucapan kosong, coba bicara lebih jelas.');` — Validasi: tidak ada gunanya kirim string kosong ke server. Lebih baik error langsung dari client.
- `final res = await _client.functions.invoke('parse-fuel-voice', body: {'transcript': clean});` — Panggil edge function. Argumen pertama = nama function. `body` = JSON yang dikirim. `await` berarti tunggu response.
- `return _decode(res);` — Parse response jadi objek `ParsedRefuel`.

**Penjelasan baris demi baris (`parseReceiptBytes`):**

- `Future<ParsedRefuel> parseReceiptBytes(Uint8List bytes, String mime) async {` — Variant yang menerima bytes mentah dari kamera/galeri. `Uint8List` = list integer 8-bit, format byte standar di Dart.
- `if (bytes.length > 5 * 1024 * 1024) {` — Validasi ukuran. `5 * 1024 * 1024` = 5 MB. Foto >5 MB ditolak supaya tidak boros bandwidth dan blur tipis tetap bisa dideteksi tanpa megapixel berlebih.
- `final base64Image = base64Encode(bytes);` — Encode bytes ke string base64 supaya bisa dikirim sebagai field JSON. Base64 menambah ukuran ~33% tapi safe untuk JSON.
- `final res = await _client.functions.invoke('parse-fuel-receipt', body: {'image_base64': base64Image, 'mime': mime});` — Panggil edge function dengan body berisi base64 + tipe MIME (mis. `image/jpeg`).
- `return _decode(res);` — Parse response.

Error mapping `_humanize` translate code dari edge function jadi pesan Indo:

| Code | Pesan |
|---|---|
| `no_vehicles` | "Belum ada kendaraan. Tambahkan di profil dulu." |
| `no_fuel_products` | "Master BBM kosong. Hubungi admin." |
| `no_refuel_parsed` | "AI tidak mengenali ucapan/struk sebagai pengisian." |
| `image_too_large` | "Foto terlalu besar." |
| `unsupported_mime` | "Format foto tidak didukung (pakai JPG / PNG)." |
| `transcript_too_long` | "Ucapan terlalu panjang (>600 karakter)." |

### 7.4 NotificationService

File: [`lib/services/notification_service.dart`](lib/services/notification_service.dart)

Singleton wrapper untuk `flutter_local_notifications`. Hanya dipakai untuk satu use case sekarang: notif "Trip dihentikan otomatis".

Saat init, channel Android `trip_events` dibuat di-advance supaya muncul di App Settings:

```dart
// lib/services/notification_service.dart
await androidImpl?.createNotificationChannel(
  const AndroidNotificationChannel(
    _tripChannelId,        // 'trip_events'
    _tripChannelName,      // 'Perjalanan'
    description: _tripChannelDesc,
    importance: Importance.high,
  ),
);
```

**Penjelasan baris demi baris:**

- `await androidImpl?.createNotificationChannel(` — Bikin notification channel. Tanda `?` setelah `androidImpl` artinya kalau objek itu null (mis. di iOS), skip pemanggilan tanpa crash.
- `const AndroidNotificationChannel(` — Bikin objek channel dengan parameter konstan.
- `_tripChannelId,` — ID unik channel ('trip_events'). Notifikasi yang dikirim ke channel ini akan grouping dengan ID ini.
- `_tripChannelName,` — Nama channel yang user lihat di Settings → Notifications app.
- `description: _tripChannelDesc,` — Deskripsi yang muncul di bawah nama di Settings, menjelaskan kapan notif ini muncul.
- `importance: Importance.high,` — Level prioritas. `high` artinya notif dengan suara dan heads-up display di atas screen. Tidak `max` karena kita tidak mau full-screen interruption.

`notifyAutoStop` pakai stable id (`1001`) supaya notif berikutnya replace yang sebelumnya — tidak menumpuk:

```dart
await _plugin.show(
  _autoStopNotificationId,
  'Trip dihentikan otomatis',
  '$distText tercatat. Buka BensinKu untuk lihat detail.',
  details,
);
```

**Penjelasan baris demi baris:**

- `await _plugin.show(` — Tampilkan notif lewat plugin.
- `_autoStopNotificationId,` — ID notif (1001). Karena ID-nya tetap, panggilan berikutnya akan replace notif lama, bukan stack jadi banyak.
- `'Trip dihentikan otomatis',` — Title.
- `'$distText tercatat. Buka BensinKu untuk lihat detail.',` — Body. `$distText` adalah string interpolation — value variable `distText` disisipkan di sana.
- `details,` — Konfigurasi notif (channel, priority, dll) — di-build di tempat lain.

### 7.5 HomeWidgetService + WidgetLaunchIntent

File: [`lib/services/home_widget_service.dart`](lib/services/home_widget_service.dart) — push data ke home widget.
File: [`lib/services/widget_launch_intent.dart`](lib/services/widget_launch_intent.dart) — bridge ke MainActivity Kotlin via MethodChannel.

`HomeWidgetService.refresh()` kompose 3 string: greeting, tanggal, footer (total bulan + km/L), lalu trigger `BensinKuWidgetProvider.onUpdate`:

```dart
// lib/services/home_widget_service.dart
await Future.wait([
  HomeWidget.saveWidgetData<String>('widget_greeting', greeting),
  HomeWidget.saveWidgetData<String>('widget_date', dateStr),
  HomeWidget.saveWidgetData<String>('widget_footer', footer),
]);
await HomeWidget.updateWidget(
  androidName: 'BensinKuWidgetProvider',
  qualifiedAndroidName: 'com.temanlabs.bensinku.BensinKuWidgetProvider',
);
```

**Penjelasan baris demi baris:**

- `await Future.wait([...]);` — Jalankan beberapa async operation paralel, tunggu sampai semua selesai. Lebih cepat daripada `await` satu-satu.
- `HomeWidget.saveWidgetData<String>('widget_greeting', greeting),` — Tulis ke SharedPreferences dengan key `'widget_greeting'`. `<String>` adalah tipe parameter — beri tahu plugin bahwa value-nya string.
- `HomeWidget.saveWidgetData<String>('widget_date', dateStr),` — Tanggal hari ini dalam format pendek (mis. "26.05.26").
- `HomeWidget.saveWidgetData<String>('widget_footer', footer),` — Footer text dengan info bulan ini.
- `await HomeWidget.updateWidget(...)` — Trigger Android system untuk re-render widget, yang akan memanggil `BensinKuWidgetProvider.onUpdate()` di Kotlin.
- `androidName: 'BensinKuWidgetProvider',` — Nama class widget provider tanpa package.
- `qualifiedAndroidName: 'com.temanlabs.bensinku.BensinKuWidgetProvider',` — Fully qualified name (dengan package). Diperlukan agar Android tahu class mana yang harus di-broadcast.

Footer pakai `PredictionService.posteriorKmPerLiter` di kendaraan pertama:

```dart
final estimate = PredictionService.posteriorKmPerLiter(
  vehicle: firstVehicle,
  samples: samples,
  usageProfile: UsageProfile.tryParse(meta?['usage_profile']),
  primaryCity:  PrimaryCity.tryParse(meta?['primary_city']),
);
return '$monthName: $rpStr · ${totalLiter.toStringAsFixed(1)} L · '
       '${estimate.kmPerLiter.toStringAsFixed(0)} km/L';
```

**Penjelasan baris demi baris:**

- `final estimate = PredictionService.posteriorKmPerLiter(` — Panggil prediction service untuk dapat estimasi km/L.
- `vehicle: firstVehicle,` — Kendaraan pertama user (widget cuma punya tempat untuk satu).
- `samples: samples,` — Data efficiency sample yang sudah di-fetch dari DB.
- `usageProfile: UsageProfile.tryParse(meta?['usage_profile']),` — Convert string dari user_metadata ke enum. `tryParse` return null kalau tidak match — aman kalau user belum set.
- `primaryCity: PrimaryCity.tryParse(meta?['primary_city']),` — Sama untuk kota.
- `return '$monthName: $rpStr · ${totalLiter.toStringAsFixed(1)} L · ${estimate.kmPerLiter.toStringAsFixed(0)} km/L';` — String composer pakai interpolation. `toStringAsFixed(1)` artinya format dengan 1 desimal. `·` adalah karakter middle dot untuk separator visual.

Widget Android-only — di iOS perlu WidgetKit extension terpisah (out of scope).

#### WidgetLaunchIntent — handshake widget → app

User tap tombol "MULAI PERJALANAN" di widget → MainActivity di-launch dengan deeplink `bensinku://widget/start-trip`. Native side simpan flag boolean. Dart polling lewat MethodChannel:

```dart
// lib/services/widget_launch_intent.dart
static const _channel = MethodChannel('bensinku/widget_intent');
static const int _consumerCount = 2;  // HomeShell + TripMapScreen

static Future<bool> consumePending() async {
  if (_cycleActive) {
    _cycleConsumed++;
    if (_cycleConsumed >= _consumerCount) { _cycleActive = false; ... }
    return true;
  }
  final native = await _channel.invokeMethod<bool>('consumePendingTripStart');
  if (native == true) {
    _cycleActive = true; _cycleConsumed = 1;
    ...
    return true;
  }
  return false;
}
```

**Penjelasan baris demi baris:**

- `static const _channel = MethodChannel('bensinku/widget_intent');` — Bikin saluran komunikasi Dart ↔ native dengan nama unik. Native side harus pakai nama yang sama.
- `static const int _consumerCount = 2;` — Berapa banyak komponen Dart yang harus tahu soal flag ini. Komentar menjelaskan: HomeShell (untuk switch tab) + TripMapScreen (untuk auto-start trip).
- `if (_cycleActive) {` — Kalau cycle sedang aktif (sudah ada consumer pertama), jangan tanya native lagi.
- `_cycleConsumed++;` — Increment counter consumer yang sudah ack.
- `if (_cycleConsumed >= _consumerCount) { _cycleActive = false; ... }` — Kalau semua expected consumer sudah ack, reset cycle. Cycle berikutnya akan tanya native lagi.
- `final native = await _channel.invokeMethod<bool>('consumePendingTripStart');` — Panggil method native. `<bool>` = expected return type. Native return true sekali (consume sekali pakai), lalu return false sampai intent baru datang.
- `if (native == true) {` — Native bilang ada intent.
- `_cycleActive = true; _cycleConsumed = 1;` — Mulai cycle baru. Counter dimulai dari 1 karena pemanggil saat ini menghitung sebagai consumer pertama.
- `return true;` — Beri tahu pemanggil ada intent yang harus diproses.
- `return false;` — Tidak ada intent.

Kotlin side di [`MainActivity.kt`](android/app/src/main/kotlin/com/temanlabs/bensinku/MainActivity.kt):

```kotlin
override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
  super.configureFlutterEngine(flutterEngine)
  MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
    .setMethodCallHandler { call, result ->
      when (call.method) {
        "consumePendingTripStart" -> {
          val v = pendingTripStart
          pendingTripStart = false
          result.success(v)
        }
        else -> result.notImplemented()
      }
    }
}
```

**Penjelasan baris demi baris:**

- `override fun configureFlutterEngine(flutterEngine: FlutterEngine) {` — Override hook yang dipanggil saat engine Flutter di-attach ke Activity. `override` = override method dari parent class.
- `super.configureFlutterEngine(flutterEngine)` — Panggil implementasi parent dulu (penting untuk plugin lain).
- `MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)` — Bikin handler MethodChannel di sisi native dengan nama yang sama dengan Dart side.
- `.setMethodCallHandler { call, result ->` — Pasang handler. `call` berisi nama method + args; `result` adalah callback untuk reply.
- `when (call.method) {` — Pattern matching ala Kotlin. Mirip switch-case.
- `"consumePendingTripStart" -> {` — Handler untuk method ini.
- `val v = pendingTripStart` — Simpan nilai sekarang ke variable lokal.
- `pendingTripStart = false` — Reset flag (consume sekali pakai).
- `result.success(v)` — Reply ke Dart dengan nilai original.
- `else -> result.notImplemented()` — Kalau ada method lain yang tidak dikenal, lempar error standar.

### 7.6 VehicleAssets

File: [`lib/services/vehicle_assets.dart`](lib/services/vehicle_assets.dart)

Resolver untuk asset foto kendaraan, dengan in-memory cache:

```dart
final candidates = [
  'assets/vehicles/${v.id}.jpg',
  'assets/vehicles/${v.id}.png',
  'assets/vehicles/${v.type.dbValue}-default.jpg',
  'assets/vehicles/${v.type.dbValue}-default.png',
];
for (final path in candidates) {
  try {
    await rootBundle.load(path);
    _cache[v.id] = path;
    return path;
  } catch (_) {}
}
_cache[v.id] = null;
return null;
```

**Penjelasan baris demi baris:**

- `final candidates = [...]` — List path yang akan dicoba berurutan. Path pertama yang ada → menang.
- `'assets/vehicles/${v.id}.jpg',` — Foto specific by vehicle id, format JPG.
- `'assets/vehicles/${v.id}.png',` — Sama tapi format PNG (fallback).
- `'assets/vehicles/${v.type.dbValue}-default.jpg',` — Default per type (mis. `motor-default.jpg`).
- `'assets/vehicles/${v.type.dbValue}-default.png',` — Default per type, PNG.
- `for (final path in candidates) {` — Loop tiap path.
- `await rootBundle.load(path);` — Coba load asset. Kalau ada → sukses; kalau tidak → throw exception.
- `_cache[v.id] = path;` — Simpan ke cache supaya pemanggilan berikutnya tidak ulangi proses load.
- `return path;` — Sukses, balik path-nya.
- `} catch (_) {}` — Tidak ada di path ini, lanjut ke kandidat berikutnya.
- `_cache[v.id] = null;` — Tidak ada satu pun yang match. Cache null supaya tidak ulang proses.
- `return null;` — UI akan render fallback (silhouette atau initials).

Lookup berurutan: foto specific → default per type → null (UI fallback ke silhouette).


---

## 8. Feature Modules (UI)

State management ditahan ringan: `StatefulWidget` + `FutureBuilder`/`StreamBuilder` + `ChangeNotifier`. Tidak ada Bloc/Riverpod — biaya cognitif lebih rendah, dan use case-nya cukup sederhana.

### 8.1 Auth — [`lib/features/auth/`](lib/features/auth/)

| File | Fungsi |
|---|---|
| [`sign_in_page.dart`](lib/features/auth/sign_in_page.dart) | Email + password, tangani `AuthException` |
| [`sign_up_page.dart`](lib/features/auth/sign_up_page.dart) | Daftar baru |
| [`forgot_password_page.dart`](lib/features/auth/forgot_password_page.dart) | Magic link reset |
| [`email_verify_page.dart`](lib/features/auth/email_verify_page.dart) | Wait & resend verif email |

Sign-in core:

```dart
// lib/features/auth/sign_in_page.dart
await Supabase.instance.client.auth
    .signInWithPassword(email: email, password: password);
```

**Penjelasan baris demi baris:**

- `await Supabase.instance.client.auth.signInWithPassword(...)` — Panggil API login Supabase. Kalau berhasil, internal state Supabase otomatis simpan session, dan listener `onAuthStateChange` akan fire — yang bikin `_AuthGate` rebuild dan user diarahkan ke dashboard.
- `email: email, password: password,` — Named arguments. Sengaja eksplisit supaya tidak ada confusion mana posisinya email mana password.

`AuthException.message` di-translate ke pesan Indo (e.g. "email not confirmed" → "Email belum diverifikasi. Cek inbox/spam.").

### 8.2 Onboarding — [`lib/features/onboarding/`](lib/features/onboarding/)

Berurutan: [`welcome_page.dart`](lib/features/onboarding/welcome_page.dart) → [`setup_profile_page.dart`](lib/features/onboarding/setup_profile_page.dart) → [`add_vehicle_page.dart`](lib/features/onboarding/add_vehicle_page.dart) → [`complete_vehicle_data_page.dart`](lib/features/onboarding/complete_vehicle_data_page.dart) → [`setup_preferences_page.dart`](lib/features/onboarding/setup_preferences_page.dart).

Tiap page panggil `_refresh()` callback yang bump `_refreshKey` di `_RegisteredGate` supaya gate re-evaluasi state.

### 8.3 Home Shell — [`lib/features/home/home_shell.dart`](lib/features/home/home_shell.dart)

Bottom nav 5 slot: 0=Beranda, 1=Analisa, 2=tombol "+", 3=Arsip, 4=Rute. `IndexedStack` dipakai supaya state tab tidak hilang saat switch:

```dart
// lib/features/home/home_shell.dart
body: IndexedStack(
  index: stackIndex,
  children: [
    SummaryTab(key: ValueKey('summary-${_refreshCounters[0]}'), ...),
    AnalyticsTab(key: ValueKey('analytics-${_refreshCounters[1]}')),
    HistoryTab(key: ValueKey('history-${_refreshCounters[3]}')),
    const TripMapScreen(),
  ],
),
```

**Penjelasan baris demi baris:**

- `body: IndexedStack(` — `IndexedStack` adalah widget yang menampung beberapa child tapi cuma render satu pada satu waktu — sambil child lain tetap "hidup" di belakang. Bedanya dengan `Stack`: `IndexedStack` cuma show satu, sementara `Stack` show semua bertumpuk.
- `index: stackIndex,` — Index child yang ditampilkan. Switch tab = ganti index.
- `SummaryTab(key: ValueKey('summary-${_refreshCounters[0]}'), ...)` — `key` adalah identifier widget. Saat key berubah, Flutter treat ini sebagai widget baru dan rebuild from scratch (re-fetch data, dll). `${_refreshCounters[0]}` berisi counter yang di-increment saat user pull-to-refresh atau switch tab — efeknya: tab di-refresh tanpa harus close-open app.
- `const TripMapScreen(),` — Tidak pakai key karena trip recorder punya state internal yang harus persist (active trip, GPS sub).

`_refreshCounters` increment saat user switch tab supaya FutureBuilder di tab itu re-fetch fresh data.

Tombol "+" buka radial menu dengan 3 opsi:

```dart
// lib/features/home/home_shell.dart
enum _AddAction { camera, manual, voice }
```

**Penjelasan baris demi baris:**

- `enum _AddAction { camera, manual, voice }` — Enum sederhana. Tiga pilihan input: kamera (struk), manual (form biasa), voice (suara). Underscore di depan menandakan private (cuma dipakai di file ini).

- `manual` → `_AddFuelSheet` (form input langsung)
- `voice` → `VoiceInputSheet` (transcribe + edge function) → `_AddFuelSheet` dengan prefill
- `camera` → `image_picker.pickImage()` → `ReceiptProcessingSheet` (edge function) → `_AddFuelSheet` dengan prefill

### 8.4 Tabs

| Tab | File | Fungsi |
|---|---|---|
| Beranda | [`summary_tab.dart`](lib/features/home/summary_tab.dart) | Greeting, total bulan, last refuel, prediksi sisa BBM, garasi, riwayat singkat |
| Analisa | [`analytics_tab.dart`](lib/features/home/analytics_tab.dart) | Chart total spend per minggu/bulan/tahun, mini stats |
| Arsip | [`history_tab.dart`](lib/features/home/history_tab.dart) | List semua refuel + trip dengan filter periode |
| Profil | [`profile_tab.dart`](lib/features/home/profile_tab.dart) | Edit user metadata + manage vehicles |
| Rute | [`trip/trip_map_screen.dart`](lib/features/trip/trip_map_screen.dart) | Live GPS recorder |

### 8.5 TripMapScreen — [`lib/features/trip/trip_map_screen.dart`](lib/features/trip/trip_map_screen.dart)

UI lifecycle:

1. `_init` — list vehicles, request permission, ambil first GPS fix.
2. **Sebelum trip**: `_idlePositionSub` low-power stream untuk update "you are here" dot.
3. **Saat user tap MULAI**: cancel idle stream → `TripService.startTrip()` → high-accuracy stream.
4. **Saat user tap SELESAI**: `_stopTrip()` → tampilkan dialog summary.
5. **Auto-stopped callback**: dialog summary dengan badge "DIHENTIKAN OTOMATIS".

Render:

```dart
// lib/features/trip/trip_map_screen.dart
FlutterMap(
  mapController: _mapController,
  options: MapOptions(initialCenter: initCenter, initialZoom: 15),
  children: [
    TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.temanlabs.bensinku',
      maxZoom: 19,
    ),
    if (polylinePoints.length >= 2)
      PolylineLayer(polylines: [
        Polyline(points: polylinePoints, color: AppEditorial.ink, strokeWidth: 4),
      ]),
    MarkerLayer(markers: [...]),  // "you are here" + live trip dot
  ],
),
```

**Penjelasan baris demi baris:**

- `FlutterMap(` — Widget root peta dari package `flutter_map`.
- `mapController: _mapController,` — Controller yang bisa diakses untuk pan/zoom programatik (mis. tombol "recenter").
- `options: MapOptions(initialCenter: initCenter, initialZoom: 15),` — Setting awal: pusat peta + level zoom (1=dunia, 19=street level).
- `children: [` — List layer yang akan ditumpuk dari bawah ke atas.
- `TileLayer(` — Layer paling bawah: gambar peta itu sendiri.
- `urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',` — Template URL dengan placeholder {z}/{x}/{y}. flutter_map yang resolve placeholder jadi koordinat tile asli.
- `userAgentPackageName: 'com.temanlabs.bensinku',` — Identifikasi app saat request ke OSM. Wajib sesuai usage policy OSM.
- `maxZoom: 19,` — Batas zoom paling dekat. OSM tile tidak punya level lebih dari 19.
- `if (polylinePoints.length >= 2)` — Conditional widget: render PolylineLayer hanya kalau ada minimal 2 titik (1 titik tidak bisa bikin garis).
- `PolylineLayer(polylines: [` — Layer untuk garis-garis.
- `Polyline(points: polylinePoints, color: AppEditorial.ink, strokeWidth: 4),` — Definisi satu garis dari list LatLng. `AppEditorial.ink` = warna near-black dari theme. `strokeWidth: 4` = tebal 4px.
- `MarkerLayer(markers: [...]),` — Layer untuk pin/marker (titik posisi user).

### 8.6 TripDetailPage — [`lib/features/trip/trip_detail_page.dart`](lib/features/trip/trip_detail_page.dart)

Replay trip lama dari list waypoint di Supabase:

```dart
// lib/features/trip/trip_detail_page.dart
FutureBuilder<List<TripWaypoint>>(
  future: repo.getTripWaypoints(trip.id),
  builder: (context, snap) {
    final waypoints = snap.data ?? [];
    final latLngs = waypoints.map((w) => LatLng(w.lat, w.lng)).toList();
    LatLngBounds? bounds = latLngs.length >= 2
        ? LatLngBounds.fromPoints(latLngs) : null;
    ...
    FlutterMap(
      options: MapOptions(
        initialCameraFit: bounds != null
            ? CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(32))
            : null,
      ),
      children: [
        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', ...),
        PolylineLayer(...),
        MarkerLayer(markers: [start, end]),
      ],
    );
  },
);
```

**Penjelasan baris demi baris:**

- `FutureBuilder<List<TripWaypoint>>(` — Widget yang otomatis rebuild berdasarkan state Future. `<List<TripWaypoint>>` = expected type hasil future.
- `future: repo.getTripWaypoints(trip.id),` — Future yang akan di-monitor. Di-fetch sekali saat builder pertama kali dipasang.
- `builder: (context, snap) {` — Function yang dipanggil saat state berubah. `snap` (snapshot) berisi state: connectionState, data, error.
- `final waypoints = snap.data ?? [];` — Ambil data atau array kosong kalau null. Operator `??` artinya "kalau kiri null, pakai kanan".
- `final latLngs = waypoints.map((w) => LatLng(w.lat, w.lng)).toList();` — Transform List<TripWaypoint> jadi List<LatLng>. `.map(...)` menerapkan transformasi ke tiap elemen; `.toList()` ubah hasil iterator jadi list konkret.
- `LatLngBounds? bounds = latLngs.length >= 2 ? LatLngBounds.fromPoints(latLngs) : null;` — Hitung bounding box dari semua waypoint. Kalau cuma 1 atau 0 titik, null (tidak bisa zoom-fit).
- `initialCameraFit: bounds != null ? CameraFit.bounds(...) : null,` — Auto-zoom supaya semua waypoint kelihatan. `padding: EdgeInsets.all(32)` = sisakan 32px margin di tiap sisi supaya garis tidak nempel di tepi layar.

`CameraFit.bounds` otomatis zoom-to-fit semua waypoint.


---

## 9. Backend — Supabase

### 9.1 Schema & RLS

Semua tabel di schema `bensinku` (bukan `public`) — supaya bisa coexist dengan app lain di instance Supabase yang sama.

#### Tabel utama

| Tabel | Kolom utama | RLS |
|---|---|---|
| `bensinku.vehicles` | id, user_id, vehicle_type, name, tank_capacity_liters, **engine_cc**, **manufacturing_year**, **body_type**, **transmission**, **recommended_ron**, **make_model** | `user_id = auth.uid()` |
| `bensinku.refuels` | id, user_id, vehicle_id, fuel_product_id, refuel_date, odometer_km, total_rp, price_per_liter_snapshot, liters, is_full_tank | `user_id = auth.uid()` |
| `bensinku.trips` | id, user_id, vehicle_id, started_at, ended_at, distance_km, note | `user_id = auth.uid()` |
| `bensinku.trip_waypoints` | trip_id, lat, lng, recorded_at | `trip_id IN (select … where user_id = auth.uid())` |
| `bensinku.fuel_products` | id, brand, name, sort_order, active | read-only untuk user |
| `bensinku.fuel_prices` | fuel_product_id, effective_from, price_per_liter | read-only untuk user |
| `bensinku.fuel_efficiency_samples` | id, user_id, vehicle_id, from_refuel_id, to_refuel_id, km_traveled, liters_filled, **km_per_liter (generated)**, measured_at, context | `user_id = auth.uid()` |

Kolom **bold** di `vehicles` dan tabel `fuel_efficiency_samples` ditambah lewat migration Predictions v2 — lihat [§9.2](#92-migrations-strategy).

#### CHECK constraints penting

Sumber: [`supabase/migrations/20260515090000_predictions_v2.sql`](supabase/migrations/20260515090000_predictions_v2.sql)

```sql
-- vehicles
check (engine_cc is null or engine_cc between 50 and 9999)
check (manufacturing_year is null or manufacturing_year between 1980 and 2035)
check (body_type is null or body_type in ('sedan','hatchback','mpv','suv','pickup','sport'))
check (vehicle_type <> 'motor' or body_type is null)
check (transmission is null or transmission in ('manual','at','cvt','dct'))
check (recommended_ron is null or recommended_ron in (88,90,92,95,98))

-- fuel_efficiency_samples
km_per_liter numeric(10,4) generated always as (km_traveled / liters_filled) stored
check (km_traveled > 0)
check (liters_filled > 0)
```

**Penjelasan baris demi baris:**

- `check (engine_cc is null or engine_cc between 50 and 9999)` — CHECK constraint = aturan validasi level database. Engine CC boleh null (opsional) atau di range 50–9999. Ini fail-safe: app bisa-bisa salah kirim 0 atau negatif, DB akan tolak.
- `check (manufacturing_year is null or manufacturing_year between 1980 and 2035)` — Tahun produksi 1980 sampai 2035. Upper bound 2035 dipilih supaya valid sampai 9 tahun ke depan tanpa perlu update migration.
- `check (body_type is null or body_type in ('sedan','hatchback','mpv','suv','pickup','sport'))` — Body type harus salah satu dari 6 nilai itu. Mencegah typo seperti "Sedan" (kapital) atau "minivan" (tidak ada).
- `check (vehicle_type <> 'motor' or body_type is null)` — Logic: kalau vehicle_type = motor, body_type wajib null. `<>` adalah operator "tidak sama dengan" di SQL.
- `check (transmission is null or transmission in ('manual','at','cvt','dct'))` — Transmisi dibatasi ke 4 nilai standar.
- `check (recommended_ron is null or recommended_ron in (88,90,92,95,98))` — RON harus salah satu dari 5 nilai populer Indonesia.
- `km_per_liter numeric(10,4) generated always as (km_traveled / liters_filled) stored` — Generated column: nilainya tidak di-input app, tapi dihitung Postgres dari kolom lain. `numeric(10,4)` artinya max 10 digit total, 4 di belakang koma. `stored` artinya hasil disimpan fisik di disk (bukan dihitung ulang setiap query). Bonus: bisa di-index seperti kolom biasa.
- `check (km_traveled > 0)` — Jarak harus positif. Kalau ada bug yang submit 0 atau negatif, DB tolak.
- `check (liters_filled > 0)` — Sama untuk liter. Selain validasi data, ini juga proteksi rumus generated column dari pembagian 0.

`km_per_liter` adalah **generated stored column** — Postgres yang hitung, app hanya kirim `km_traveled` + `liters_filled`. Idempotent guard:

```sql
create unique index if not exists fuel_efficiency_samples_pair_uidx
  on bensinku.fuel_efficiency_samples (vehicle_id, from_refuel_id, to_refuel_id)
  where from_refuel_id is not null and to_refuel_id is not null;
```

**Penjelasan baris demi baris:**

- `create unique index if not exists fuel_efficiency_samples_pair_uidx` — Bikin index unik dengan nama eksplisit. `if not exists` bikin re-run aman.
- `on bensinku.fuel_efficiency_samples (vehicle_id, from_refuel_id, to_refuel_id)` — Index di kombinasi 3 kolom. Kombinasi ini harus unik di seluruh tabel.
- `where from_refuel_id is not null and to_refuel_id is not null;` — _Partial index_: index hanya berlaku untuk row di mana kedua refuel_id tidak null. Row yang punya null di salah satu boleh duplikat (mis. data import lama tanpa from_refuel_id).

#### RLS pattern — vehicles

Sumber: [`supabase/schema.sql`](supabase/schema.sql)

```sql
alter table public.vehicles enable row level security;

create policy "vehicles_select_own" on public.vehicles
  for select to authenticated using (user_id = auth.uid());

create policy "vehicles_insert_own" on public.vehicles
  for insert to authenticated with check (user_id = auth.uid());

-- update + delete serupa
```

**Penjelasan baris demi baris:**

- `alter table public.vehicles enable row level security;` — Aktifkan RLS untuk tabel ini. Setelah ini, semua query default ditolak — kecuali ada policy yang allow.
- `create policy "vehicles_select_own" on public.vehicles` — Bikin policy bernama "vehicles_select_own" di tabel vehicles.
- `for select to authenticated` — Policy ini berlaku untuk operasi SELECT, dan untuk role `authenticated` (user yang sudah login).
- `using (user_id = auth.uid());` — Kondisi: user hanya boleh SELECT row di mana kolom user_id sama dengan UUID user yang login. `auth.uid()` adalah fungsi Supabase yang return UUID dari JWT yang dikirim client.
- `for insert to authenticated with check (user_id = auth.uid());` — Untuk INSERT, pakai `with check` (bukan `using`). Kondisi: row baru yang di-insert harus punya user_id sama dengan auth.uid(). User tidak bisa insert row atas nama user lain.

Kolom `user_id uuid not null default auth.uid()` bikin tiap insert otomatis isi user_id pengguna saat ini — client tidak perlu kirim manual, dan attempt forging akan ditolak `with check`.

`fuel_products`/`fuel_prices` punya policy read-only untuk authenticated — write hanya bisa lewat service_role key (admin / migration).

### 9.2 Migrations Strategy

Forward-only. Tidak ada down-migration. Untuk fix, bikin file baru — file lama jangan diedit setelah dijalankan.

| File | Tanggal | Tujuan |
|---|---|---|
| [`schema.sql`](supabase/schema.sql) | initial | Bootstrap awal saat self-host fresh |
| [`upgrade_2026_04_13.sql`](supabase/upgrade_2026_04_13.sql) | apr 2026 | Patch tambah `tank_capacity_liters`, optionalkan odometer, bikin `trips` + `trip_waypoints` |
| [`migrations/20260514120000_move_to_bensinku_schema.sql`](supabase/migrations/20260514120000_move_to_bensinku_schema.sql) | mei 2026 | Pindah semua tabel dari `public` → `bensinku` (multi-app namespace) |
| [`migrations/20260515090000_predictions_v2.sql`](supabase/migrations/20260515090000_predictions_v2.sql) | mei 2026 | Tambah kolom detail mesin di `vehicles` + bikin `fuel_efficiency_samples` |

Semua migration ditulis idempotent — `IF NOT EXISTS`, `DO $$ ... EXCEPTION when duplicate_object then null END $$`, atau probe ke `information_schema`. Aman di-run berulang.

```sql
-- Pattern: probe-then-add
do $$
begin
  if not exists (
    select 1 from information_schema.columns
     where table_schema = 'bensinku' and table_name = 'vehicles' and column_name = 'engine_cc'
  ) then
    alter table bensinku.vehicles add column engine_cc int null;
  end if;
end$$;
```

**Penjelasan baris demi baris:**

- `do $$` — Mulai blok PL/pgSQL. `$$` adalah delimiter dollar-quoted, lebih nyaman daripada single quote untuk multiline SQL.
- `begin` — Buka block code.
- `if not exists (` — Conditional: cek dulu sebelum aksi.
- `select 1 from information_schema.columns where ...` — Query system catalog Postgres untuk lihat apakah kolom `engine_cc` sudah ada di tabel `bensinku.vehicles`. `information_schema` adalah view standar SQL yang berisi metadata schema.
- `) then` — Kalau hasil query kosong (kolom belum ada), eksekusi:
- `alter table bensinku.vehicles add column engine_cc int null;` — Tambah kolom engine_cc bertipe integer, boleh null.
- `end if;` — Tutup conditional.
- `end$$;` — Tutup blok PL/pgSQL.

Pattern ini bikin migration aman di-run berkali-kali tanpa error "column already exists".

Move ke schema baru di-handle dengan `ALTER TABLE ... SET SCHEMA`:

```sql
-- supabase/migrations/20260514120000_move_to_bensinku_schema.sql
alter table if exists public.vehicles       set schema bensinku;
alter table if exists public.fuel_products  set schema bensinku;
alter table if exists public.fuel_prices    set schema bensinku;
alter table if exists public.refuels        set schema bensinku;
alter table if exists public.trips          set schema bensinku;
alter table if exists public.trip_waypoints set schema bensinku;
```

**Penjelasan baris demi baris:**

- `alter table if exists public.vehicles set schema bensinku;` — Pindahkan tabel `public.vehicles` ke schema `bensinku`. `if exists` bikin no-op kalau tabelnya sudah tidak ada di public (mis. migration sudah jalan sebelumnya, tabel sudah di bensinku).
- 5 baris berikutnya = sama untuk tabel lain.

Bagusnya `set schema`: RLS policy, indexes, constraint, FK, trigger ikut otomatis tertarik bareng. Tidak perlu re-create satu-satu.


### 9.3 Edge Functions (Deno + OpenAI)

Dua function, runtime Deno, deployed via `supabase functions deploy`.

#### Common pattern

Sumber: [`supabase/functions/parse-fuel-receipt/index.ts`](supabase/functions/parse-fuel-receipt/index.ts), [`supabase/functions/parse-fuel-voice/index.ts`](supabase/functions/parse-fuel-voice/index.ts)

Tiap function:

1. Cek method (POST), CORS, auth header (Bearer JWT).
2. Buat Supabase client **dengan auth header user di-forward** supaya RLS scope ke user yang request.
3. Fetch list `vehicles` + `fuel_products` user untuk dijadikan konteks LLM.
4. Build system prompt dengan list itu.
5. Panggil `${OPENAI_BASE_URL}/chat/completions` dengan `response_format: { type: "json_object" }`.
6. Validasi + normalisasi output (force `vehicle_id` & `fuel_product_id` ke salah satu yang valid; round number).
7. Balikan `ParsedRefuel` JSON.

Auth-forwarding pattern:

```typescript
// supabase/functions/parse-fuel-receipt/index.ts
const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  db: { schema: "bensinku" },
  global: { headers: { Authorization: authHeader } },
  auth: { persistSession: false },
});
```

**Penjelasan baris demi baris:**

- `const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {` — Bikin client baru di sisi server. Karena pakai anon key + JWT user (forwarded), RLS akan di-enforce sebagai user yang login.
- `db: { schema: "bensinku" },` — Default schema untuk semua query lewat client ini.
- `global: { headers: { Authorization: authHeader } },` — Ini kuncinya: forward auth header dari request original. Tanpa ini, query akan dianggap dari role anon yang tidak punya akses ke data user.
- `auth: { persistSession: false },` — Edge function tidak butuh persist session (server-less, tiap invocation fresh).

Dengan ini, query `supabase.from("vehicles").select(...)` di edge function otomatis kena RLS — tidak bisa lihat kendaraan user lain meskipun bug.

#### Receipt parser — `parse-fuel-receipt`

Input:

```json
{ "image_base64": "...", "mime": "image/jpeg" }
```

Validasi:

```typescript
const ALLOWED_MIMES = new Set(["image/jpeg","image/jpg","image/png","image/webp"]);
const MAX_BASE64_BYTES = 6_500_000;  // ~5 MB raw
```

**Penjelasan baris demi baris:**

- `const ALLOWED_MIMES = new Set([...])` — Bikin Set (kumpulan unik) berisi MIME type yang diterima. Set lebih efisien untuk lookup `.has(...)` daripada array.
- `const MAX_BASE64_BYTES = 6_500_000;` — Underscore di angka adalah separator JS yang bikin angka mudah dibaca (sama seperti koma di "6,500,000"). 6.5 MB base64 ≈ 5 MB raw karena base64 menambah ~33% overhead.

Prompt detail (excerpt):

```
CARA BACA STRUK SPBU:
1. total_rp = TOTAL RUPIAH yang dibayar.
   - Cari label "TOTAL", "GRAND TOTAL", "JUMLAH BAYAR", "BAYAR".
   - Format struk SPBU biasanya tampilkan harga dalam ribuan: "Rp 50.000" -> 50000.
2. price_per_liter = HARGA PER LITER.
3. liters = JUMLAH LITER yang diisi.
4. fuel_product_id = pilih dari list di atas.
   - Untuk struk Pertamina yang cuma tulis "PRT" / "PMX" / "PXT", inferensi:
     PRT/Pertalite, PMX/Pertamax, PXT/Pertamax Turbo, DXL/Dexlite, PDX/Pertamina Dex.
5. vehicle_id = pilih dari KENDARAAN USER di atas.
   - Jika user cuma punya 1 kendaraan -> pakai itu.
   - Heuristic: BBM motor + total kecil -> motor; diesel atau total besar -> mobil.
```

Vision call:

```typescript
// supabase/functions/parse-fuel-receipt/index.ts
const dataUrl = `data:${mime};base64,${imageBase64}`;
const openaiRes = await fetch(`${OPENAI_BASE_URL}/chat/completions`, {
  method: "POST",
  headers: { "Content-Type": "application/json", Authorization: `Bearer ${OPENAI_API_KEY}` },
  body: JSON.stringify({
    model: OPENAI_CHAT_MODEL,
    temperature: 0.1,
    response_format: { type: "json_object" },
    messages: [
      { role: "system", content: systemPrompt },
      { role: "user", content: [
          { type: "text", text: "Baca struk SPBU berikut..." },
          { type: "image_url", image_url: { url: dataUrl, detail: "high" } },
      ]},
    ],
  }),
});
```

**Penjelasan baris demi baris:**

- `const dataUrl = `data:${mime};base64,${imageBase64}`;` — Bikin "data URL" inline. Format ini universal untuk encode binary di string. OpenAI Vision menerima format ini.
- `const openaiRes = await fetch(`${OPENAI_BASE_URL}/chat/completions`, {` — HTTP POST ke endpoint chat completions OpenAI. `${OPENAI_BASE_URL}` di-set via env var supaya bisa diganti ke OpenAI-compatible provider.
- `method: "POST",` — Standar OpenAI.
- `headers: { "Content-Type": "application/json", Authorization: \`Bearer ${OPENAI_API_KEY}\` },` — Header autentikasi pakai API key di env var. Bearer token = standar OAuth.
- `body: JSON.stringify({...})` — Convert object JS jadi string JSON.
- `model: OPENAI_CHAT_MODEL,` — Model yang dipakai (mis. `gpt-4o-mini`).
- `temperature: 0.1,` — Temperature rendah → output deterministic. Untuk parsing struk, kita mau jawaban konsisten, bukan kreatif.
- `response_format: { type: "json_object" },` — Force model output JSON valid (bukan markdown atau prose).
- `messages: [...]` — Array message untuk chat completion.
- `{ role: "system", content: systemPrompt },` — Pesan sistem berisi instruksi parsing + list vehicles/fuels yang valid.
- `{ role: "user", content: [...]}` — Pesan user dengan konten multipart: text + image.
- `{ type: "image_url", image_url: { url: dataUrl, detail: "high" } },` — Embed image. `detail: "high"` artinya OpenAI process image dengan resolusi tinggi (lebih akurat tapi lebih mahal).

Defense-in-depth: meskipun LLM dipaksa pilih dari list, kode tetap validate ulang:

```typescript
let vehicle = vehicles.find((v) => v.id === item.vehicle_id);
if (!vehicle) vehicle = vehicles[0];

let fuel = fuelProducts.find((f) => f.id === item.fuel_product_id);
if (!fuel) fuel = fuelProducts[0];

// liters kalau LLM lupa hitung, fallback dari total / harga
if (!Number.isFinite(liters) || liters <= 0) {
  liters = pricePerLiter > 0 ? totalRp / pricePerLiter : 0;
}
liters = Math.round(liters * 1000) / 1000;
```

**Penjelasan baris demi baris:**

- `let vehicle = vehicles.find((v) => v.id === item.vehicle_id);` — Cari vehicle dengan ID yang LLM pilih. `.find` return objek pertama yang match atau undefined.
- `if (!vehicle) vehicle = vehicles[0];` — Kalau tidak ketemu (LLM hallucinate ID), fallback ke vehicle pertama. Defensif: gak boleh balikin ID null ke client.
- `let fuel = fuelProducts.find((f) => f.id === item.fuel_product_id);` — Sama untuk fuel product.
- `if (!fuel) fuel = fuelProducts[0];` — Fallback ke fuel pertama.
- `if (!Number.isFinite(liters) || liters <= 0) {` — Cek apakah liter angka valid. `Number.isFinite` filter NaN, Infinity, null, undefined.
- `liters = pricePerLiter > 0 ? totalRp / pricePerLiter : 0;` — Recalculate liter dari total/harga kalau LLM lupa. Kalau harga juga 0, tetap 0 (UI nanti minta user koreksi).
- `liters = Math.round(liters * 1000) / 1000;` — Bulatkan ke 3 desimal. Trick `*1000 → round → /1000` adalah cara clamp presisi tanpa toString conversion.

#### Voice parser — `parse-fuel-voice`

Input:

```json
{ "transcript": "isi pertamax 50rb di motor honda" }
```

Validasi: max 600 karakter. Prompt menjelaskan parser angka (`50rb` → 50000, `1jt` → 1000000), parser fuel name, dan aturan pemilihan vehicle. Skema output identik dengan receipt.

#### Env vars yang dibutuhkan

| Var | Contoh | Catatan |
|---|---|---|
| `OPENAI_API_KEY` | `sk-...` | Wajib |
| `OPENAI_BASE_URL` | `https://api.openai.com/v1` | Bisa diganti ke OpenAI-compatible provider |
| `OPENAI_CHAT_MODEL` | `gpt-4o-mini` | Vision-capable model |

Set via Supabase CLI:

```bash
supabase secrets set OPENAI_API_KEY=sk-...
supabase secrets set OPENAI_CHAT_MODEL=gpt-4o-mini
supabase secrets set OPENAI_BASE_URL=https://api.openai.com/v1
supabase functions deploy parse-fuel-receipt
supabase functions deploy parse-fuel-voice
```

**Penjelasan baris demi baris:**

- `supabase secrets set OPENAI_API_KEY=sk-...` — Set environment variable di edge runtime Supabase. Dipakai oleh `Deno.env.get("OPENAI_API_KEY")` di kode.
- `supabase secrets set OPENAI_CHAT_MODEL=gpt-4o-mini` — Pilih model yang dipakai. Bisa swap tanpa edit kode.
- `supabase secrets set OPENAI_BASE_URL=https://api.openai.com/v1` — Base URL OpenAI. Bisa di-redirect ke proxy / provider lain yang OpenAI-compatible (mis. Azure OpenAI, OpenRouter, vLLM self-host).
- `supabase functions deploy parse-fuel-receipt` — Deploy function ke Supabase edge runtime. CLI yang bundle TS jadi JS dan upload.
- `supabase functions deploy parse-fuel-voice` — Sama untuk voice parser.


---

## 10. Map & Rute (OpenStreetMap)

Tile map = OpenStreetMap publik. Tidak ada API key, tidak ada provider berbayar. Polyline rute digenerate dari titik GPS sendiri (bukan routing engine OSM).

### 10.1 Tile source

Endpoint:

```
https://tile.openstreetmap.org/{z}/{x}/{y}.png
```

`{z}/{x}/{y}` = slippy-map convention. `flutter_map` resolve placeholder, lakukan HTTP GET, cache di memory + disk.

Konfigurasi di Flutter (dua tempat):

```dart
// lib/features/trip/trip_map_screen.dart  &  trip_detail_page.dart
TileLayer(
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  userAgentPackageName: 'com.temanlabs.bensinku',
  maxZoom: 19,
)
```

**Penjelasan baris demi baris:**

- `TileLayer(` — Layer untuk tile gambar peta.
- `urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',` — Template URL. `{z}` = zoom level (0 dunia, 19 jalan). `{x}/{y}` = koordinat tile di grid pada zoom level itu. flutter_map yang resolve template — tiap kali user pan/zoom peta, flutter_map hitung tile mana yang dibutuhkan, ganti placeholder, lakukan HTTP GET. Hasilnya di-cache supaya tidak repeated download saat user balik ke area sama.
- `userAgentPackageName: 'com.temanlabs.bensinku',` — String User-Agent yang dikirim saat request. OSM tile usage policy WAJIB User-Agent yang valid; kalau kosong / generic, server bisa block traffic.
- `maxZoom: 19,` — Batas zoom maksimum. OSM tidak punya tile lebih dari level 19. Kalau user coba zoom in lebih dari ini, flutter_map akan render tile level 19 di-stretch.

`userAgentPackageName` wajib diisi sesuai [OSM tile usage policy](https://operations.osmfoundation.org/policies/tiles/) — server bisa block traffic tanpa User-Agent yang valid.

### 10.2 Polyline rute

Garis rute = list `LatLng` yang di-derive dari GPS samples lokal:

```dart
// lib/features/trip/trip_map_screen.dart
final polylinePoints =
    positions.map((p) => LatLng(p.latitude, p.longitude)).toList();

if (polylinePoints.length >= 2)
  PolylineLayer(polylines: [
    Polyline(
      points: polylinePoints,
      color: AppEditorial.ink,
      strokeWidth: 4,
    ),
  ]),
```

**Penjelasan baris demi baris:**

- `final polylinePoints = positions.map((p) => LatLng(p.latitude, p.longitude)).toList();` — Convert `List<Position>` (dari geolocator) jadi `List<LatLng>` (yang dipakai flutter_map). `map` apply transformasi, `toList` materialize iterator.
- `if (polylinePoints.length >= 2)` — Garis butuh minimal 2 titik. Kalau cuma 1 titik (baru saja mulai), tidak render PolylineLayer.
- `PolylineLayer(polylines: [` — Layer yang bisa render banyak garis. Kita kirim satu garis.
- `Polyline(` — Definisi satu garis.
- `points: polylinePoints,` — Daftar titik berurutan.
- `color: AppEditorial.ink,` — Warna near-black dari theme (mengikuti style logbook).
- `strokeWidth: 4,` — Ketebalan 4 pixel.

OSM hanya berperan sebagai **wallpaper peta**. Tidak ada routing API, tidak ada turn-by-turn — app cuma plot titik yang user benar-benar lewati menurut GPS.

### 10.3 Replay trip lama

Trip yang sudah selesai punya waypoint disimpan di `bensinku.trip_waypoints`. [`TripDetailPage`](lib/features/trip/trip_detail_page.dart) fetch list itu lalu plot dengan `CameraFit.bounds` supaya peta auto-zoom ke bounding box rute.

### 10.4 Catatan operasional

`tile.openstreetmap.org` bersifat **free + best-effort + rate-limited**. OSM Foundation jelas-jelas bilang "not for heavy use". Kalau user-base berkembang, tinggal swap `urlTemplate` ke provider lain — sisanya tidak berubah:

- [MapTiler](https://www.maptiler.com/) — free tier 100k tile/bulan
- [Stadia Maps](https://stadiamaps.com/) — free tier 200k/bulan
- [Thunderforest](https://www.thunderforest.com/)
- Self-host pakai `tileserver-gl`

---

## 11. Native Integrations (Android Widget)

### 11.1 Widget provider — [`BensinKuWidgetProvider.kt`](android/app/src/main/kotlin/com/temanlabs/bensinku/BensinKuWidgetProvider.kt)

Extends `HomeWidgetProvider` dari plugin `home_widget`. Read SharedPreferences yang ditulis Flutter side, lalu render `RemoteViews`:

```kotlin
override fun onUpdate(...) {
  appWidgetIds.forEach { id ->
    val views = RemoteViews(context.packageName, R.layout.bensinku_widget)
    views.setTextViewText(R.id.widget_greeting, widgetData.getString("widget_greeting", null) ?: "Selamat datang")
    views.setTextViewText(R.id.widget_date,     widgetData.getString("widget_date", null) ?: "")
    views.setTextViewText(R.id.widget_footer,   widgetData.getString("widget_footer", null) ?: "Belum ada catatan bulan ini")

    // Tap body → buka app
    views.setOnClickPendingIntent(R.id.widget_root, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))

    // Tap MULAI → buka app dengan deeplink
    val startTripIntent = HomeWidgetLaunchIntent.getActivity(
      context, MainActivity::class.java, Uri.parse("bensinku://widget/start-trip"),
    )
    views.setOnClickPendingIntent(R.id.widget_start_button, startTripIntent)

    appWidgetManager.updateAppWidget(id, views)
  }
}
```

**Penjelasan baris demi baris:**

- `override fun onUpdate(...)` — Method dipanggil oleh sistem Android setiap kali widget perlu di-refresh (jadwal periodik atau trigger manual).
- `appWidgetIds.forEach { id ->` — Loop tiap instance widget. User bisa pasang widget yang sama beberapa kali; tiap instance punya ID unik.
- `val views = RemoteViews(context.packageName, R.layout.bensinku_widget)` — Bikin objek RemoteViews dari layout XML. `RemoteViews` adalah API Android khusus untuk render UI di app lain (launcher punya proses sendiri).
- `views.setTextViewText(R.id.widget_greeting, widgetData.getString("widget_greeting", null) ?: "Selamat datang")` — Set text di TextView dengan id `widget_greeting`. Baca value dari SharedPreferences. Operator Kotlin `?:` (Elvis) artinya "kalau kiri null, pakai kanan".
- `views.setTextViewText(R.id.widget_date, widgetData.getString("widget_date", null) ?: "")` — Sama untuk tanggal.
- `views.setTextViewText(R.id.widget_footer, widgetData.getString("widget_footer", null) ?: "Belum ada catatan bulan ini")` — Sama untuk footer.
- `views.setOnClickPendingIntent(R.id.widget_root, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))` — Pasang click listener di body widget. Saat di-tap, launch MainActivity normal.
- `val startTripIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("bensinku://widget/start-trip"),)` — Bikin PendingIntent dengan URI deeplink khusus. URI ini yang di-baca MainActivity untuk tahu "ini launch dari tombol MULAI".
- `views.setOnClickPendingIntent(R.id.widget_start_button, startTripIntent)` — Pasang click listener di tombol MULAI.
- `appWidgetManager.updateAppWidget(id, views)` — Submit views yang sudah di-konfigurasi ke launcher untuk render.

### 11.2 MainActivity — [`MainActivity.kt`](android/app/src/main/kotlin/com/temanlabs/bensinku/MainActivity.kt)

Detect deeplink di `onCreate` dan `onNewIntent`:

```kotlin
private fun isStartTripIntent(intent: Intent?): Boolean {
  val data = intent?.data ?: return false
  return data.scheme == "bensinku" && data.host == "widget" && data.path == "/start-trip"
}
```

**Penjelasan baris demi baris:**

- `private fun isStartTripIntent(intent: Intent?): Boolean {` — Fungsi privat yang return boolean. `Intent?` artinya parameter boleh null.
- `val data = intent?.data ?: return false` — `intent?.data` artinya "kalau intent null, hasilnya null". `?: return false` adalah Elvis dengan return — artinya "kalau hasil di kiri null, langsung return false dari fungsi". Idiom Kotlin yang bersih.
- `return data.scheme == "bensinku" && data.host == "widget" && data.path == "/start-trip"` — Cek 3 part dari URI `bensinku://widget/start-trip`. Hanya kalau ketiganya match, return true.

MethodChannel `bensinku/widget_intent` ekspos satu method `consumePendingTripStart` — Dart side consume flag, native reset jadi false. Detail flow lihat [§7.5](#75-homewidgetservice--widgetlaunchintent).

---

## 12. Aliran Data End-to-End

### 12.1 Flow: User catat refuel manual

```
SummaryTab/HomeShell
  ↓ tap "+" → "MANUAL"
_AddFuelSheet (AddRefuelTab)
  ↓ user isi form
SupabaseRepository.createRefuel()
  ↓ INSERT bensinku.refuels
  ├─ if isFullTank → _maybeRecordFullTankCycle()
  │   ├─ SELECT prev full-tank refuel
  │   ├─ compute km traveled (odometer delta atau sum trips)
  │   └─ INSERT bensinku.fuel_efficiency_samples (idempotent unique index)
  └─ refresh HomeShell counters → SummaryTab re-fetch
        ↓
HomeWidgetService.refresh()
  └─ HomeWidget.saveWidgetData → BensinKuWidgetProvider.onUpdate
```

### 12.2 Flow: Voice input

```
HomeShell tap "+" → "VOICE"
VoiceInputSheet
  ├─ speech_to_text on-device transcribe
  └─ RefuelParserService.parseVoice(transcript)
       ↓ POST /functions/v1/parse-fuel-voice
       └─ Edge Function (Deno)
            ├─ fetch user vehicles + fuel_products (auth-forwarded, RLS)
            ├─ call OpenAI chat dengan system prompt
            ├─ validate + normalize JSON output
            └─ return ParsedRefuel
  ↓ Sheet close dengan ParsedRefuel
HomeShell._toggleAddFuelSheet(prefill: parsed)
  → AddRefuelTab (prefill terisi semua field)
  → user koreksi (kalau perlu) → tap simpan
  → SupabaseRepository.createRefuel() (sama seperti flow manual)
```

### 12.3 Flow: Receipt scan

```
HomeShell tap "+" → "STRUK"
ImagePicker.pickImage(source: camera/gallery, imageQuality: 75, maxWidth: 1600)
  ↓ XFile
ReceiptProcessingSheet
  ├─ readAsBytes
  └─ RefuelParserService.parseReceiptBytes(bytes, mime)
       ↓ check size (max 5MB), base64 encode
       └─ POST /functions/v1/parse-fuel-receipt
            └─ Edge Function (Deno)
                 ├─ fetch user vehicles + fuel_products (auth-forwarded, RLS)
                 ├─ call OpenAI vision dengan dataUrl base64
                 ├─ heuristic vehicle picking (motor vs mobil dari size & fuel)
                 └─ return ParsedRefuel
  ↓ ParsedRefuel
AddRefuelTab (prefill) → user konfirmasi → repo.createRefuel()
```

### 12.4 Flow: GPS trip recording

```
TripMapScreen
  ↓ tap MULAI
TripService.startTrip()
  ├─ SupabaseRepository.createTrip() → INSERT bensinku.trips
  ├─ Geolocator.getPositionStream(AndroidSettings/AppleSettings)
  │   └─ tiap update _onPosition()
  │        ├─ akumulasi distance
  │        ├─ update _lastMovingWaypointTime kalau delta > 30m
  │        └─ buffer ke _pendingWaypoints
  ├─ Timer 30s → _flushWaypoints()
  │        └─ SupabaseRepository.addWaypoints() → batch INSERT
  └─ Timer 60s → _checkIdle()
       └─ kalau idle ≥ 30 menit → _performAutoStop(cutoffTime)
            ├─ flush sisa waypoint
            ├─ recompute distance hingga cutoff (idle dipotong)
            ├─ SupabaseRepository.endTrip(endedAt: cutoffTime)
            ├─ NotificationService.notifyAutoStop()
            └─ onAutoStopped callback → UI dialog summary
  ↓ user tap SELESAI
TripService.stopTrip()
  ├─ cancel streams
  ├─ flush waypoint sisa
  └─ repo.endTrip(distanceKm: distance kumulatif)
```

### 12.5 Flow: Prediction posterior

```
SummaryTab.build
  ├─ repo.listVehicles()
  ├─ repo.listRefuels(vehicleId)
  ├─ repo.listTrips(vehicleId, since: monthStart)
  └─ untuk vehicle terpilih:
       ├─ repo.recentEfficiencySamples(vehicleId, limit: 20)
       └─ PredictionService.posteriorKmPerLiter(
            vehicle, samples,
            usageProfile: meta.usage_profile,
            primaryCity: meta.primary_city,
          )
            ├─ priorKmPerLiter() = base × age × tx × city
            ├─ filter outlier (km/L 2..100)
            ├─ posterior = (α·prior + Σsamples) / (α+n)
            └─ source label dari sampleWeight
       ↓ FuelEconomyEstimate
  → UI render gauge "X km/L · n=12 · DATA-DRIVEN"
```


---

## 13. Theme & Visual System

File: [`lib/app/theme.dart`](lib/app/theme.dart)

Vibe: **car service manual / fuel pump LCD / paper logbook**. Bukan magazine blog post.

### 13.1 Palette

```dart
// lib/app/theme.dart — AppEditorial
static const Color canvas      = Color(0xFFF6EFDF);  // cream paper
static const Color cream       = Color(0xFFFFF7E6);
static const Color butter      = Color(0xFFE9B341);  // spot accent
static const Color butterDeep  = Color(0xFFB6841C);
static const Color butterSoft  = Color(0xFFF6DC9F);
static const Color ink         = Color(0xFF1A0F03);  // near-black
static const Color inkSoft     = Color(0xFF6B5A45);
static const Color inkMuted    = Color(0xFF8E7B62);
static const Color hairline    = Color(0xFFD9CCAC);
static const Color hairlineSoft= Color(0xFFEBE2C8);
static const Color sage        = Color(0xFF5C7042);  // OK / start
static const Color rust        = Color(0xFFA8391A);  // warn / stop
```

**Penjelasan baris demi baris:**

- `static const Color canvas = Color(0xFFF6EFDF);` — Konstanta warna canvas (kertas cream). `0xFFF6EFDF` adalah hex ARGB: FF (alpha 100% = solid), F6 EF DF (RGB cream pucat).
- `static const Color butter = Color(0xFFE9B341);` — Warna butter sebagai accent satu-satunya. Dipakai untuk highlight aktif (selected nav item, primary button).
- `static const Color ink = Color(0xFF1A0F03);` — Warna text utama, near-black tapi bukan #000 — kontras lebih lembut di canvas cream.
- `static const Color hairline = Color(0xFFD9CCAC);` — Warna garis tipis pemisah. Lebih lembut dari ink untuk separator.
- `static const Color sage = Color(0xFF5C7042);` — Hijau zaitun untuk tombol OK / start.
- `static const Color rust = Color(0xFFA8391A);` — Merah tua untuk warning / stop. Bukan red bright supaya konsisten dengan vibe vintage logbook.

### 13.2 Typography

- **IBM Plex Mono** — angka, label, eyebrow, headline, masthead. Always with `tabularFigures` + `liningFigures` so number columns line up.
- **IBM Plex Sans** — body prose, deskripsi.

```dart
// lib/app/theme.dart
static TextStyle mono({...}) => GoogleFonts.ibmPlexMono(
  fontFeatures: tabular ? tabularFigures : null,
  ...
);
static TextStyle sans({...}) => GoogleFonts.ibmPlexSans(...);
```

**Penjelasan baris demi baris:**

- `static TextStyle mono({...}) =>` — Method static yang return TextStyle. Tanda `=>` adalah arrow function (one-liner shorthand).
- `GoogleFonts.ibmPlexMono(` — Pakai font IBM Plex Mono dari Google Fonts. Plugin `google_fonts` auto-download font saat first run.
- `fontFeatures: tabular ? tabularFigures : null,` — Aktifkan OpenType feature `tnum` (tabular numerals) yang bikin tiap digit punya lebar sama. Penting untuk readout angka — tanpa ini, kolom angka akan bergeser tergantung digit.
- `static TextStyle sans({...}) => GoogleFonts.ibmPlexSans(...);` — Sister method untuk Sans-serif variant. Dipakai untuk paragraf yang lebih panjang.

### 13.3 Radii

```dart
static const double rCard   = 6;
static const double rButton = 4;
static const double rPill   = 999;
static const double rTiny   = 2;
```

**Penjelasan baris demi baris:**

- `static const double rCard = 6;` — Radius corner untuk card (6px). Tajam, bukan rounded berlebihan.
- `static const double rButton = 4;` — Tombol lebih tajam lagi (4px). Memberi kesan terminal-box.
- `static const double rPill = 999;` — Pill shape — angka besar bikin Flutter render lingkaran penuh di sisi pendek.
- `static const double rTiny = 2;` — Untuk badge/chip kecil.

Sudut tajam (4–6px). Bukan playful pill — terminal-box look.

---

## Lampiran — File Index untuk Navigasi Cepat

### Frontend (Flutter)

- Entry & bootstrap: [`lib/main.dart`](lib/main.dart)
- App shell + auth gate: [`lib/app/app.dart`](lib/app/app.dart)
- Theme: [`lib/app/theme.dart`](lib/app/theme.dart)
- Config loader: [`lib/config/app_config.dart`](lib/config/app_config.dart)
- Models: [`lib/data/models.dart`](lib/data/models.dart)
- Repository: [`lib/data/repository.dart`](lib/data/repository.dart)

### Services

- Supabase init: [`lib/services/supabase_bootstrap.dart`](lib/services/supabase_bootstrap.dart)
- Trip GPS: [`lib/services/trip_service.dart`](lib/services/trip_service.dart)
- Prediction: [`lib/services/prediction_service.dart`](lib/services/prediction_service.dart)
- AI parser client: [`lib/services/refuel_parser_service.dart`](lib/services/refuel_parser_service.dart)
- Notifikasi: [`lib/services/notification_service.dart`](lib/services/notification_service.dart)
- Home widget: [`lib/services/home_widget_service.dart`](lib/services/home_widget_service.dart)
- Widget bridge: [`lib/services/widget_launch_intent.dart`](lib/services/widget_launch_intent.dart)
- Vehicle assets: [`lib/services/vehicle_assets.dart`](lib/services/vehicle_assets.dart)

### Features — Auth

- [`lib/features/auth/sign_in_page.dart`](lib/features/auth/sign_in_page.dart)
- [`lib/features/auth/sign_up_page.dart`](lib/features/auth/sign_up_page.dart)
- [`lib/features/auth/forgot_password_page.dart`](lib/features/auth/forgot_password_page.dart)
- [`lib/features/auth/email_verify_page.dart`](lib/features/auth/email_verify_page.dart)

### Features — Onboarding

- [`lib/features/onboarding/welcome_page.dart`](lib/features/onboarding/welcome_page.dart)
- [`lib/features/onboarding/setup_profile_page.dart`](lib/features/onboarding/setup_profile_page.dart)
- [`lib/features/onboarding/add_vehicle_page.dart`](lib/features/onboarding/add_vehicle_page.dart)
- [`lib/features/onboarding/complete_vehicle_data_page.dart`](lib/features/onboarding/complete_vehicle_data_page.dart)
- [`lib/features/onboarding/setup_preferences_page.dart`](lib/features/onboarding/setup_preferences_page.dart)

### Features — Home

- Shell + bottom nav: [`lib/features/home/home_shell.dart`](lib/features/home/home_shell.dart)
- Beranda: [`lib/features/home/summary_tab.dart`](lib/features/home/summary_tab.dart)
- Analisa: [`lib/features/home/analytics_tab.dart`](lib/features/home/analytics_tab.dart)
- Arsip: [`lib/features/home/history_tab.dart`](lib/features/home/history_tab.dart)
- Profil: [`lib/features/home/profile_tab.dart`](lib/features/home/profile_tab.dart)
- Detail kendaraan: [`lib/features/home/vehicle_detail_page.dart`](lib/features/home/vehicle_detail_page.dart)
- Form input: [`lib/features/home/add_refuel_tab.dart`](lib/features/home/add_refuel_tab.dart)
- Voice sheet: [`lib/features/home/voice_input_sheet.dart`](lib/features/home/voice_input_sheet.dart)
- Receipt sheet: [`lib/features/home/receipt_processing_sheet.dart`](lib/features/home/receipt_processing_sheet.dart)
- About: [`lib/features/home/about_page.dart`](lib/features/home/about_page.dart)
- Privacy: [`lib/features/home/privacy_page.dart`](lib/features/home/privacy_page.dart)

### Features — Trip

- GPS recorder: [`lib/features/trip/trip_map_screen.dart`](lib/features/trip/trip_map_screen.dart)
- Replay: [`lib/features/trip/trip_detail_page.dart`](lib/features/trip/trip_detail_page.dart)

### Backend — Supabase

- Initial schema: [`supabase/schema.sql`](supabase/schema.sql)
- Master data seed: [`supabase/seed.sql`](supabase/seed.sql)
- Patch lama: [`supabase/upgrade_2026_04_13.sql`](supabase/upgrade_2026_04_13.sql)
- Migration multi-app schema: [`supabase/migrations/20260514120000_move_to_bensinku_schema.sql`](supabase/migrations/20260514120000_move_to_bensinku_schema.sql)
- Migration predictions v2: [`supabase/migrations/20260515090000_predictions_v2.sql`](supabase/migrations/20260515090000_predictions_v2.sql)
- Edge: receipt parser: [`supabase/functions/parse-fuel-receipt/index.ts`](supabase/functions/parse-fuel-receipt/index.ts)
- Edge: voice parser: [`supabase/functions/parse-fuel-voice/index.ts`](supabase/functions/parse-fuel-voice/index.ts)

### Native Android

- MainActivity: [`android/app/src/main/kotlin/com/temanlabs/bensinku/MainActivity.kt`](android/app/src/main/kotlin/com/temanlabs/bensinku/MainActivity.kt)
- Widget provider: [`android/app/src/main/kotlin/com/temanlabs/bensinku/BensinKuWidgetProvider.kt`](android/app/src/main/kotlin/com/temanlabs/bensinku/BensinKuWidgetProvider.kt)

### Konfigurasi

- Flutter dependencies: [`pubspec.yaml`](pubspec.yaml)
- Env template: [`supabase.defines.example.json`](supabase.defines.example.json)
- Supabase CLI link: [`supabase.json`](supabase.json)
- Self-host server scripts: [`server/`](server/)
