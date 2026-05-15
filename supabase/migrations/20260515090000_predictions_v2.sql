-- =============================================================================
-- BensinKu — Predictions v2 schema additions.
--
-- Goals:
--   1. Tambah kolom-kolom detail mesin di `bensinku.vehicles` agar prediksi
--      konsumsi bisa pakai prior yang masuk akal (anti cold-start).
--   2. Tambah tabel `bensinku.fuel_efficiency_samples` untuk merekam
--      ground-truth km/L tiap kali ada full-tank → full-tank cycle. Ini yang
--      nanti dipakai untuk Bayesian update terhadap prior.
--
-- Sifat migration:
--   - Forward-only. Jangan edit setelah dijalankan; bikin file baru kalau
--     perlu fix.
--   - Idempotent: aman di-run berkali-kali (semua statement pakai
--     IF NOT EXISTS / DO blocks dengan probe ke information_schema).
--   - Non-destructive: tidak ada DROP / TRUNCATE / DELETE data user.
--
-- Asumsi:
--   - Schema `bensinku` + tabel `vehicles`, `refuels` sudah ada (lihat
--     migration 20260514120000_move_to_bensinku_schema.sql).
--   - User pakai `auth.users` shared dengan app TemanKu/IngatanKu/dst —
--     RLS untuk fuel_efficiency_samples filter berdasarkan auth.uid().
-- =============================================================================

-- ── 1. Vehicles: detail mesin (semua nullable supaya backward-compatible) ──
do $$
begin
  if not exists (
    select 1 from information_schema.columns
     where table_schema = 'bensinku'
       and table_name   = 'vehicles'
       and column_name  = 'engine_cc'
  ) then
    alter table bensinku.vehicles add column engine_cc int null;
  end if;

  if not exists (
    select 1 from information_schema.columns
     where table_schema = 'bensinku'
       and table_name   = 'vehicles'
       and column_name  = 'manufacturing_year'
  ) then
    alter table bensinku.vehicles add column manufacturing_year int null;
  end if;

  if not exists (
    select 1 from information_schema.columns
     where table_schema = 'bensinku'
       and table_name   = 'vehicles'
       and column_name  = 'body_type'
  ) then
    -- Hanya untuk mobil. Motor → null.
    alter table bensinku.vehicles add column body_type text null;
  end if;

  if not exists (
    select 1 from information_schema.columns
     where table_schema = 'bensinku'
       and table_name   = 'vehicles'
       and column_name  = 'transmission'
  ) then
    alter table bensinku.vehicles add column transmission text null;
  end if;

  if not exists (
    select 1 from information_schema.columns
     where table_schema = 'bensinku'
       and table_name   = 'vehicles'
       and column_name  = 'recommended_ron'
  ) then
    alter table bensinku.vehicles add column recommended_ron smallint null;
  end if;

  if not exists (
    select 1 from information_schema.columns
     where table_schema = 'bensinku'
       and table_name   = 'vehicles'
       and column_name  = 'make_model'
  ) then
    alter table bensinku.vehicles add column make_model text null;
  end if;
end$$;

-- ── 2. Vehicles: validasi nilai enum-ish lewat CHECK constraints ──
--     CHECK ditambahkan dengan nama eksplisit + IF NOT EXISTS guard supaya
--     re-run aman.
do $$
begin
  -- engine_cc: 50–9999 (wajar untuk motor 50cc s/d truk besar)
  if not exists (
    select 1 from pg_constraint
     where conname = 'vehicles_engine_cc_range_chk'
       and conrelid = 'bensinku.vehicles'::regclass
  ) then
    alter table bensinku.vehicles
      add constraint vehicles_engine_cc_range_chk
      check (engine_cc is null or engine_cc between 50 and 9999);
  end if;

  -- manufacturing_year: 1980 .. (current year + 1) — pakai literal upper agar
  --   immutable, di-bump tiap dekade jika perlu.
  if not exists (
    select 1 from pg_constraint
     where conname = 'vehicles_manufacturing_year_range_chk'
       and conrelid = 'bensinku.vehicles'::regclass
  ) then
    alter table bensinku.vehicles
      add constraint vehicles_manufacturing_year_range_chk
      check (manufacturing_year is null
             or manufacturing_year between 1980 and 2035);
  end if;

  -- body_type: enum-ish via CHECK. Motor harus null, mobil bebas pilih.
  if not exists (
    select 1 from pg_constraint
     where conname = 'vehicles_body_type_chk'
       and conrelid = 'bensinku.vehicles'::regclass
  ) then
    alter table bensinku.vehicles
      add constraint vehicles_body_type_chk
      check (
        body_type is null
        or body_type in ('sedan', 'hatchback', 'mpv', 'suv', 'pickup', 'sport')
      );
  end if;

  -- body_type only-for-mobil: motor wajib null.
  if not exists (
    select 1 from pg_constraint
     where conname = 'vehicles_body_type_motor_null_chk'
       and conrelid = 'bensinku.vehicles'::regclass
  ) then
    alter table bensinku.vehicles
      add constraint vehicles_body_type_motor_null_chk
      check (vehicle_type <> 'motor' or body_type is null);
  end if;

  -- transmission: subset of common ID terms.
  if not exists (
    select 1 from pg_constraint
     where conname = 'vehicles_transmission_chk'
       and conrelid = 'bensinku.vehicles'::regclass
  ) then
    alter table bensinku.vehicles
      add constraint vehicles_transmission_chk
      check (
        transmission is null
        or transmission in ('manual', 'at', 'cvt', 'dct')
      );
  end if;

  -- recommended_ron: nilai BBM populer di ID. 90=Pertalite, 92=Pertamax,
  --   95=Pertamax Turbo (lama)/V-Power, 98=Pertamax Turbo (baru).
  if not exists (
    select 1 from pg_constraint
     where conname = 'vehicles_recommended_ron_chk'
       and conrelid = 'bensinku.vehicles'::regclass
  ) then
    alter table bensinku.vehicles
      add constraint vehicles_recommended_ron_chk
      check (recommended_ron is null
             or recommended_ron in (88, 90, 92, 95, 98));
  end if;
end$$;

-- ── 3. Tabel `fuel_efficiency_samples` ──
--     Merekam tiap full-tank → full-tank cycle: km tempuh / liter terisi.
--     Auto-populated oleh app side ketika user catat refuel dengan
--     is_full_tank=true.
create table if not exists bensinku.fuel_efficiency_samples (
  id              uuid        primary key default gen_random_uuid(),
  user_id         uuid        not null,
  vehicle_id      uuid        not null
                                references bensinku.vehicles (id)
                                on delete cascade,
  from_refuel_id  uuid        null
                                references bensinku.refuels (id)
                                on delete set null,
  to_refuel_id    uuid        null
                                references bensinku.refuels (id)
                                on delete set null,
  km_traveled     numeric(10,2) not null
                                check (km_traveled > 0),
  liters_filled   numeric(10,2) not null
                                check (liters_filled > 0),
  km_per_liter    numeric(10,4) generated always as
                                  (km_traveled / liters_filled) stored,
  measured_at     timestamptz   not null default now(),
  -- Future-proof: tag konteks (weekday/weekend, kota, dll). JSONB supaya
  -- gak perlu migration tiap kali nambah dimensi konteks baru.
  context         jsonb         null
);

-- Foreign key ke auth.users (cross-schema) — tidak pakai ON DELETE CASCADE
-- karena auth.users dikelola Supabase auth dan akun bisa di-soft-delete.
do $$
begin
  if not exists (
    select 1 from pg_constraint
     where conname = 'fuel_efficiency_samples_user_id_fkey'
       and conrelid = 'bensinku.fuel_efficiency_samples'::regclass
  ) then
    alter table bensinku.fuel_efficiency_samples
      add constraint fuel_efficiency_samples_user_id_fkey
      foreign key (user_id) references auth.users (id);
  end if;
end$$;

-- Idempotent: prevent double-insert untuk pasangan refuel yang sama.
create unique index if not exists fuel_efficiency_samples_pair_uidx
  on bensinku.fuel_efficiency_samples (vehicle_id, from_refuel_id, to_refuel_id)
  where from_refuel_id is not null and to_refuel_id is not null;

create index if not exists fuel_efficiency_samples_vehicle_measured_idx
  on bensinku.fuel_efficiency_samples (vehicle_id, measured_at desc);

create index if not exists fuel_efficiency_samples_user_measured_idx
  on bensinku.fuel_efficiency_samples (user_id, measured_at desc);

-- ── 4. RLS untuk fuel_efficiency_samples ──
alter table bensinku.fuel_efficiency_samples enable row level security;

-- Drop-then-create untuk policies supaya re-run aman tanpa "already exists".
drop policy if exists fuel_efficiency_samples_select_own
  on bensinku.fuel_efficiency_samples;
create policy fuel_efficiency_samples_select_own
  on bensinku.fuel_efficiency_samples
  for select
  using (user_id = auth.uid());

drop policy if exists fuel_efficiency_samples_insert_own
  on bensinku.fuel_efficiency_samples;
create policy fuel_efficiency_samples_insert_own
  on bensinku.fuel_efficiency_samples
  for insert
  with check (user_id = auth.uid());

drop policy if exists fuel_efficiency_samples_update_own
  on bensinku.fuel_efficiency_samples;
create policy fuel_efficiency_samples_update_own
  on bensinku.fuel_efficiency_samples
  for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists fuel_efficiency_samples_delete_own
  on bensinku.fuel_efficiency_samples;
create policy fuel_efficiency_samples_delete_own
  on bensinku.fuel_efficiency_samples
  for delete
  using (user_id = auth.uid());

-- ── 5. Grants (mengikuti default privileges schema bensinku) ──
grant all on bensinku.fuel_efficiency_samples
  to anon, authenticated, service_role;

-- =============================================================================
-- End of migration.
-- =============================================================================
