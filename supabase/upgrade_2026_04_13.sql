-- Upgrade script (2026-04-13)
-- Jalankan ini kalau kamu sudah pernah menjalankan supabase/schema.sql sebelumnya.

-- 1) Vehicles: kapasitas tanki
alter table if exists public.vehicles
  add column if not exists tank_capacity_liters numeric(8,2);

do $$
begin
  alter table public.vehicles
    add constraint vehicles_tank_capacity_positive
    check (tank_capacity_liters is null or tank_capacity_liters > 0);
exception
  when duplicate_object then null;
end $$;

-- 2) Refuels: spidometer jadi opsional
alter table if exists public.refuels
  alter column odometer_km drop not null;

-- Replace old constraint if present (best-effort)
alter table if exists public.refuels
  drop constraint if exists refuels_odometer_km_check;

do $$
begin
  alter table public.refuels
    add constraint refuels_odometer_km_check
    check (odometer_km is null or odometer_km >= 0);
exception
  when duplicate_object then null;
end $$;
