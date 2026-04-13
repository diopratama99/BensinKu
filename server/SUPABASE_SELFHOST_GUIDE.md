# Supabase self-host (homeserver) guide

Catatan: aku nggak bisa remote-install ke server kamu tanpa akses SSH dari sini. Pakai langkah di bawah di server.

## 0) Akses server

SSH ke server kamu dulu, contoh:

```bash
ssh <user>@<ip>
```

IP `100.106.53.46` terlihat seperti IP Tailscale; artinya akses biasanya hanya dari device yang join network Tailscale.

## 1) Install Docker (Ubuntu/Debian)

Jalankan script:

```bash
chmod +x server/setup_docker_ubuntu.sh
./server/setup_docker_ubuntu.sh
```

Lalu **logout/login** supaya group `docker` aktif.

## 2) Jalankan Supabase self-host

```bash
chmod +x server/setup_supabase_selfhost.sh
./server/setup_supabase_selfhost.sh ~/supabase-selfhost
cd ~/supabase-selfhost/supabase/docker
nano .env
```

Minimal yang wajib kamu set di `.env`:
- `POSTGRES_PASSWORD`
- `JWT_SECRET`
- `ANON_KEY`
- `SERVICE_ROLE_KEY` (jangan dipakai di Flutter)

### Kalau Sign Up error: "Error sending confirmation email"

Itu karena Auth (GoTrue) mencoba kirim email konfirmasi, tapi SMTP belum dikonfigurasi.

Untuk development paling simpel: **auto-confirm** user (tanpa kirim email).
Di file `.env` Supabase docker (lokasi: `~/supabase-selfhost/supabase/docker/.env`) lakukan salah satu ini (tergantung variabel yang ada di file kamu):

```bash
# Kalau .env kamu punya variabel ini (umum di template Supabase):
ENABLE_EMAIL_AUTOCONFIRM=true

# Atau kalau yang ada format GOTRUE_* langsung:
# GOTRUE_MAILER_AUTOCONFIRM=true
```

Alternatif (lebih proper): set SMTP (mailer) sesuai provider email yang kamu pakai.

Setelah ubah `.env`, restart container:

```bash
cd ~/supabase-selfhost/supabase/docker
docker compose up -d
```

Cek status:

```bash
docker ps
docker compose logs -f --tail=100
```

## 3) Port penting

Umumnya:
- Supabase API gateway (Kong): `http://<server>:8000`
- Supabase Studio: `http://<server>:3000`

Kalau kamu expose ke internet, wajib pakai HTTPS (reverse proxy) dan firewall.

## 4) Hubungkan ke Flutter

Di Flutter jalankan:

```bash
flutter run --dart-define-from-file=supabase.defines.json

# atau (manual)
flutter run --dart-define=SUPABASE_URL=http://<server>:8000 \
  --dart-define=SUPABASE_ANON_KEY=<ANON_KEY>
```

## 5) Setup schema

Di Supabase Studio (SQL Editor), jalankan:
- `supabase/schema.sql`
- `supabase/seed.sql`

Kalau DB kamu sudah pernah dibuat sebelumnya, dan kamu update app versi terbaru:
- jalankan `supabase/upgrade_2026_04_13.sql` (menambah kapasitas tanki + odometer opsional)

Lalu isi `fuel_prices` sesuai harga.

### Troubleshooting: PGRST205 "Could not find the table ... in the schema cache"

Kalau app menampilkan error seperti:

> Could not find the table 'public.vehicles' in the schema cache (PGRST205)

Berarti schema belum ada atau PostgREST belum refresh cache.

- Pastikan kamu menjalankan `supabase/schema.sql` dulu, baru `supabase/seed.sql`.
- Kalau sudah, restart Supabase (minimal service REST/PostgREST) dari folder docker:

```bash
cd ~/supabase-selfhost/supabase/docker
docker compose up -d
```

## Security

- Jangan pernah taruh `SERVICE_ROLE_KEY` di mobile app.
- Jangan share password/kredensial di chat.
- Untuk produksi: set email confirmation sesuai kebutuhan dan pertimbangkan backup Postgres.
