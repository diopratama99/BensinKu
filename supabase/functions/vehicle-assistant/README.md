# Edge Function: `vehicle-assistant`

Backend AI untuk fitur **Asisten Montir** di app BensinKu. App memanggil
function ini; function memanggil LLM (OpenAI-compatible) memakai API key yang
disimpan sebagai **secret** (key tidak pernah ada di aplikasi).

## 1. Set secret (API key LLM)

Pakai **nama env yang sama** dengan function `parse-fuel-receipt` yang sudah
jalan, supaya providernya konsisten:

```bash
supabase secrets set OPENAI_API_KEY=sk-xxxx
supabase secrets set OPENAI_BASE_URL=https://<provider>/v1
supabase secrets set OPENAI_CHAT_MODEL=<model-id-yang-tersedia-di-provider>
```

> Penting: `OPENAI_CHAT_MODEL` harus model yang BENAR-BENAR ada di
> `OPENAI_BASE_URL` providermu. Kalau salah model → LLM balas error →
> function balas 502.

## 2. Deploy

```bash
supabase functions deploy vehicle-assistant
```

Karena Supabase-mu **self-hosted** (`https://leykopin.temanlabs.tech`),
pastikan:
- Kamu sudah `supabase link` ke project self-hosted itu, atau jalankan
  `supabase functions deploy` dengan `--project-ref`/config yang menunjuk
  ke instance tersebut.
- Container **edge-runtime** (functions) aktif di server self-hosted, dan
  endpoint `/functions/v1/` ter-route. Set juga env (`OPENAI_API_KEY`, dst)
  di environment functions container kalau tidak pakai `supabase secrets`.

## 3. Tes cepat

```bash
curl -X POST 'https://leykopin.temanlabs.tech/functions/v1/vehicle-assistant' \
  -H "Authorization: Bearer <SUPABASE_ANON_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"Kapan ganti oli motor?"}],"vehicle_context":"Motor Honda Vario 125 2020"}'
```

Balasan: `{ "reply": "..." }`.

## Kontrak request/response

Request body:
```json
{
  "messages": [{ "role": "user|assistant", "content": "..." }],
  "vehicle_context": "ringkasan kendaraan pengguna (string)"
}
```
Response:
```json
{ "reply": "jawaban montir" }     // sukses
{ "error": "pesan error" }        // gagal (status != 200)
```
