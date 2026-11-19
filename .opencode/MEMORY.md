# Project memory — LibreGeoTag

Flutter app (Android + iOS) that turns a photo into a location memory image.
Local-first: no backend, no analytics, no accounts, no photo uploads.

## Decisions
- **Geocoding:** Photon public endpoint is the v1 default, behind a `GeocodingProvider`
  interface. Nominatim is only ever used via a configurable self-hosted/proxy base URL —
  its public instance's policy forbids direct use from a shipped mobile app (2026-11-12).
- **OSM attribution:** in-app only ("Data: © OpenStreetMap contributors" + About entry),
  deliberately not on exported images (2026-11-12).
- **Bundle ID:** `io.github.wichosu.libregeotag`. Android `minSdk 24`, iOS deployment target 15.0.
- **State:** one `ChangeNotifier` + `ListenableBuilder`. No state-management package.
- **Rendering:** a single `Canvas` painting function serves both preview and export. All
  sizes are fractions of canvas width so the two are pixel-equivalent. Export renders via
  `PictureRecorder` at the photo's native pixel size; `RepaintBoundary` is never used.
  Template colours are fixed constants, not theme colours, so dark mode cannot darken an
  exported image. Type uses the platform font (Roboto / SF); bundling one is deferred, so
  the same memory can differ slightly between Android and iOS (2026-11-13).
- **JPEG export:** `image` package (pure Dart), chosen over `flutter_image_compress` so
  template rendering stays unit-testable.
- **Export is split by responsibility:** `lib/export/` turns a draft into bytes and names
  the file; `lib/services/gallery_service.dart` and `share_service.dart` own the plugins
  behind interfaces; the editor only orchestrates. JPEG encoding runs in `compute`,
  rendering stays on the main isolate because it needs `dart:ui` (2026-11-19).
- **Export result messages are scoped to their inputs:** the editor stores the draft,
  format, and quality an export was made from and shows the message only while all three
  still match, so editing anything clears a now-wrong "Saved to your gallery."
  Error messages are scoped the same way (2026-11-19).
- **iOS:** unverifiable on this machine (no macOS). GitHub Actions `macos` runner is the
  release path; release is a later milestone, not a blocker for Android work.

## Environment
- Flutter 3.50.0 / Dart 3.14 cloned to `~/flutter`; invoked via `~/flutter/bin/flutter`
  (not on `PATH`, not in `.bashrc`). Android SDK at `~/Android/Sdk`, AVD
  `Medium_Phone_API_36.1`, screen 1080x2400 at density 420. `adb exec-out screencap` now
  returns 1080x2400 too, so tap coordinates map 1:1 — do not assume the older 900x2000
  output and scale by 1.2 (corrected 2026-11-19).
- Emulator storage is tight (~700–850 MB free). A debug APK install fails with
  `INSTALL_FAILED_INSUFFICIENT_STORAGE` unless the app is uninstalled first, which also
  resets the photo-picker grant. The emulator itself has crashed mid-session under this
  pressure; restart with `-no-snapshot-save` and redo the check (2026-11-19).
- Material widgets come from `package:material_ui/material_ui.dart`.
  `package:flutter/material.dart` is deprecated as of Flutter 3.47, and the 3.50 template
  uses `material_ui`. Do not follow tutorials that import `flutter/material.dart`.
- Linux desktop toolchain is incomplete (no clang/GTK) — irrelevant, the project is
  Android/iOS only and is created with `--platforms=android,ios`.

## Location
- **EXIF GPS is preselected in the editor, but a device fix always replaces it** — the
  user tapping "Use my location" is asking about now, not about the moment of capture.
  No location is fetched on editor open; only an explicit tap requests one (2026-11-12).
- **100 m is the "too loose to name a place" threshold** (`LocationFix.poorAccuracyMeters`);
  above it the editor warns that a derived address may be wrong (2026-11-12).
- **Read `getLastKnownPosition` before requesting a fresh fix:** ≤2 min old is used at once
  and labelled "Current location"; on timeout, ≤30 min is used and labelled "Last known
  location"; older is rejected. Waiting for a fresh fix on the emulator costs the full
  20 s timeout (2026-11-12).

## Address
- **Looked up only on an explicit tap**, never when a location is set, so coordinates are
  sent only when the user asks (2026-11-12).
- **The final address text is always editable**, including with no connection. The presets
  (Full / City level / Regional / Country only) and the per-part chips rewrite that text
  when tapped, so a hand edit lasts until a part is changed (2026-11-12).
- **Changing the location clears the address**, manual text included, because it described
  the old coordinates (2026-11-12).
- **Photon is called with an explicit `User-Agent`.** The default Dart agent gets a 403;
  see the global memory entry before changing the client (2026-11-12).

## Constraints found the hard way
- **Widget tests must inject `FakeGallery` (and normally `FakeExporter`).** `gal`'s
  MethodChannel never answers under `flutter_test`, so the save future hangs and
  `pumpAndSettle` fails with a 10 s timeout instead of a useful error. Real encoding works
  in tests only when awaited inside `tester.runAsync` (2026-11-19).
- Android's Photo Picker redacts GPS EXIF, so EXIF GPS is a best-effort fallback only —
  never a promised path. Manual location must always work, including fully offline.
  Verified on API 36: the copy keeps `DateTimeOriginal` but the GPS rationals are zeroed,
  so a picked photo shows its date and no coordinates.
- `dart:ui` cannot encode JPEG. See the global memory entry before changing export code.
- A `Center` inside a max-height box still reports the full max height, so a wide photo
  leaves tall empty bands above and below it. `Align(heightFactor: 1)` sizes the box to the
  child — use it around the preview (2026-11-13).
