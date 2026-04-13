-- Seed fuel_products (Pertamina + Shell). Jalankan setelah schema.sql.

insert into public.fuel_products (brand, name, sort_order, active)
values
  ('pertamina', 'Pertalite', 10, true),
  ('pertamina', 'Pertamax', 20, true),
  ('pertamina', 'Pertamax Turbo', 30, true),
  ('pertamina', 'Dexlite', 40, true),
  ('pertamina', 'Pertamina Dex', 50, true),

  ('shell', 'Shell Super', 10, true),
  ('shell', 'Shell V-Power', 20, true),
  ('shell', 'Shell V-Power Nitro+', 30, true),
  ('shell', 'Shell V-Power Diesel', 40, true)
on conflict (brand, name) do update
set
  sort_order = excluded.sort_order,
  active = excluded.active;

-- fuel_prices sengaja tidak di-seed karena biasanya sering berubah.
-- Contoh insert (sesuaikan harganya):
-- insert into public.fuel_prices (fuel_product_id, effective_from, price_per_liter)
-- select id, '2026-04-01'::date, 10000
-- from public.fuel_products
-- where brand = 'pertamina' and name = 'Pertalite';
