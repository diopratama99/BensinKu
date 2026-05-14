// supabase/functions/parse-fuel-voice/index.ts
//
// Parses an Indonesian transcript like "isi pertamax 50rb di motor honda"
// into a structured refuel draft using LLM.
//
// Speech is transcribed on-device by the Flutter client (speech_to_text); only
// the resulting text is sent here, so this function stays cheap and fast.
//
// Input  (POST JSON):
//   { transcript: string }
//
// Output (200 JSON): same shape as parse-fuel-receipt
//   {
//     refuel: { vehicle_id, vehicle_label, fuel_product_id, fuel_product_label,
//               refuel_date, odometer_km, total_rp, price_per_liter, liters,
//               is_full_tank, confidence, reasoning },
//     transcript: string
//   }
//
// Auth: requires the caller's JWT.

// deno-lint-ignore-file no-explicit-any
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
if (!OPENAI_API_KEY) throw new Error("Missing env: OPENAI_API_KEY");

const OPENAI_BASE_URL = Deno.env.get("OPENAI_BASE_URL");
if (!OPENAI_BASE_URL) throw new Error("Missing env: OPENAI_BASE_URL");

const OPENAI_CHAT_MODEL = Deno.env.get("OPENAI_CHAT_MODEL");
if (!OPENAI_CHAT_MODEL) throw new Error("Missing env: OPENAI_CHAT_MODEL");

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface VehicleRow {
  id: string;
  vehicle_type: "motor" | "mobil";
  name: string | null;
  tank_capacity_liters: number | null;
}

interface FuelProductRow {
  id: string;
  brand: string;
  name: string;
}

function todayJakarta(): string {
  const now = new Date();
  const jakarta = new Date(now.getTime() + 7 * 60 * 60 * 1000);
  return jakarta.toISOString().slice(0, 10);
}

function buildSystemPrompt(
  vehicles: VehicleRow[],
  fuelProducts: FuelProductRow[],
  today: string,
): string {
  const vehicleList = vehicles
    .map(
      (v) =>
        `  - id="${v.id}" type=${v.vehicle_type} name="${v.name ?? v.vehicle_type}"${
          v.tank_capacity_liters != null
            ? ` tank=${v.tank_capacity_liters}L`
            : ""
        }`,
    )
    .join("\n");
  const fuelList = fuelProducts
    .map((f) => `  - id="${f.id}" brand=${f.brand} name="${f.name}"`)
    .join("\n");

  return `Kamu adalah parser PENGISIAN BENSIN untuk aplikasi BensinKu (Bahasa Indonesia).
Tugasmu: ubah ucapan bebas user menjadi SATU transaksi pengisian bensin (JSON).

KONTEKS TANGGAL HARI INI: ${today} (Asia/Jakarta).

KENDARAAN USER:
${vehicleList || "  (kosong)"}

JENIS BBM YANG TERSEDIA:
${fuelList || "  (kosong)"}

PARSING JUMLAH RUPIAH:
- "20rb" / "20 ribu" / "20k" -> 20000
- "100 ribu" / "100rb" -> 100000
- "1jt" / "1 juta" -> 1000000
- "150rb" -> 150000
- "Rp 50.000" / "lima puluh ribu" -> 50000

PARSING LITER (kalau disebut):
- "5 liter" / "5L" -> 5
- "tiga liter" -> 3
- "setengah tanki" -> hitung dari kapasitas tanki kendaraan terpilih (jika ada)

ATURAN VEHICLE:
- "motor" / nama motor user -> kendaraan tipe motor
- "mobil" / nama mobil user -> kendaraan tipe mobil
- Kalau user cuma punya 1 kendaraan -> selalu pakai itu.
- Kalau user TIDAK menyebut kendaraan dan punya 2+:
  * BBM type Pertalite/Pertamax/Premium dengan total kecil -> motor
  * BBM diesel -> mobil
  * Default -> kendaraan pertama di list.

ATURAN FUEL PRODUCT:
- "pertalite" -> pertamina/Pertalite
- "pertamax" -> pertamina/Pertamax (kalau user bilang "pertamax turbo" -> Pertamax Turbo)
- "dexlite" -> pertamina/Dexlite
- "dex" / "pertamina dex" -> pertamina/Pertamina Dex
- "shell" sendirian -> Shell Super (default Shell)
- "v-power" / "vpower" -> Shell V-Power
- "v-power diesel" / "shell diesel" -> Shell V-Power Diesel
- Kalau tidak disebut, pakai BBM pertama di list.

CARA MENGHITUNG (PENTING):
- Kalau user sebut TOTAL_RP saja -> price_per_liter biarkan 0, biar client refresh
  dari fuel_prices. Liters juga set 0 untuk dihitung ulang di client.
- Kalau user sebut LITER + TOTAL -> hitung price_per_liter = total / liter, bulatkan.
- Kalau user sebut LITER + HARGA_PER_LITER -> hitung total_rp = liter * harga.

ATURAN OUTPUT:
1. vehicle_id WAJIB dari list KENDARAAN USER (UUID, persis).
2. fuel_product_id WAJIB dari list JENIS BBM (UUID, persis).
3. total_rp HARUS angka rupiah utuh (integer). Default 0 kalau benar-benar tidak disebut.
4. price_per_liter integer. Default 0 (client akan refresh dari DB).
5. liters number (max 3 desimal). Default 0 kalau tidak ada cukup info.
6. odometer_km null kecuali user bilang spidometer/odo.
7. refuel_date ${today} kecuali user bilang kemarin/tanggal lain.
8. is_full_tank true kalau user bilang "full tank" / "isi penuh".
9. confidence "high"/"medium"/"low" sesuai kejelasan ucapan.
10. reasoning 1 kalimat singkat.

CONTOH:
- "Isi bensin pertamax 50rb"
  -> fuel=Pertamax, total_rp=50000, price_per_liter=0, liters=0
- "Isi pertalite 5 liter di motor"
  -> vehicle=motor, fuel=Pertalite, liters=5, total_rp=0
- "Isi pertamax 12 liter total 162 ribu"
  -> fuel=Pertamax, liters=12, total_rp=162000, price_per_liter=13500
- "Isi full tank pertamax mobil"
  -> vehicle=mobil, fuel=Pertamax, is_full_tank=true (liters & total dari kapasitas+harga)
- "Beli bensin shell 100rb kemarin"
  -> fuel=Shell Super, total_rp=100000, refuel_date=${today} minus 1 day

FORMAT OUTPUT (WAJIB):
Balas HANYA satu objek JSON valid:
{ "refuel": { ...field di atas... } }
Tanpa markdown, tanpa backticks.

Jika ucapan tidak terkait pengisian bensin / kosong, balas:
{ "refuel": null }`;
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }
  if (!OPENAI_API_KEY) {
    return jsonResponse({ error: "missing_openai_api_key" }, 500);
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }

  let payload: { transcript?: string };
  try {
    payload = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }

  const transcript = (payload.transcript ?? "").trim();
  if (!transcript) {
    return jsonResponse({ error: "empty_transcript" }, 400);
  }
  if (transcript.length > 600) {
    return jsonResponse({ error: "transcript_too_long" }, 400);
  }

  // 1. Fetch caller's vehicles + fuel products from bensinku schema.
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    db: { schema: "bensinku" },
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });

  const [vehiclesRes, fuelsRes] = await Promise.all([
    supabase
      .from("vehicles")
      .select("id, vehicle_type, name, tank_capacity_liters")
      .order("vehicle_type"),
    supabase
      .from("fuel_products")
      .select("id, brand, name")
      .eq("active", true)
      .order("brand")
      .order("sort_order"),
  ]);

  if (vehiclesRes.error) {
    return jsonResponse(
      { error: "vehicles_query_failed", detail: vehiclesRes.error.message },
      500,
    );
  }
  if (fuelsRes.error) {
    return jsonResponse(
      { error: "fuel_products_query_failed", detail: fuelsRes.error.message },
      500,
    );
  }

  const vehicles = (vehiclesRes.data ?? []) as VehicleRow[];
  const fuelProducts = (fuelsRes.data ?? []) as FuelProductRow[];

  if (vehicles.length === 0) {
    return jsonResponse(
      { error: "no_vehicles", detail: "User belum punya kendaraan." },
      400,
    );
  }
  if (fuelProducts.length === 0) {
    return jsonResponse(
      { error: "no_fuel_products", detail: "Master BBM kosong." },
      400,
    );
  }

  // 2. Call LLM.
  const today = todayJakarta();
  const systemPrompt = buildSystemPrompt(vehicles, fuelProducts, today);

  const openaiRes = await fetch(`${OPENAI_BASE_URL}/chat/completions`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${OPENAI_API_KEY}`,
    },
    body: JSON.stringify({
      model: OPENAI_CHAT_MODEL,
      stream: false,
      temperature: 0.1,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: transcript },
      ],
    }),
  });

  if (!openaiRes.ok) {
    const detail = await openaiRes.text();
    return jsonResponse(
      { error: "openai_call_failed", status: openaiRes.status, detail },
      502,
    );
  }

  const openaiBody: any = await openaiRes.json();
  const raw = openaiBody?.choices?.[0]?.message?.content;
  if (typeof raw !== "string") {
    return jsonResponse({ error: "empty_llm_response" }, 502);
  }

  let parsed: any;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return jsonResponse({ error: "invalid_llm_json", raw }, 502);
  }

  const item = parsed?.refuel;
  if (!item || typeof item !== "object") {
    return jsonResponse(
      { error: "no_refuel_parsed", detail: "Tidak terdeteksi pengisian.", raw },
      422,
    );
  }

  // 3. Validate + force onto a known shape (same as receipt).
  let vehicle = vehicles.find((v) => v.id === item.vehicle_id);
  if (!vehicle) vehicle = vehicles[0];

  let fuel = fuelProducts.find((f) => f.id === item.fuel_product_id);
  if (!fuel) fuel = fuelProducts[0];

  const totalRp = Math.max(0, Math.round(Number(item.total_rp) || 0));
  const pricePerLiter = Math.max(
    0,
    Math.round(Number(item.price_per_liter) || 0),
  );
  let liters = Number(item.liters);
  if (!Number.isFinite(liters) || liters < 0) liters = 0;
  liters = Math.round(liters * 1000) / 1000;

  const odometerKm =
    item.odometer_km == null
      ? null
      : Math.max(0, Number(item.odometer_km) || 0);

  const date = /^\d{4}-\d{2}-\d{2}$/.test(item.refuel_date ?? "")
    ? item.refuel_date
    : today;

  const isFullTank = item.is_full_tank === true;

  const vehicleLabel = `${vehicle.vehicle_type === "motor" ? "Motor" : "Mobil"} — ${
    vehicle.name ?? vehicle.vehicle_type
  }`;
  const brandCap = fuel.brand
    ? fuel.brand[0].toUpperCase() + fuel.brand.slice(1)
    : "";
  const fuelLabel = `${brandCap} — ${fuel.name}`;

  return jsonResponse(
    {
      refuel: {
        vehicle_id: vehicle.id,
        vehicle_label: vehicleLabel,
        fuel_product_id: fuel.id,
        fuel_product_label: fuelLabel,
        refuel_date: date,
        odometer_km: odometerKm,
        total_rp: totalRp,
        price_per_liter: pricePerLiter,
        liters,
        is_full_tank: isFullTank,
        confidence:
          item.confidence === "high" ||
          item.confidence === "medium" ||
          item.confidence === "low"
            ? item.confidence
            : "medium",
        reasoning:
          typeof item.reasoning === "string" ? item.reasoning.trim() : "",
      },
      transcript,
    },
    200,
  );
});
