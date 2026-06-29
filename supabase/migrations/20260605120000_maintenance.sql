-- =============================================================================
-- BensinKu — Maintenance reminders.
--
-- Goal:
--   Tabel `bensinku.maintenance_items` untuk menyimpan jadwal perawatan
--   kendaraan (ganti oli, ban, busi, dst). Time-based by design — reminder
--   dipicu dari `last_service_date + interval_days`. Tidak butuh odometer.
--
-- Sifat migration:
--   - Forward-only. Jangan edit setelah dijalankan; bikin file baru kalau
--     perlu fix.
--   - Idempotent: aman di-run berkali-kali.
--   - Non-destructive: tidak ada DROP / TRUNCATE / DELETE data user.
--
-- Asumsi:
--   - Schema `bensinku` + tabel `vehicles` sudah ada (lihat migration
--     20260514120000_move_to_bensinku_schema.sql).
-- =============================================================================

create table if not exists bensinku.maintenance_items (
  id                 uuid          primary key default gen_random_uuid(),
  user_id            uuid          not null default auth.uid(),
  vehicle_id         uuid          not null
                                     references bensinku.vehicles (id)
                                     on delete cascade,
  type               text          not null,
  title              text          null,
  interval_days      int           not null check (interval_days between 1 and 3650),
  last_service_date  timestamptz   not null,
  note               text          null,
  created_at         timestamptz   not null default now()
);

-- Enum-ish CHECK for `type` (named + guarded so re-run is safe).
do $$
begin
  if not exists (
    select 1 from pg_constraint
     where conname = 'maintenance_items_type_chk'
       and conrelid = 'bensinku.maintenance_items'::regclass
  ) then
    alter table bensinku.maintenance_items
      add constraint maintenance_items_type_chk
      check (type in (
        'engine_oil', 'transmission_oil', 'tires', 'spark_plug',
        'brake_pads', 'air_filter', 'battery', 'general_service',
        'cvt_service', 'chain', 'coolant', 'other'
      ));
  end if;
end$$;

create index if not exists maintenance_items_vehicle_idx
  on bensinku.maintenance_items (vehicle_id);

create index if not exists maintenance_items_user_idx
  on bensinku.maintenance_items (user_id);

-- RLS — owner only.
alter table bensinku.maintenance_items enable row level security;

drop policy if exists maintenance_items_select_own
  on bensinku.maintenance_items;
create policy maintenance_items_select_own
  on bensinku.maintenance_items
  for select to authenticated
  using (user_id = auth.uid());

drop policy if exists maintenance_items_insert_own
  on bensinku.maintenance_items;
create policy maintenance_items_insert_own
  on bensinku.maintenance_items
  for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists maintenance_items_update_own
  on bensinku.maintenance_items;
create policy maintenance_items_update_own
  on bensinku.maintenance_items
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists maintenance_items_delete_own
  on bensinku.maintenance_items;
create policy maintenance_items_delete_own
  on bensinku.maintenance_items
  for delete to authenticated
  using (user_id = auth.uid());

grant all on bensinku.maintenance_items
  to anon, authenticated, service_role;

-- =============================================================================
-- End of migration.
-- =============================================================================
