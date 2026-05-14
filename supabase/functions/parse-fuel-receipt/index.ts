// supabase/functions/parse-fuel-receipt/index.ts
//
// Reads a photo of an SPBU receipt (Pertamina, Shell, etc.) and converts it
// into a structured refuel draft using LLM vision.
//
// One receipt = one refuel transaction. The flutter client previews the draft
// and lets the user confirm / edit before inserting into bensinku.refuels.
//
// Input  (POST JSON):
//   {
//     image_base64: string,   // raw base64, no data: prefix
//     mime: "image/jpeg" | "image/png" | "image/webp"
//   }
//
// Output (200 JSON):
//   {
//     refuel: {
//       vehicle_id: string,           // resolved from user's vehicles
//       vehicle_label: string,        // human-readable for preview
//       fuel_product_id: string,      // resolved from fuel_products
//       fuel_product_label: string,   // human-readable
//       refuel_date: "YYYY-MM-DD",
//       odometer_km: number | null,
//       total_rp: number,             // rupiah, integer
//       price_per_liter: number,      // rupiah, integer
//       liters: number,               // 3 decimals
//       is_full_tank: boolean,
//       confidence: "high" | "medium" | "low",
//       reasoning: string
//     },
//     transcript: string
//   }
//
// Auth: requires the caller's JWT (forwarded so RLS scopes vehicles per user).

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

const ALLOWED_MIMES = new Set([
  "image/jpeg",
  "image/jpg",
  "image/png",
  "image/webp",
]);
// Hard cap on the *base64* payload size. ~6.5 MB base64 ≈ ~5 MB raw image.
const MAX_BASE64_BYTES = 6_500_000;

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

  return `Kamu adalah parser STRUK SPBU untuk aplikasi BensinKu (Bahasa Indonesia).
Tugasmu: lihat foto struk pengisian bensin yang dikirim user, lalu ubah jadi
JSON terstruktur untuk satu transaksi pengisian.

Satu struk SPBU = SATU transaksi pengisian bensin.

KONTEKS TANGGAL HARI INI: ${today} (Asia/Jakarta).

KENDARAAN USER (pilih id yang paling cocok):
${vehicleList || "  (kosong)"}

JENIS BBM YANG TERSEDIA (pilih id yang paling cocok, JANGAN buat baru):
${fuelList || "  (kosong)"}

CARA BACA STRUK SPBU:
1. total_rp = TOTAL RUPIAH yang dibayar.
   - Cari label "TOTAL", "GRAND TOTAL", "JUMLAH BAYAR", "BAYAR".
   - Format struk SPBU biasanya tampilkan harga dalam ribuan: "Rp 50.000" -> 50000.
   - Hilangkan pemisah ribuan: "20.000" / "20,000" -> 20000.

2. price_per_liter = HARGA PER LITER.
   - Cari label "HARGA/L", "HARGA/LITER", "Rp/L".
   - Untuk Pertamina struk biasa: "Pertalite Rp 10.000/L" -> 10000.

3. liters = JUMLAH LITER yang diisi.
   - Cari label "VOLUME", "LITER", "QTY", atau angka dengan satuan "L".
   - Bisa berupa decimal: "5.234 L" -> 5.234.
   - Jika tidak terbaca, hitung dari total_rp / price_per_liter.

4. fuel_product_id = pilih dari list di atas.
   - "Pertalite" / "Pertamax" / "Pertamax Turbo" / "Dexlite" / "Pertamina Dex"
     -> match by name di brand=pertamina
   - "Shell Super" / "Shell V-Power" / "V-Power Diesel"
     -> match by name di brand=shell
   - Untuk struk Pertamina yang cuma tulis "PRT" / "PMX" / "PXT", inferensi:
     PRT/Pertalite, PMX/Pertamax, PXT/Pertamax Turbo, DXL/Dexlite, PDX/Pertamina Dex.

5. vehicle_id = pilih dari KENDARAAN USER di atas.
   - Struk SPBU biasanya TIDAK menyebut kendaraan. Pakai HEURISTIK:
     - Jika user cuma punya 1 kendaraan -> pakai itu.
     - Jika user punya motor + mobil:
       * BBM type motor (Pertalite, Pertamax) + total kecil (<Rp 100.000) -> motor
       * BBM diesel (Dexlite, Pertamina Dex, V-Power Diesel) -> mobil
       * Total besar (>Rp 200.000) atau liter banyak (>10L) -> mobil
       * Default -> mobil (mobil lebih sering di SPBU formal)
   - JANGAN bikin id baru. WAJIB pilih dari list user.

6. refuel_date = tanggal di struk dalam format YYYY-MM-DD.
   - Format umum: "12/03/2024", "12-03-2024", "12 Mar 2024".
   - Jika tidak terbaca, pakai ${today}.

7. odometer_km = pembacaan spidometer kalau ada di struk (jarang).
   - Default null kalau tidak terlihat.

8. is_full_tank = true kalau struk menunjukkan tanki penuh.
   - Heuristik: jika liters >= 95% kapasitas tanki kendaraan terpilih -> true.
   - Default false.

9. confidence:
   - "high" jika total + harga/liter + nama BBM terbaca jelas
   - "medium" jika ada 1 field yang ditebak
   - "low" jika foto buram / sebagian terpotong / banyak tebakan

10. reasoning: 1 kalimat singkat Bahasa Indonesia menjelaskan apa yang kamu baca.

ATURAN OUTPUT:
- vehicle_id WAJIB dari list KENDARAAN USER (UUID, persis).
- fuel_product_id WAJIB dari list JENIS BBM (UUID, persis).
- total_rp, price_per_liter HARUS angka rupiah utuh (integer).
- liters BOLEH decimal (max 3 angka di belakang koma).

Selain "refuel", balas juga "transcript": 1 kalimat ringkas (maks 100 karakter)
yang menggambarkan struk, mis: "Pertamax 12.5L Rp 162.500 di SPBU Sudirman".

FORMAT OUTPUT (WAJIB):
Balas HANYA satu objek JSON valid:
{ "refuel": { ...field di atas... }, "transcript": "..." }
Tanpa markdown, tanpa backticks.

Jika foto BUKAN struk SPBU / tidak bisa dibaca / kosong, balas:
{ "refuel": null, "transcript": "Foto tidak terbaca sebagai struk SPBU." }`;
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

  let payload: { image_base64?: string; mime?: string };
  try {
    payload = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }

  const imageBase64 = (payload.image_base64 ?? "").trim();
  const mime = (payload.mime ?? "image/jpeg").toLowerCase();

  if (!imageBase64) {
    return jsonResponse({ error: "empty_image" }, 400);
  }
  if (imageBase64.length > MAX_BASE64_BYTES) {
    return jsonResponse({ error: "image_too_large" }, 413);
  }
  if (!ALLOWED_MIMES.has(mime)) {
    return jsonResponse({ error: "unsupported_mime", detail: mime }, 400);
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

  // 2. Call LLM vision with structured output.
  const today = todayJakarta();
  const systemPrompt = buildSystemPrompt(vehicles, fuelProducts, today);
  const dataUrl = `data:${mime};base64,${imageBase64}`;

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
        {
          role: "user",
          content: [
            {
              type: "text",
              text:
                "Baca struk SPBU berikut dan ubah jadi JSON sesuai instruksi sistem.",
            },
            {
              type: "image_url",
              image_url: { url: dataUrl, detail: "high" },
            },
          ],
        },
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

  const transcript =
    typeof parsed?.transcript === "string"
      ? parsed.transcript.trim().slice(0, 200)
      : "";

  const item = parsed?.refuel;
  if (!item || typeof item !== "object") {
    return jsonResponse(
      {
        error: "no_refuel_parsed",
        detail: transcript || "Struk tidak terbaca.",
        raw,
      },
      422,
    );
  }

  // 3. Validate + force onto a known shape.
  let vehicle = vehicles.find((v) => v.id === item.vehicle_id);
  if (!vehicle) vehicle = vehicles[0];

  let fuel = fuelProducts.find((f) => f.id === item.fuel_product_id);
  if (!fuel) {
    if (typeof item.fuel_product_name === "string") {
      const target = item.fuel_product_name.toLowerCase().trim();
      fuel = fuelProducts.find((f) => f.name.toLowerCase() === target);
    }
  }
  if (!fuel) fuel = fuelProducts[0];

  const totalRp = Math.max(0, Math.round(Number(item.total_rp) || 0));
  const pricePerLiter = Math.max(
    0,
    Math.round(Number(item.price_per_liter) || 0),
  );
  let liters = Number(item.liters);
  if (!Number.isFinite(liters) || liters <= 0) {
    liters = pricePerLiter > 0 ? totalRp / pricePerLiter : 0;
  }
  liters = Math.round(liters * 1000) / 1000;

  const odometerKm =
    item.odometer_km == null
      ? null
      : Math.max(0, Number(item.odometer_km) || 0);

  const date = /^\d{4}-\d{2}-\d{2}$/.test(item.refuel_date ?? "")
    ? item.refuel_date
    : today;

  const tankCap = vehicle.tank_capacity_liters;
  const isFullTank =
    typeof item.is_full_tank === "boolean"
      ? item.is_full_tank
      : tankCap != null && liters > 0
        ? liters / tankCap >= 0.95
        : false;

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
