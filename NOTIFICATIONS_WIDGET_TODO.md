# Notifications & Android Home Widget TODO

Dua fitur, masing-masing punya integration point yang berbeda jadi
dipisah jadi 2 phase.

---

## Phase 1 — Local notifications

Tujuan: kasih notifikasi sistem ketika `TripService` auto-stop trip karena
30 menit idle. User mungkin sudah lupa pencet stop dan app di background;
tanpa notif user gak akan tahu trip sudah ditutup.

### Plan

- [ ] T1.1 Tambah dependency `flutter_local_notifications` ke `pubspec.yaml`
- [ ] T1.2 Bikin `lib/services/notification_service.dart`:
  - `init()` dipanggil di `main.dart` sebelum `runApp`. Setup Android
    + iOS init settings, request permission (Android 13+ butuh
    `POST_NOTIFICATIONS`).
  - `notifyAutoStop({required Trip trip})` — tampilkan notif:
    - Channel: `trip_events` (importance high)
    - Title: "Trip dihentikan otomatis"
    - Body: "X.XX km tercatat. Buka BensinKu untuk lihat detail."
    - Action: tap → buka app (default behavior)
- [ ] T1.3 Wire ke `TripService._performAutoStop`:
  - Setelah `endTrip` sukses + `notifyListeners`, panggil
    `NotificationService.instance.notifyAutoStop(trip: ended)`.
- [ ] T1.4 Android manifest: tambah `POST_NOTIFICATIONS` permission.
- [ ] T1.5 iOS Info.plist: tambah notification entitlement (sudah handled
  oleh plugin biasanya, tapi cek).

---

## Phase 2 — Android home widget (3x2)

Tujuan: widget di home screen Android dengan tombol "MULAI PERJALANAN"
yang bisa langsung start trip tanpa buka app penuh, plus info ringkas.

Layout 3x2 (3 cells wide, 2 cells tall — kira-kira 250–300dp × 130–180dp):

```
┌───────────────────────────────────────┐
│  BENSINKU                  15 MEI 26  │  <- masthead row
│  Selamat sore, Leykopin               │
│                                       │
│  ┌─────────────────────────────────┐  │
│  │  ► MULAI PERJALANAN             │  │  <- butter CTA button
│  └─────────────────────────────────┘  │
│                                       │
│  Mei: Rp 150rb · 5.2 L · 12 km/L      │  <- footer stats
└───────────────────────────────────────┘
```

Constraint Android RemoteViews:
- Cuma widget terbatas: `LinearLayout`, `FrameLayout`, `TextView`,
  `ImageView`, `Button`, `LinearProgressBar` dll. Tidak bisa custom
  view atau Flutter UI di widget.
- Background, color, font weight harus pakai resources (drawable +
  colors.xml). Tidak bisa pakai Material Design 3 dari app.
- Click intent harus `PendingIntent` ke broadcast atau activity.

### Plan

- [ ] T2.1 Tambah dependency `home_widget` ke `pubspec.yaml`.
- [ ] T2.2 Tambah resource files Android:
  - `android/app/src/main/res/values/colors.xml` (atau extend yang
    sudah ada): `widget_canvas` `#F6EFDF`, `widget_butter` `#E9B341`,
    `widget_ink` `#1A0F03`, `widget_ink_soft` `#4A3A20`.
  - `android/app/src/main/res/drawable/widget_bg.xml` — rounded
    rectangle ink-bordered cream background.
  - `android/app/src/main/res/drawable/widget_button_bg.xml` —
    rounded rectangle butter background dengan ink border.
  - `android/app/src/main/res/layout/bensinku_widget.xml` — RemoteViews
    layout sesuai mockup di atas. Pakai IBM Plex Mono kalau bisa
    embed font, atau fallback ke `monospace` typeface.
  - `android/app/src/main/res/xml/bensinku_widget_info.xml` — widget
    metadata: minWidth 250dp, minHeight 110dp, resizeMode horizontal,
    updatePeriodMillis 1800000 (30 min).
- [ ] T2.3 Tambah `AppWidgetProvider` Kotlin class:
  - `android/app/src/main/kotlin/com/temanlabs/bensinku/BensinKuWidgetProvider.kt`
  - `onUpdate()`: build RemoteViews, pull data dari shared
    SharedPreferences (yang `home_widget` plugin pakai), set click
    intents:
    - Tombol MULAI → launch MainActivity dengan extra
      `start_trip_immediately=true`.
    - Background card → launch MainActivity normal.
- [ ] T2.4 Daftar `<receiver>` di `AndroidManifest.xml`:
  ```xml
  <receiver android:name=".BensinKuWidgetProvider" android:exported="false">
    <intent-filter>
      <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
    </intent-filter>
    <meta-data android:name="android.appwidget.provider"
               android:resource="@xml/bensinku_widget_info" />
  </receiver>
  ```
- [ ] T2.5 Bikin `lib/services/home_widget_service.dart`:
  - `updateWidget()` — kumpulkan data (greeting, total bulan ini, km/L
    posterior estimate, last refuel) → push ke `home_widget` plugin
    via `HomeWidget.saveWidgetData<T>(key, value)` → trigger
    `HomeWidget.updateWidget(...)`.
  - Dipanggil pada: app start, setelah refuel saved, setelah trip ended.
- [ ] T2.6 Handle deep-link "start trip immediately":
  - Di `main.dart` cek `getInitialUri()` atau intent extra. Kalau ada
    flag `start_trip_immediately=true`, navigate ke Rute tab + auto
    panggil `_startTrip()`.
  - Atau lebih simpel: pakai pendekatan "navigate ke RUTE tab dengan
    arg auto_start". HomeShell baca arg saat init.

### Out of scope (future)

- iOS home widget — butuh WidgetKit Swift, beda subsystem. Skip dulu.
- Widget ukuran lain (4x1, 2x2). Fokus 3x2 dulu.
- Auto-update widget realtime saat trip aktif (butuh foreground service
  hook ke widget update). Skip dulu.

---

## Phase 3 — Verification

- [ ] T3.1 `flutter analyze --no-pub` → 0 issues.
- [ ] T3.2 Manual smoke:
  - Trip aktif → diamkan 30 menit → notif muncul "Trip dihentikan
    otomatis" dengan suara/vibrate.
  - Tap notif → app open ke Rute tab, summary dialog muncul.
  - Tambah widget BensinKu ke homescreen → tampilan sesuai mockup,
    warna match cream + butter.
  - Tap MULAI di widget → app open di Rute tab, trip langsung start.
  - Tambah refuel di app → widget refresh menampilkan total bulan
    yang baru.
