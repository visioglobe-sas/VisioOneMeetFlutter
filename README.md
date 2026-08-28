# VisioOne Meet Flutter

A minimal Flutter app that displays an interactive [VisioOne](https://www.npmjs.com/package/@visioglobe/visioone) indoor map full-screen inside a `WebView`, and demonstrates how to drive the SDK from native Dart code through a JS bridge.

This project is one of a series of integration examples for the VisioOne SDK across different platforms (native Android, native iOS, React Native, Flutter).

## Setup

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel) and a configured Android/iOS toolchain.
- A connected device or a running emulator/simulator (`flutter devices` to list available targets).

### Install dependencies

```bash
flutter pub get
```

### Configure your own map

The app ships pointed at a demo map. To point it at your own map:

1. Get your map's hash (a 41-character identifier) from [my.visioglobe.com](https://my.visioglobe.com) (see `docs/INTEGRATION_GUIDE.md`, part D, for the detailed steps).
2. Replace the value of `kDefaultMapHash` in `lib/visio_one/visio_one_map_shell.dart`:

   ```dart
   const String kDefaultMapHash = 'YOUR_HASH_HERE';
   ```

### Run

```bash
flutter run                 # connected device/emulator
flutter run -d <device-id>  # a specific target (see `flutter devices`)
```

### Refresh the vendored SDK bundle

The app vendors a prebuilt build of the SDK (`assets/www/visioone.umd.cjs`) rather than depending on it through a JS bundler. To update it to a newer `@visioglobe/visioone` release:

```bash
npm pack @visioglobe/visioone          # or @visioglobe/visioone@<version> to pin
tar xzf visioglobe-visioone-*.tgz
cp package/dist/visioone.umd.cjs assets/www/visioone.umd.cjs
rm -rf package visioglobe-visioone-*.tgz
```

No Dart code changes are needed for a minor SDK bump — only if the bundle's public surface (`window.MapBridge` calls, `view` events) changes, which would also require editing `assets/www/map.html`.

## Features

Each item below links to a dedicated doc describing the SDK call it demonstrates:

- **[Reset view](docs/features/reset-view.md)** — recenters the camera on the whole venue.
- **[Occupancy (simulated)](docs/features/occupancy-simulated.md)** — colors a POI's surface to reflect a simulated occupancy status (free / soon occupied / occupied).
- **[POI click](docs/features/poi-click.md)** — reacts to a tap on a POI on the map by surfacing its name and ID.
- **[Go to POI](docs/features/goto-poi.md)** — centers the camera on a POI given its ID and selects it visually.
- **[Floor selector](docs/features/floor-selector.md)** — lets the host app switch building/floor from its own native UI, kept in sync with the SDK's built-in floor selector.
- **[Compute navigation](docs/features/compute-navigation.md)** — computes and displays a route between two POIs.
- **[UI part visibility](docs/features/ui-part-visibility.md)** — shows or hides individual parts of the SDK's built-in overlay UI.
- **[Simulated position](docs/features/simulated-position.md)** — animates a simulated tracked position back and forth between two POIs.
- **[Camera lock on position](docs/features/camera-lock-on-position.md)** — locks the camera focus on the tracked position set up by "Simulated position".
- **[Clickable surface](docs/features/clickable-surface.md)** — makes a place's surface interactive, with the SDK handling hover/tap color feedback itself; the base building block for "availability" use cases.
- **[Custom data](docs/features/custom-data.md)** — reads free-form business data (price, opening hours, product reference) attached to a POI in VisioMapEditor.
- **[Category highlight](docs/features/category-highlight.md)** — highlights every POI belonging to a chosen category (e.g. all restaurants, all shops) in one action.
- **[Dynamic POI CRUD](docs/features/dynamic-poi-crud.md)** — creates, updates, and removes a POI at runtime, without republishing the map.
- **[Runtime locale](docs/features/runtime-locale.md)** — switches the language of POI names and labels on the map at runtime, without reloading it.
- **[Native UI replacement](docs/features/native-ui-replacement.md)** — hides the SDK's built-in floor selector and shows the app's own native one as a complete, fully-functional replacement.
- **[Explore mode](docs/features/explore-mode.md)** — switches between the global, building "carousel", and floor camera-exploration modes.
- **[Add locale](docs/features/add-locale.md)** — adds a brand-new locale at runtime, never authored in VisioMapEditor for this map.
- **[Geofencing](docs/features/geofencing.md)** — triggers a visual alert when a simulated tracked position enters a zone on the map.

## How it works

The VisioOne SDK (`@visioglobe/visioone` on npm) is a **JS/WebGL** SDK — there is no native Dart port. The app embeds it as:

- the SDK's **UMD** bundle (`assets/www/visioone.umd.cjs`, vendored from npm — see "Refresh the vendored SDK bundle" above to update it),
- a host page (`assets/www/map.html`) that loads that bundle via a classic `<script>` tag and exposes a JS bridge (`window.MapBridge`),
- displayed full-screen in a `WebView` via the [`webview_flutter`](https://pub.dev/packages/webview_flutter) package.

The **UMD** build is used deliberately, instead of the ESM build (`visioone.js`) — the same lesson learned on other native integrations of the VisioOne SDK (see `docs/ARCHITECTURE.md`): a module's dynamic `import()` calls fail under WebKit's `file://` CORS restrictions, while a classic `<script>` tag works identically whether the WebView serves the page over `file://` (iOS) or an internal origin (Android, via `loadFlutterAsset`).

Native code talks to the SDK through a bidirectional bridge:

| Direction | Mechanism | Details |
|---|---|---|
| Native → JS | `WebViewController.runJavaScript()` calling `window.MapBridge.<method>(...)` | [`lib/visio_one/visio_one_controller.dart`](lib/visio_one/visio_one_controller.dart) |
| JS → Native | a single `JavaScriptChannel` (`VisioOneBridge`), envelope `{type, data}` | [`lib/visio_one/visio_one_message.dart`](lib/visio_one/visio_one_message.dart) |

See [`docs/COMMUNICATION_GUIDE.md`](docs/COMMUNICATION_GUIDE.md) for the full bridge contract and [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the overall picture.

## Repo structure

```
lib/
  main.dart                          entry point, MaterialApp
  features/
    feature.dart                     catalogue of demonstrated features (slug, title, overlay)
    feature_menu_screen.dart         home screen listing all features
    feature_screen.dart              full-screen host for one feature's map + overlay
    <feature>_overlay.dart           per-feature UI control shown in the bottom sheet
  visio_one/
    visio_one_map_shell.dart         shared map screen: loads the SDK, kDefaultMapHash, loading/ready/error states
    visio_one_controller.dart        typed Native <-> WebView/SDK bridge
    visio_one_message.dart           JSON envelope for the JS -> Native channel
    simulated_position_session.dart  state for the simulated tracked-position demo
assets/www/
  map.html                           host page + window.MapBridge (JS side of the bridge)
  visioone.umd.cjs                   vendored VisioOne SDK (UMD build, from npm)
docs/
  ARCHITECTURE.md                    why UMD, asset-loading diagram, full lifecycle sequence
  COMMUNICATION_GUIDE.md             full bridge contract, threading, security, debugging
  INTEGRATION_GUIDE.md               non-Dart-developer walkthrough (install, configure, ship)
  features/                          one doc per demonstrated feature, SDK usage focused
```
