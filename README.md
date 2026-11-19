# LibreGeoTag

Give your photographs a place and a story.

LibreGeoTag turns a photo into a location memory: it attaches a place, an
optional note, and a date, and renders a new image in one of two templates.
The original photograph is never modified.

Local-first by design — no account, no backend, no analytics, and photographs
never leave the device. Only coordinates are sent, and only to look up an
address.

## Status

Early development, but the whole path works: choose a photograph, give it a
place, a note, and a date, pick a template, then save it to your gallery or share
it. iOS is built on CI and has not been run on a device yet.

## Requirements

- Flutter 3.50.0 (stable) / Dart 3.14
- Android SDK with platform 36 and an emulator or device (Android 7.0+)
- For iOS builds: macOS with Xcode 16+, or the macOS CI workflow
- JDK 17 or newer

## Running

```sh
flutter pub get
flutter run
```

Checks:

```sh
flutter analyze
flutter test
```

## Project layout

```
lib/
  app.dart                  # MaterialApp, theme
  app_info.dart             # version string, checked against pubspec by a test
  screens/                  # UI only
  services/                 # photo picking, EXIF, location, geocoding, gallery, sharing
  export/                   # encoding a finished image, file naming
  rendering/                # template painters and image composition
  models/                   # plain data classes
test/                       # business logic and widget tests
docs/                       # the GitHub Pages site: privacy policy and landing page
```

UI is kept separate from metadata, geocoding, and image-generation logic. There
is deliberately no state-management framework, database, or service layer
beyond what a feature needs.

## Dependencies

| Package | Why |
|---|---|
| `image_picker` | Camera capture and gallery selection through the system picker |
| `native_exif` | Reading the capture date and GPS from the original file, on device |
| `geolocator` | A single foreground location fix, only on request |
| `http` | Talking to the geocoding provider |
| `image` | JPEG encoding in pure Dart, so rendering and encoding stay testable |
| `gal` | Saving a finished image to the system photo gallery |
| `share_plus` | The system share sheet |
| `material_ui` | Material 3 widgets (`flutter/material.dart` is deprecated in 3.47+) |

There is no analytics, crash-reporting, advertising, or database package.

## Reverse geocoding and attribution

Coordinates are converted to an address with [Photon](https://photon.komoot.io/),
which uses OpenStreetMap data. The provider sits behind a small interface so it
can be swapped without touching the UI.

The address is only looked up when you ask for it, and only the coordinates are
sent. The result can be narrowed to a city, a region, or just the country, part
by part, and the final text can always be edited by hand — including when there
is no connection at all.

Address data is © OpenStreetMap contributors, available under the
[Open Database License](https://www.openstreetmap.org/copyright). Attribution is
shown in the app — under the address field, and on the About screen, together
with the app version, the licence, and the open-source licences of every
dependency.

The public Nominatim endpoint is **not** used: its usage policy requires a proxy,
caching, and the ability to switch providers without an app update.

## Templates

**Overlay** fills the frame with the photograph and sets the place, the note,
and the date in the lower left over a soft dark gradient, so light text stays
readable on any picture.

**Postcard** prints the photograph on a warm paper card with the caption in the
margin beneath it.

Coordinates are printed in place of an address only when no address was given,
so a memory is never left completely unlabelled.

Both are drawn by one function (`lib/rendering/memory_renderer.dart`) that the
preview and the export share, with every measurement expressed as a fraction of
the canvas width. The preview is therefore the same image at a smaller size, not
an approximation of it. Colours are fixed rather than taken from the app theme,
so a dark-mode phone does not produce a dark image.

Type is set in the system font — Roboto on Android, SF on iOS — so the same
memory exported on two platforms can differ slightly in letter shapes. Bundling
a font would fix that at the cost of a larger download; it is deferred.

## Saving and sharing

The exported image is painted by the same function as the preview, at the
photograph's own pixel size unless a smaller size is chosen. Nothing is
upscaled and nothing is cropped.

- **JPEG** for smaller files, at quality 80, 90, or 100.
- **PNG** for lossless output, larger files.
- **Original**, **Large** (longest edge 4096 px), or **Small** (2048 px). A
  photograph already below the cap keeps its own size. Downscaling happens
  before painting, so it also caps the memory the render needs — a 48 MP
  photograph otherwise needs about 190 MB of pixels before encoding starts.

The file is named after the photograph's capture date
(`libregeotag-2023-07-15-1423.jpg`), so it sorts next to the picture it came
from. Saving puts it in a `LibreGeoTag` album in the device gallery; sharing
hands the same bytes to the system share sheet. The original photograph is only
ever read.

Encoding a large JPEG runs off the UI isolate, so the app stays responsive; a
full-size 12 MP export takes a moment.

## Releasing

Play accepts an Android App Bundle, not an APK:

```sh
flutter build appbundle --release
```

The bundle is written to `build/app/outputs/bundle/release/app-release.aab`.

Release builds are signed with your upload key when `android/key.properties`
exists, and with the debug key when it does not, so a fresh clone still builds
and only the file you upload needs the real key. To set one up, copy
`android/key.properties.example` to `android/key.properties` and follow the
comments in it. Both that file and the keystore itself are ignored by git.

The version comes from `pubspec.yaml` — `version: 0.1.0+1` is the version name
and the build number. Play requires the build number to increase with every
upload.

The privacy policy the listing links to lives in `docs/`, served by GitHub
Pages. Enable it once under **Settings → Pages → Deploy from a branch → main →
/docs**; the site is then at `https://wichosu.github.io/libregeotag/`.

Two things still need doing before a first upload: the launcher icon is still
Flutter's default (`android/app/src/main/res/mipmap-*/ic_launcher.png`), and the
store listing needs screenshots, a feature graphic, and the Data safety form.

## Privacy

- Location permission is requested only when a location is needed.
- There is no background location access and no location history.
- EXIF metadata is read on device.
- Address lookups send only the coordinates, over HTTPS, and the answer is kept
  in the editor until the location changes.
- Generated images are written to the gallery only when you ask for it, and
  contain only the place, note, and date you chose.
- Sharing goes through the system share sheet. The app itself uploads nothing.

## License

Application source code: MIT — see [LICENSE](LICENSE).

OpenStreetMap data is licensed separately under the ODbL. Map data licensing is
independent of this project's source-code license.
