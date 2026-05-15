# Prediction Accuracy v2 — Implementation TODO

Goal: tingkatkan akurasi prediksi bensin dengan **Bayesian blending** —
prior dari preferensi user (anti cold-start) + ground truth dari
full-tank-to-full-tank cycle.

**No RAG, no embedding.** Pure stats with adaptive learning.

---

## Phase 1 — Schema migration

- [x] T1.1 Buat migration `supabase/migrations/<ts>_predictions_v2.sql`
  - Extend `bensinku.vehicles`:
    - `engine_cc int NULL`
    - `manufacturing_year int NULL`
    - `body_type text NULL` (sedan/hatchback/mpv/suv/pickup/sport, null = motor)
    - `transmission text NULL` (manual/at/cvt/dct)
    - `recommended_ron smallint NULL`
    - `make_model text NULL`
    - CHECK constraint untuk valid enum values
  - New table `bensinku.fuel_efficiency_samples`:
    - `id uuid PK`
    - `user_id uuid NOT NULL`
    - `vehicle_id uuid NOT NULL → vehicles(id) ON DELETE CASCADE`
    - `from_refuel_id uuid → refuels(id)` (start full-tank)
    - `to_refuel_id uuid → refuels(id)` (end full-tank, where liters_filled measured)
    - `km_traveled numeric(10,2)`
    - `liters_filled numeric(10,2)`
    - `km_per_liter numeric(10,4) GENERATED`
    - `measured_at timestamptz DEFAULT now()`
    - RLS: user_id = auth.uid()
  - Idempotent (IF NOT EXISTS / DO blocks)

## Phase 2 — Models & Repository

- [x] T2.1 Update `Vehicle` model di `lib/data/models.dart`:
  - Tambah 6 field baru, semua nullable
  - `fromJson` + `toJson` adjust
- [x] T2.2 Tambah enum/const helpers untuk body_type, transmission, ron, usage_profile, primary_city
- [x] T2.3 Update `SupabaseRepository.createVehicle` & `updateVehicle` untuk terima field baru
- [x] T2.4 Add `EfficiencySample` model + `recordEfficiencySample()` repo method
- [x] T2.5 Add `recentEfficiencySamples(vehicleId, limit)` repo query

## Phase 3 — Onboarding & vehicle form extension

- [x] T3.1 Extend `AddVehiclePage` (lib/features/onboarding/add_vehicle_page.dart)
  - Tier 1 fields: CC, tahun produksi, body type (mobil only), transmisi, RON, make/model
  - Layout dengan section header "DETAIL MESIN" (collapsible / optional)
  - Validation reasonable (CC 50-9999, year 1980–current+1)
- [x] T3.2 Extend `SetupPreferencesPage` (lib/features/onboarding/setup_preferences_page.dart)
  - Tambah usage_profile picker (4 options)
  - Tambah primary_city picker (Jakarta/Bandung/Surabaya/kota sedang/luar kota)
  - Save ke user_metadata
- [x] T3.3 Update `VehicleDetailPage` agar bisa edit field baru
- [x] T3.4 Update `_PreferencesEditPage` di profile_tab — tambah usage_profile + primary_city

## Phase 4 — Prediction service refactor

- [x] T4.1 Buat `lib/services/prediction_service.dart`:
  - `priorKmPerLiter(Vehicle v, UserPrefs p) → double`
    - Base table by body type / motor displacement
    - Adjustments: year (>10y −15%), transmission (matic +10% in city), city (jakarta −20%), RON mismatch (−5%)
  - `posteriorKmPerLiter(Vehicle v, UserPrefs p, List<EfficiencySample> samples) → double`
    - Bayesian-style blend: `(α·prior + Σ samples) / (α + n)`
    - α decays as n grows (e.g. α=8 effective measurements)
  - `dailyKmEstimate(UserPrefs p, List<Trip> recentTrips) → double`
    - Use trip data jika cukup (>30d, >5 trips)
    - Else map dari usage_profile + weekly_km preferensi
- [x] T4.2 Auto-detect & record full-tank cycles:
  - Trigger di `createRefuel`: jika current refuel `is_full_tank=true`, cari refuel sebelumnya yang juga `is_full_tank=true` untuk vehicle yang sama
  - Hitung km via trip distance antara dua tanggal tersebut
  - Insert ke `fuel_efficiency_samples`
  - Skip kalau gak ada trip data (km tidak terukur)

## Phase 5 — Wire into UI

- [x] T5.1 Refactor `_FuelPredictionBlock` di `summary_tab.dart`:
  - Pakai `PredictionService.posteriorKmPerLiter`
  - Pakai `PredictionService.dailyKmEstimate`
  - Tampilkan source confidence badge (PRIOR / MIXED / DATA-DRIVEN)
- [x] T5.2 Tambah info "berdasarkan N pengukuran" di prediksi block

## Phase 6 — Verification

- [x] T6.1 `flutter analyze --no-pub` → 0 issues
- [ ] T6.2 Manual smoke test:
  - User baru tanpa data → prediksi muncul reasonable (bukan "—")
  - Setelah 1 full-tank cycle → measurement masuk ke samples table
  - Prediksi shift mendekati measurement aktual

---

## Out of scope (later)

- Tier 2 fields (RON detail, age proxy)
- Cluster trips by time-of-day / weekday-weekend
- Cross-user signal (collaborative filtering)
- Anomaly detection (suspicious refuel input)
