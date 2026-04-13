-- BensinKu prototype schema (Supabase / Postgres)
-- Jalankan di SQL Editor (Supabase Studio) pada project self-host kamu.

-- Extensions
create extension if not exists "uuid-ossp";

-- VEHICLES (limit: 1 motor + 1 mobil per user)
create table if not exists public.vehicles (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null default auth.uid(),
  vehicle_type text not null check (vehicle_type in ('motor', 'mobil')),
  name text,
  tank_capacity_liters numeric(8,2) check (tank_capacity_liters is null or tank_capacity_liters > 0),
  created_at timestamptz not null default now(),
  unique (user_id, vehicle_type)
);

create index if not exists vehicles_user_id_idx on public.vehicles (user_id);

-- FUEL PRODUCTS (master data: Pertamina + Shell)
create table if not exists public.fuel_products (
  id uuid primary key default uuid_generate_v4(),
  brand text not null check (brand in ('pertamina', 'shell')),
  name text not null,
  active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  unique (brand, name)
);

-- FUEL PRICES (master data, edited by server/admin only)
create table if not exists public.fuel_prices (
  id uuid primary key default uuid_generate_v4(),
  fuel_product_id uuid not null references public.fuel_products(id) on delete cascade,
  effective_from date not null,
  price_per_liter numeric(14,2) not null check (price_per_liter > 0),
  created_at timestamptz not null default now(),
  unique (fuel_product_id, effective_from)
);

create index if not exists fuel_prices_product_date_idx
  on public.fuel_prices (fuel_product_id, effective_from desc);

-- REFUELS
create table if not exists public.refuels (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null default auth.uid(),
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  fuel_product_id uuid not null references public.fuel_products(id),
  refuel_date timestamptz not null,
  odometer_km numeric(14,1) check (odometer_km is null or odometer_km >= 0),
  total_rp numeric(18,0) not null check (total_rp >= 0),
  price_per_liter_snapshot numeric(14,2) not null check (price_per_liter_snapshot > 0),
  liters numeric(14,3) not null check (liters > 0),
  is_full_tank boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists refuels_user_id_idx on public.refuels (user_id);
create index if not exists refuels_vehicle_date_idx on public.refuels (vehicle_id, refuel_date desc);

-- RLS
alter table public.vehicles enable row level security;
alter table public.refuels enable row level security;
alter table public.fuel_products enable row level security;
alter table public.fuel_prices enable row level security;

-- Vehicles: only owner
drop policy if exists "vehicles_select_own" on public.vehicles;
create policy "vehicles_select_own" on public.vehicles
for select to authenticated
using (user_id = auth.uid());

drop policy if exists "vehicles_insert_own" on public.vehicles;
create policy "vehicles_insert_own" on public.vehicles
for insert to authenticated
with check (user_id = auth.uid());

drop policy if exists "vehicles_update_own" on public.vehicles;
create policy "vehicles_update_own" on public.vehicles
for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "vehicles_delete_own" on public.vehicles;
create policy "vehicles_delete_own" on public.vehicles
for delete to authenticated
using (user_id = auth.uid());

-- Refuels: only owner
drop policy if exists "refuels_select_own" on public.refuels;
create policy "refuels_select_own" on public.refuels
for select to authenticated
using (user_id = auth.uid());

drop policy if exists "refuels_insert_own" on public.refuels;
create policy "refuels_insert_own" on public.refuels
for insert to authenticated
with check (user_id = auth.uid());

drop policy if exists "refuels_update_own" on public.refuels;
create policy "refuels_update_own" on public.refuels
for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "refuels_delete_own" on public.refuels;
create policy "refuels_delete_own" on public.refuels
for delete to authenticated
using (user_id = auth.uid());

-- Fuel master data: read-only for authenticated clients
drop policy if exists "fuel_products_read" on public.fuel_products;
create policy "fuel_products_read" on public.fuel_products
for select to authenticated
using (active = true);

drop policy if exists "fuel_prices_read" on public.fuel_prices;
create policy "fuel_prices_read" on public.fuel_prices
for select to authenticated
using (true);

-- Note: Do NOT create insert/update/delete policies for fuel_products/fuel_prices.
-- Admin changes should be done via Supabase Studio or server-side using service_role key.
