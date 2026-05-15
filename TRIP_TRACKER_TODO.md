# Trip Tracker — Improvements TODO

Tiga perbaikan yang diminta user, ditambah analisis side-effect untuk
masing-masing.

---

## Phase 1 — Bug fix: Stop button kasih layar gelap

### T1.1 Investigasi root cause
- [x] Identifikasi: `_stopTrip()` await `endTrip` lalu memanggil
  `_showTripSummary(finished)`. Dialog rendering kelihatan gagal karena
  `_stopping=true` membungkus body dengan modal barrier (`AlertDialog`
  posisi blur). Layar tampak gelap = `_stopping` overlay tetap visible
  di belakang dialog yang gagal rebuild.
- Hipotesis: `setState(() => _stopping = false)` di `finally` block
  dijalankan **setelah** `_showTripSummary` muncul, tapi dialog terlanjur
  di-close oleh tombol OK yang reset `_service = null` lalu trigger
  rebuild — yang menabrak in-flight setState. Atau lebih simpel: dialog
  `showDialog` dipanggil dari context yang sudah unmounted setelah
  rebuild service teardown.
- Perbaikan: tampilkan summary **sebelum** clear service & loading state.
  Pakai `showDialog<bool>` dengan return value, dan teardown service di
  callback OK seperti sekarang — tapi tanpa overlap dengan `_stopping`
  spinner.

### T1.2 Fix
- [x] Pastikan `_stopping=false` dipanggil sebelum `_showTripSummary`
  (atau tambah short delay untuk memastikan barrier hilang)
- [x] Audit `_showTripSummary` dipanggil dari context yang masih mounted
- [x] Manual smoke test: stop → summary muncul instant, tidak ada layar
  gelap

---

## Phase 2 — Feature: Estimasi konsumsi bensin di TripDetailPage

Trip detail page sekarang menampilkan: tanggal, jam, jarak, durasi,
titik GPS. Tambahkan **perkiraan penggunaan bensin** untuk perjalanan
itu.

### T2.1 Hitung estimated liters
- [x] Di `TripDetailPage` ambil:
  - vehicle dari `trip.vehicleId` (perlu refactor minor — saat ini Trip
    model gak include vehicle relation, jadi load via repo)
  - efficiency samples + user prefs untuk hitung posterior km/L
  - `trip.distanceKm`
- [x] `estimatedLiters = distanceKm / posteriorKmPerLiter`
- [x] `estimatedRp = estimatedLiters × <BBM favorit price atau price snapshot terbaru>`

### T2.2 Tampilkan di TELEMETRI section
- [x] Row baru: "Estimasi BBM" → `1.20 L` (mono, butter accent)
- [x] Row baru: "Estimasi biaya" → `Rp 18.000`
- [x] Tambah footnote kecil: "berdasarkan efisiensi {N} ukuran" atau
  "berdasarkan profil kendaraan" (mengikuti source label dari
  `FuelEconomyEstimate`)

---

## Phase 3 — Feature: Auto-stop trip after 30 minutes idle

User minta: kalau user lupa pencet stop, sistem auto-stop tracking setelah
30 menit gak ada gerakan signifikan. Window 30 menit terakhir itu
**dipotong** dari rekam perjalanan supaya jarak dan durasi tidak ngaco.

### T3.1 Klarifikasi semantics "tidak aktif"
- [x] Definisi: tidak ada waypoint baru yang bergeser >X meter selama
  30 menit terakhir. Bukan: idle = device offline (tidak relevan).
- [x] Threshold gerakan: 30 meter (sama dengan `distanceFilter` aktivitas
  normal × 2, supaya GPS jitter saat parkir tidak counted as movement).
- [x] Detection trigger: `Timer.periodic(1 menit)` di `TripService` cek
  selisih waktu antara waypoint terakhir dengan now.

### T3.2 Modifikasi `TripService`
- [x] Tambah `Timer? _idleCheckTimer` yang fire tiap 60 detik.
- [x] Di tiap fire, cek:
  ```
  if (now - lastWaypointTime > 30 minutes) {
    autoStopTripAtTime(lastWaypointTime);
  }
  ```
- [x] `autoStopTripAtTime(cutoff)`:
  1. Cancel position stream + idle timer + flush timer.
  2. Hitung distance/duration **hanya sampai cutoff** (yaitu waypoint
     terakhir yang masih bergerak), bukan sampai now.
  3. Update trip row di DB dengan `ended_at = cutoff` dan
     `distance_km = clipped_distance`.
  4. Notify listeners + emit signal "auto-stopped" supaya UI bisa
     tampilkan toast/dialog "Trip otomatis dihentikan karena tidak
     aktif".
- [x] **Penting**: waypoint dalam 30 menit window terakhir SUDAH ter-flush
  ke `trip_waypoints` table. Ada dua opsi:
  - **A. Delete idle waypoints**: hapus row di `trip_waypoints` di mana
    `recorded_at > cutoff`. Implikasi: history bersih, tapi data hilang.
  - **B. Keep waypoints, clip `ended_at` saja**: simpler, tapi waypoint
    "tidak terpakai" tetap di DB. UI plot polyline tetap pakai
    waypoints sampai `ended_at`, jadi visual akan terclip secara
    natural.
- [x] **Pilih B** karena data tetap auditable; UI sudah filter berdasar
  `ended_at` saat hitung distance.
- [x] Edit `endTrip` repository method untuk terima parameter `endedAt`
  override (default = now), supaya bisa pass cutoff time.

### T3.3 UX: notifikasi auto-stop
- [x] Saat auto-stop fired, app mungkin di background. Solusi:
  - Foreground service notification (geolocator) di-update teks-nya jadi
    "Trip otomatis dihentikan" + sticky sebentar.
  - Saat user buka app lagi, UI detect `_service == null` tapi terakhir
    aktif → tampilkan trip summary dialog yang sama dengan manual stop.
- [x] Tambah field di Trip model: `autoStopped: bool` (di-pass dari
  service ke summary dialog supaya bisa tampilkan badge "DIHENTIKAN
  OTOMATIS").

### T3.4 Edge cases
- [x] User parkir <30 menit lalu lanjut jalan → idle timer reset begitu
  ada waypoint dengan delta >30m, tidak fire.
- [x] User di kemacetan stuck >30 menit → ini bug positif: macet bisa
  trigger auto-stop. Mitigasi: threshold gerakan 30m sudah cukup ketat
  untuk kebanyakan macet (kendaraan bergerak setidaknya 30m dalam 30
  menit di kemacetan parah sekalipun). Kalau user benar-benar parkir
  di tengah trip, tinggal start trip baru.
- [x] GPS hilang sinyal di terowongan/parkiran → tidak ada waypoint baru
  → auto-stop fired. Mitigasi: ini behavior yang acceptable; user
  bisa start trip baru saat keluar.
- [x] App killed by OS sebelum auto-stop fire → trip stuck "active" di
  DB. Mitigasi: di app boot kalau ada trip dengan `ended_at IS NULL`
  yang `started_at > 24 jam lalu`, tampilkan dialog "Trip sebelumnya
  belum ditutup, apakah ingin disimpan?". Skip dulu, taro di sub-task
  `T3.5 (later)`.

### T3.5 (later) Recovery untuk trip yang stuck
- [ ] Implementasi belakangan kalau ternyata sering kejadian. Tidak
  blocking untuk MVP.

---

## Phase 4 — Verification

- [ ] T4.1 `flutter analyze --no-pub` → 0 issues
- [ ] T4.2 Manual smoke test:
  - Stop button: summary dialog muncul instant tanpa layar gelap. ✓
  - Trip detail menampilkan estimasi BBM dengan source label.
  - Trip aktif → diamkan 30 menit → cek auto-stop dengan ended_at
    sesuai waypoint terakhir.
  - Trip aktif → bergerak terus → auto-stop tidak fired.
