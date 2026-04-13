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

-- 3) Trip tracking tables
create table if not exists public.trips (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users not null,
  vehicle_id uuid references public.vehicles on delete cascade not null,
  started_at timestamptz not null,
  ended_at timestamptz,
  distance_km numeric(10,3),
  note text,
  created_at timestamptz default now()
);

create table if not exists public.trip_waypoints (
  id bigint generated always as identity primary key,
  trip_id uuid references public.trips on delete cascade not null,
  lat double precision not null,
  lng double precision not null,
  recorded_at timestamptz not null
);

alter table public.trips enable row level security;
alter table public.trip_waypoints enable row level security;

do $$
begin
  create policy "user_trips" on public.trips for all
    using (user_id = auth.uid()) with check (user_id = auth.uid());
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create policy "user_trip_waypoints" on public.trip_waypoints for all
    using (trip_id in (select id from public.trips where user_id = auth.uid()));
exception
  when duplicate_object then null;
end $$;
