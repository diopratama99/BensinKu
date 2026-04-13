# bensinku

Prototype aplikasi tracking bensin (Flutter + Supabase).

## Fitur prototype

- Limit kendaraan: 1 Motor + 1 Mobil (enforced di DB via UNIQUE).
- Input pengisian pakai nominal (Rp) → liter dihitung otomatis dari `fuel_prices`.
- 3 tab: Ringkasan / Tambah / Riwayat.
- Harga BBM read-only di client (diubah via server/admin).

## Getting Started

### 1) Konfigurasi Supabase (self-host)

Panduan setup Docker + Supabase self-host ada di [server/SUPABASE_SELFHOST_GUIDE.md](server/SUPABASE_SELFHOST_GUIDE.md).

Jalankan SQL berikut di Supabase Studio:

- `supabase/schema.sql`
- `supabase/seed.sql`

Lalu isi tabel `fuel_prices` sesuai harga yang kamu pakai.

### 2) Run Flutter

Cara paling simple (nggak perlu ngetik command panjang) pakai file `dart-define`:

1) Copy file contoh:

```
cp supabase.defines.example.json supabase.defines.json
```

2) Edit `supabase.defines.json` isi `SUPABASE_URL` dan `SUPABASE_ANON_KEY`.

3) Run:

```
flutter run --dart-define-from-file=supabase.defines.json
```

Alternatif (manual) pakai `dart-define`:

```
flutter run --dart-define=SUPABASE_URL=... \
	--dart-define=SUPABASE_ANON_KEY=...
```

Catatan:

- `SUPABASE_ANON_KEY` aman di client.
- Jangan pernah taruh `service_role` key di Flutter.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
