-- =============================================================================
-- BensinKu — Move all app objects from `public` schema to `bensinku` schema.
--
-- Context:
--   Supabase self-hosted Postgres dipakai bersama beberapa app (IngatanKu,
--   TemanKu, BensinKu, dst). Tiap app dipindahin ke schema sendiri biar
--   tidak rebutan namespace di public.
--
-- Sifat migration:
--   - Forward-only (bikin file baru kalau perlu fix; jangan edit yang ini
--     setelah dijalankan).
--   - Idempotent (aman di-run berkali-kali).
--   - Non-destructive (tidak ada DROP TABLE / TRUNCATE / DELETE data user).
--
-- Audit ringkas:
--   Tables  : vehicles, fuel_products, fuel_prices, refuels, trips,
--             trip_waypoints
--   Functions: (none — BensinKu tidak punya function custom)
--   Trigger di auth.users: (none — BensinKu tidak punya signup hook)
--   RLS, index, constraint: ikut otomatis dengan ALTER TABLE SET SCHEMA.
-- =============================================================================

-- 2a. Schema -----------------------------------------------------------------
create schema if not exists bensinku;

-- 2b. (Skip) — BensinKu tidak attach trigger di auth.users, jadi tidak ada
--      yang perlu di-drop dulu.

-- 2c. Move tables (MOVE list) -----------------------------------------------
--     RLS policies, indexes, constraints, dan trigger tabel-level (kalau ada)
--     ikut otomatis. ALTER ... IF EXISTS bikin re-run aman: kalau tabel sudah
--     ada di bensinku (tidak ada lagi di public), statement no-op.
alter table if exists public.vehicles       set schema bensinku;
alter table if exists public.fuel_products  set schema bensinku;
alter table if exists public.fuel_prices    set schema bensinku;
alter table if exists public.refuels        set schema bensinku;
alter table if exists public.trips          set schema bensinku;
alter table if exists public.trip_waypoints set schema bensinku;

-- 2d. (Skip) — Tidak ada tabel di COEXIST list (nama unik untuk BensinKu).

-- 2e. (Skip) — Tidak ada function untuk dipindah.

-- 2f. (Skip) — Tidak ada function body untuk di-recreate.

-- 2g. (Skip) — Tidak ada trigger di auth.users yang perlu di-recreate.
--      App lain (IngatanKu, TemanKu, dst) yang punya signup hook tidak
--      tersentuh karena migration ini hanya mengubah objek di `public` ->
--      `bensinku`, tidak menyentuh `auth.users` sama sekali.

-- 2h. (Skip) — Tidak ada trigger tabel-level yang nge-reference function di
--      schema lain. Trigger tabel-level (kalau eventually ditambahkan) ikut
--      pindah otomatis bersama tabel.

-- 2i. Grants & default privileges --------------------------------------------
grant usage on schema bensinku to anon, authenticated, service_role;

grant all on all tables    in schema bensinku to anon, authenticated, service_role;
grant all on all sequences in schema bensinku to anon, authenticated, service_role;
grant all on all functions in schema bensinku to anon, authenticated, service_role;

alter default privileges in schema bensinku
  grant all on tables    to anon, authenticated, service_role;
alter default privileges in schema bensinku
  grant all on sequences to anon, authenticated, service_role;
alter default privileges in schema bensinku
  grant all on functions to anon, authenticated, service_role;

-- =============================================================================
-- End of migration.
-- =============================================================================
