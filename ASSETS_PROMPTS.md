# BensinKu — Asset Generation Prompts

Daftar prompt siap pakai untuk image-gen (Codex / GPT-Image / Midjourney). Semua asset harus konsisten dengan editorial theme app: **cream paper canvas + butter yellow accent + near-black ink**, dengan vibe **service manual / fuel-pump LCD / paper logbook** (utilitarian, BUKAN editorial-magazine yang fancy).

> Drop hasilnya ke folder yang sesuai di `assets/`. Setelah selesai, tidak perlu update `pubspec.yaml` — folder `assets/illustrations/` dan `assets/vehicles/` sudah didaftarkan, jadi cukup taruh file dengan nama yang sesuai.

---

## 0. Style Bible (paste this before every prompt)

```
STYLE BIBLE — BensinKu editorial fuel logbook
- Palette (strict, no other colors):
  - Canvas:      #F6EFDF  (cream paper background)
  - Cream:       #FFF7E6  (slightly lighter paper)
  - Butter:      #E9B341  (primary accent — warm yellow)
  - ButterDeep:  #B6841C  (darker yellow, secondary accent)
  - ButterSoft:  #F6DC9F  (tonal yellow, fills/tints)
  - Ink:         #1A0F03  (near-black, primary text/lines)
  - InkSoft:     #4A3A20  (warm dark gray, secondary text)
  - Hairline:    #D9CCAC  (faint divider lines)
  - Optional accents (use sparingly): Rust #A8391A, Sage #5C7042
- Mood: paper / risograph / 1970s service manual / fuel-pump LCD / mechanical
  diagram / Japanese parts catalog. Calm, utilitarian, slightly nostalgic.
- Lines: hairline-thin, ink black. Crisp, vector-like edges. NO soft glows,
  NO drop shadows, NO photorealism, NO gradients except the optional flat
  butter→butterSoft tint.
- Texture: subtle paper grain OK, but keep it faint. No heavy noise.
- Typography (only if text appears): IBM Plex Mono, uppercase, tracked.
  No script, no italic, no calligraphy.
- Composition: flat, geometric, off-center / asymmetric grid. Lots of
  whitespace (cream canvas around the subject).
- Forbidden: glossy 3D renders, neon, anime/cartoon kawaii, generic stock
  illustration look, gradients beyond the cream→butter spectrum, photo
  realism, faces, mascots, hands.
```

---

## 1. App Launcher Icon

**File**: `assets/icon.png`
**Size**: 1024×1024 px, square, PNG with full opacity (no transparent bg).

```
[paste STYLE BIBLE]

Generate a 1024x1024 square app icon for "BensinKu", an Indonesian fuel
tracker app.

Subject: a bold, simplified emblem of a fuel droplet OR a vintage fuel-pump
nozzle silhouette. Solid butter (#E9B341) shape on a cream (#F6EFDF) field,
or vice versa. Add a single thin ink hairline border around the subject for
that engraved/letterpress look.

The icon should read clearly at 24x24 px (Android adaptive icon). Subject
must occupy ~70% of the frame, centered. Solid fills only — no gradients,
no shadows, no 3D. Crisp vector edges.

Optional micro-detail: a tiny "BK" monogram in IBM Plex Mono uppercase tucked
into negative space, ink black, ~5% of the canvas. Skip if it makes the icon
look noisy.
```

---

## 2. Vehicle Default Covers

These are fallback images shown in the garasi cards when the user hasn't
uploaded a real vehicle photo. Resolved by `lib/services/vehicle_assets.dart`.

### 2a. Motor (motorcycle) default

**File**: `assets/vehicles/motor-default.jpg`
**Size**: 1200×900 px (4:3), JPG quality 85+.

```
[paste STYLE BIBLE]

Generate a 1200x900 illustration of a generic side-profile motorcycle
silhouette in editorial / service-manual style. Strict palette only.

Composition:
- Cream paper background (#F6EFDF), full bleed.
- Motorcycle drawn in solid ink (#1A0F03) silhouette, no detail painting,
  occupying ~60% width, centered slightly toward the bottom-third.
- Faint butter-soft (#F6DC9F) horizontal band behind the bike, like a
  paper highlight strip, hairline ink rules above and below it.
- Tiny ink callout label "MOTOR · 01" in IBM Plex Mono uppercase, 14pt
  equivalent, top-left corner, with a 1px ink leader line pointing to the
  bike. Optional, skip if it crowds the frame.
- Subtle paper grain across the canvas (very faint).

The bike should be a generic naked / standard street bike — no logos, no
brand cues, no rider, no plate. Crisp hairline contour.
```

### 2b. Mobil (car) default

**File**: `assets/vehicles/mobil-default.jpg`
**Size**: 1200×900 px (4:3).

```
[paste STYLE BIBLE]

Generate a 1200x900 illustration of a generic side-profile compact sedan /
hatchback silhouette in editorial / service-manual style. Same treatment as
the motor counterpart so they look like a matched set.

Composition:
- Cream paper background (#F6EFDF), full bleed.
- Car silhouette in solid ink, no logo, no driver visible through windows,
  no plate text, occupying ~60% width, centered slightly low.
- Faint butter-soft horizontal band behind the car like a paper highlight,
  with 1px hairline rules.
- Tiny ink callout label "MOBIL · 02" in IBM Plex Mono uppercase, optional.
- Faint paper grain.

The car should read as a generic family sedan/hatchback — no brand, no
chrome, no decals. Crisp vector edges.
```

> Tips: minta image-gen untuk render keduanya **dalam satu batch** dengan prompt
> yang persis sama kecuali subject (motor vs mobil) supaya angle, weight, dan
> grain match.

---

## 3. Empty-State Illustrations

Dipakai ketika user belum punya kendaraan, belum ada catatan pengisian, atau
belum ada trip. Saat ini app pakai teks polos doang — illustration ini akan
bikin empty state lebih hangat.

### 3a. Garasi kosong

**File**: `assets/illustrations/empty_garasi.png`
**Size**: 800×600 px, PNG with transparent background.

```
[paste STYLE BIBLE]

Generate an 800x600 illustration of an empty garage / parking bay drawn in
editorial line-art style. Transparent background.

Composition:
- A simple geometric garage outline (rectangular bay with a roll-up door
  or simple opening), drawn in 1.5px ink hairlines only, no fill.
- Inside the bay: empty floor with two faint butter dashed parking lines
  forming an empty parking slot — emphasize the "nothing parked here yet"
  feel.
- Above the bay, a small sign tile in solid butter with the ink mono text
  "GARASI" centered (IBM Plex Mono uppercase, tracked).
- Optional: a tiny puff of dust or a single fallen wrench in ink hairline,
  bottom corner, for character. Keep it minimal.

No people, no vehicles inside, no clutter. Lots of whitespace.
```

### 3b. Arsip kosong

**File**: `assets/illustrations/empty_arsip.png`
**Size**: 800×600 px, transparent PNG.

```
[paste STYLE BIBLE]

Generate an 800x600 illustration of an empty paper logbook / receipt stack
in editorial line-art style. Transparent background.

Composition:
- A spiral-bound notebook or receipt-strip rendered in ink hairlines,
  slightly tilted (~5deg counter-clockwise), opened to a blank page.
- The blank page shows pre-printed mono ruling: 4 horizontal hairline rules
  with tiny ink mono labels "TGL", "LITER", "RP", "KENDARAAN" along the
  left margin, all faint.
- Top-right corner of the page: a butter rubber-stamp mark "BELUM ADA
  CATATAN" in IBM Plex Mono uppercase, slightly rotated, ink letterforms
  on butter fill.
- Optional: a ballpoint pen lying diagonally beside the notebook, ink
  hairline, no fill.

Keep the scene calm and uncluttered. Plenty of whitespace.
```

### 3c. Rute kosong

**File**: `assets/illustrations/empty_rute.png`
**Size**: 800×600 px, transparent PNG.

```
[paste STYLE BIBLE]

Generate an 800x600 illustration of an empty road / route map in editorial
line-art style. Transparent background.

Composition:
- A single flowing road drawn as a 2px ink line that curves gently across
  the canvas left-to-right, with two small ink circles marking start and
  end pins. The road is "blank" — no markers, no segments traced, no
  vehicles.
- Faint hairline grid (3x3) behind the road, very subtle (~10% opacity ink),
  evoking a topo map or graph paper.
- A small butter compass rose (~80px) in the top-right corner with the
  letters N E S W in IBM Plex Mono.
- Optional: a small mono callout "BELUM ADA RUTE" in butter-deep ink on a
  cream tag, attached to the road with a hairline leader.

No buildings, no terrain detail, no people.
```

---

## 4. Onboarding Hero Illustrations

Tiga ilustrasi untuk halaman onboarding (Pengenalan / Setup tanki /
Konfirmasi). Saat ini onboarding pages ada di `lib/features/onboarding/`.

### 4a. Onboarding 1 — Pump LCD

**File**: `assets/illustrations/onboarding_pump.png`
**Size**: 1080×800 px, transparent PNG.

```
[paste STYLE BIBLE]

Generate a 1080x800 hero illustration: a vintage fuel-pump display unit
shown in 3/4 perspective, editorial / service-manual style. Transparent
background.

Composition:
- The pump body is a solid butter (#E9B341) rectangular tower, ~60% of the
  frame height, centered.
- A black ink LCD panel mounted on the front shows the digits "12.34" in
  IBM Plex Mono — bold, tracked, large — colored cream so they read like
  an LCD readout.
- Below the LCD, three small ink labels: "LITER", "RP", "PER LITER", each
  with a faint cream readout. Use uppercase IBM Plex Mono.
- A nozzle hose curves down from the pump's right side, ending in a
  hairline-drawn nozzle, ink black, no fill.
- A faint paper-grain butter-soft ground shadow under the pump (NOT a
  realistic drop shadow — a flat geometric strip).
- Hairline ink labels with 1px leaders pointing to "DISPLAY", "NOZZLE",
  "TOWER", positioned around the pump like a parts diagram.

No people, no station background, no logos.
```

### 4b. Onboarding 2 — Tanki Setup

**File**: `assets/illustrations/onboarding_tank.png`
**Size**: 1080×800 px, transparent PNG.

```
[paste STYLE BIBLE]

Generate a 1080x800 hero illustration: a cutaway diagram of a fuel tank,
editorial / service-manual style. Transparent background.

Composition:
- A horizontal cylindrical fuel tank, ~70% width of the frame, centered.
  Outer shape: ink hairline contour. Inner: filled butter (#E9B341) up to
  ~75% level, with a clean horizontal ink line at the fuel surface.
- A small ink float gauge floating on the surface, hairline mechanism going
  up to a circular dial on top of the tank. The dial has tick marks 0/E,
  1/4, 1/2, 3/4, F in IBM Plex Mono.
- Below the tank, a butter-soft band with the mono label "KAPASITAS · 40 L"
  centered, like a caption strip.
- Optional callout leaders pointing to "GAUGE", "FLOAT", "FILL CAP".

Crisp diagram, no perspective tricks, like an exploded-view manual page.
```

### 4c. Onboarding 3 — Logbook / Tracking

**File**: `assets/illustrations/onboarding_logbook.png`
**Size**: 1080×800 px, transparent PNG.

```
[paste STYLE BIBLE]

Generate a 1080x800 hero illustration: an open paper logbook with three
filled fuel-log entries, editorial / service-manual style. Transparent
background.

Composition:
- A spiral-bound paper notebook, slightly tilted, opened wide.
- The visible page is ruled with hairline rows. Three rows are filled in
  with sample data, IBM Plex Mono, ink black:
    01 · 14.05.26 · 8.50 L · Rp 102.000
    02 · 09.05.26 · 7.20 L · Rp  86.500
    03 · 02.05.26 · 9.00 L · Rp 108.000
- A small butter rubber-stamp "TERVERIFIKASI" overlapping the second entry,
  slightly rotated, mono uppercase.
- A ballpoint pen lying horizontally below the logbook, ink hairline.
- Top-left of the page: a small mono header "LOGBOOK · MEI 2026" with a
  hairline rule under it.

Keep the data plausible and tidy. No handwriting style — strictly mono
typeset.
```

---

## 5. Feature Sheet Illustrations

Untuk sheet receipt-scan dan voice-input (`receipt_processing_sheet.dart`,
`voice_input_sheet.dart`).

### 5a. Scanner / receipt processing

**File**: `assets/illustrations/scanner_paper.png`
**Size**: 800×800 px square, transparent PNG.

```
[paste STYLE BIBLE]

Generate an 800x800 illustration of a fuel-pump receipt being scanned,
editorial / service-manual style. Transparent background.

Composition:
- A vertical thermal-printer receipt, slightly curled at the bottom, taking
  up ~50% of the canvas, centered. Ink hairline outline, cream fill.
- Receipt content (legible IBM Plex Mono, ink): a tiny "SPBU 31.123" header
  at the top, then three columns "LITER / RP / PER L" with sample numbers
  filled in. End with "TERIMA KASIH" centered.
- A horizontal butter scan-bar crossing the receipt, with two thin ink
  dashed guide lines above and below it, like an active scan zone.
- Tiny corner crop marks (L-shaped) at the four corners of the scan zone,
  ink black hairline, suggesting a viewfinder.

No phone bezel, no camera body — the scan is implied by the bar + corner
marks.
```

### 5b. Voice waveform

**File**: `assets/illustrations/voice_wave.png`
**Size**: 1080×400 px (wide banner), transparent PNG.

```
[paste STYLE BIBLE]

Generate a 1080x400 wide banner illustration of a stylized voice waveform,
editorial / service-manual style. Transparent background.

Composition:
- A horizontal series of vertical bars representing a waveform, centered
  vertically. Bars have varying heights (highest in the middle, tapering
  to short bars at the edges). All bars are solid butter (#E9B341).
- A thin ink baseline running through the middle, hairline.
- Above the waveform, a single mono caption "MEREKAM · TEKAN UNTUK BERHENTI"
  in IBM Plex Mono uppercase, tracked, ink color, centered.
- Below the waveform, two tiny ink tick marks at -3s, 0s, +3s timestamps,
  IBM Plex Mono, very small.

Strict 2D, vector-clean. No glow, no neon, no animation suggestion.
```

---

## 6. Auth Page Hero

**File**: `assets/illustrations/auth_pump.png`
**Size**: 1080×720 px, transparent PNG.

```
[paste STYLE BIBLE]

Generate a 1080x720 illustration: a wide editorial scene of a small fuel
station pump island under a flat butter sky, service-manual style.
Transparent background.

Composition:
- A single fuel pump (similar style to onboarding_pump.png) on a butter-soft
  ground strip, centered.
- Two thin ink horizontal hairlines above the pump, suggesting a canopy
  edge. No volumetric building.
- A faint cream "moon" or "sun" disc in the upper-left, ~120px diameter,
  hairline outline only.
- One small bird silhouette (hairline) on the canopy line, optional.
- Bottom edge: a thin ink rule with mono caption "STASIUN · BBM · 01" in
  uppercase IBM Plex Mono, very small (~24px equivalent).

Calm dawn vibe, but absolutely flat (no gradient, no rendered atmosphere).
```

---

## 7. Optional — Section Header Ornaments

Kalau mau lebih editorial-feel, bikin satu set ornament tipis dipakai sebagai
deviders di dalam halaman (saat ini pakai dotted leader bawaan).

**File**: `assets/illustrations/ornament_rule.svg`
**Size**: 800×24 px, SVG vector.

```
[paste STYLE BIBLE]

Generate an SVG ornamental rule, 800x24 px, all in ink (#1A0F03):
- Centered: a tiny diamond glyph (~10x10 px) flanked by two thin hairline
  rules extending to the edges.
- Optional: a tiny IBM Plex Mono "§" symbol next to the diamond.

Strictly vector, single color, no fills beyond the diamond. Will be tinted
in code, so keep paths clean and labeled.
```

---

## Generation Workflow

1. Buka image-gen tool (Codex / GPT-Image / Midjourney / Stable Diffusion).
2. Untuk setiap asset di atas: paste **bagian Style Bible** dulu, lalu paste
   prompt spesifiknya. Generate batch 4 variants, pilih yang paling sesuai.
3. Untuk **vehicle defaults** (`motor-default.jpg`, `mobil-default.jpg`),
   generate dalam satu batch dengan prompt yang sama-sama identik kecuali
   subject — supaya tone, grain, dan composition matching.
4. Crop / resize ke dimensi target (most tools auto-export, double-check).
5. Save dengan nama persis seperti yang ditulis di setiap section, ke folder
   yang sudah ada di `assets/`.
6. Setelah semua asset masuk, jalankan:
   ```
   flutter pub get
   flutter run
   ```
   Tidak perlu update `pubspec.yaml` — folder `illustrations/` dan
   `vehicles/` sudah didaftarkan dengan trailing slash, jadi semua file di
   dalamnya auto-include.

## QA Checklist

- [ ] Semua asset palet ketat: butter, ink, cream variants only.
- [ ] Tidak ada photo-realistic rendering, gradient gelap, atau drop shadow.
- [ ] Tidak ada wajah, manusia, atau brand logo.
- [ ] Vehicle defaults render baik di rasio 1:1 (cropped square thumbnail
      di selector) DAN 4:3 (di vehicle detail page).
- [ ] App launcher icon readable di 24px, 48px, dan 192px.
- [ ] Semua text dalam asset pakai IBM Plex Mono uppercase, tidak ada
      script / italic / decorative type.
- [ ] Receipt mock-up text tidak mengandung data PII asli.
