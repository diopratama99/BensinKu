# BensinKu 

Aplikasi mobile untuk **memantau pengeluaran bahan bakar** kendaraan secara personal. Dibangun dengan Flutter dan Supabase sebagai backend.

---

## Fitur

| Fitur | Deskripsi |
|---|---|
|  **Dashboard** | Ringkasan kendaraan, pengisian terakhir, estimasi BBM, dan pengeluaran bulan ini |
|  **Smart Prediction** | Kalkulasi sisa bensin cerdas dengan Fallback Multi-Window (GPS aktual + Preferensi user) |
|  **Isi BBM** | Input pengisian BBM dengan validasi kapasitas tangki dan auto-select BBM favorit |
|  **Statistik** | Grafik pengeluaran & ringkasan jarak tempuh otomatis |
|  **Trip Tracker** | Rekam rute perjalanan secara real-time dengan GPS |
|  **Riwayat** | Daftar semua pengisian BBM beserta detail |
|  **Profil & Preferensi** | Manajemen akun, kendaraan, dan kustomisasi preferensi berkendara (estimasi km, frekuensi isi) |

---

##  Tech Stack

- **Framework**: Flutter (Dart)
- **Backend**: [Supabase](https://supabase.com) (Auth + PostgreSQL + RLS)
- **Maps**: [flutter_map](https://pub.dev/packages/flutter_map) + OpenStreetMap (gratis, tanpa API key)
- **GPS**: [geolocator](https://pub.dev/packages/geolocator)
- **Font**: Plus Jakarta Sans

---

##  Setup & Menjalankan

### 1. Clone & Install Dependencies

```bash
git clone https://github.com/diopratama99/BensinKu.git
cd BensinKu
flutter pub get
```

### 2. Setup Supabase

Buat project di [supabase.com](https://supabase.com), lalu jalankan SQL di **SQL Editor**:

```sql
-- Jalankan file ini sesuai urutan:
-- 1. supabase/schema.sql
-- 2. supabase/upgrade_2026_04_13.sql  (tabel trips & trip_waypoints)
```

### 3. Konfigurasi environment

Salin file contoh dan isi dengan credentials Supabase kamu:

```bash
cp supabase.defines.example.json supabase.defines.json
```

Edit `supabase.defines.json`:

```json
{
  "SUPABASE_URL": "https://xxxxxxxxxxxx.supabase.co",
  "SUPABASE_ANON_KEY": "eyJ..."
}
```

> ⚠️ **Jangan commit `supabase.defines.json`** — sudah ada di `.gitignore`

### 4. Jalankan

```bash
flutter run --dart-define-from-file=supabase.defines.json
```

### 5. Build APK

```bash
flutter build apk --dart-define-from-file=supabase.defines.json
```

---

##  Database Schema

```
users (Supabase Auth)
├── vehicles (kendaraan per user)
├── refuels (pengisian BBM)
├── trips (perjalanan GPS)
│   └── trip_waypoints (titik-titik GPS per perjalanan)
└── fuel_prices (harga BBM aktual)
```

Lihat detail: [`supabase/schema.sql`](supabase/schema.sql)

---

##  Struktur Proyek

```
lib/
├── app/            # Theme & routing
├── config/         # App config (env vars)
├── data/           # Models & repository (Supabase queries)
├── features/
│   ├── auth/       # Login page
│   ├── home/       # Dashboard, statistik, riwayat, profil
│   ├── onboarding/ # Setup profil & kendaraan
│   └── trip/       # GPS trip tracking + peta
├── services/       # TripService, SupabaseBootstrap
└── widgets/        # Reusable widgets
```

---

##  Screenshot

> *(Tambahkan screenshot di sini)*

---

## 📄 Lisensi

Proyek ini dibuat untuk keperluan tugas kuliah.
