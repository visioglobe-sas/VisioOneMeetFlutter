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

1. Get your map's hash: sign in to [my.visioglobe.com](https://my.visioglobe.com), open your (already built) map and copy its hash, a 41-character identifier such as `kbae8e6c066cca4b02c2afac2bc963a643d87437a`. If you cannot find it, ask your Visioglobe contact for "the build hash of the map".
2. Replace the value of `kDefaultMapHash` in `lib/demo_map.dart`:

   ```dart
   const String kDefaultMapHash = 'YOUR_HASH_HERE';
   ```

3. Every feature screen opens with its fields prefilled with POI ids of the demo map. Replace the ids in the `DemoMap` class of the same `lib/demo_map.dart` file with ids of your own map (default label/badge texts are localized in `lib/l10n/app_*.arb`).

### Run

```bash
flutter run                 # connected device/emulator
flutter run -d <device-id>  # a specific target (see `flutter devices`)
```

The first load can take 20–30 seconds while the device downloads the map data from `mapserver.visioglobe.com`. The UI strings follow the device language (English or French).

### Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Spinner for more than two minutes | No network, or wrong map hash | Check the device's connection, then the hash in `lib/demo_map.dart` |
| "Could not load the VisioOne map" with a network message | No network, or invalid hash | Same as above; the screen's Retry button reloads the map |
| Black screen, no spinner | `assets/www/map.html`, its scripts or `visioone.umd.cjs` missing from the assets | Check that `pubspec.yaml` lists `assets/www/`, `assets/www/bridge/` and `assets/www/features/`, then `flutter clean && flutter pub get` |
| iOS build fails with a CocoaPods error | Pods not installed or out of date | `cd ios && pod install && cd ..` |
| Android toolchain errors in `flutter doctor` | Missing SDK or licences | `flutter doctor --android-licenses` |

Run `flutter run -v` for a verbose log, and see [`docs/COMMUNICATION_GUIDE.md`](docs/COMMUNICATION_GUIDE.md#9-debugging-the-bridge) to inspect the WebView.

### Refresh the vendored SDK bundle

The app vendors a prebuilt build of the SDK (`assets/www/visioone.umd.cjs`) rather than depending on it through a JS bundler. To update it to a newer `@visioglobe/visioone` release:

```bash
npm pack @visioglobe/visioone          # or @visioglobe/visioone@<version> to pin
tar xzf visioglobe-visioone-*.tgz
cp package/dist/visioone.umd.cjs assets/www/visioone.umd.cjs
rm -rf package visioglobe-visioone-*.tgz
```

The bundle currently vendored is `@visioglobe/visioone@1.1.0`. No Dart code changes are needed for a minor SDK bump — only if the bundle's public surface (`window.MapBridge` calls, `view` events, `loadVenue` options) changes, which would also require editing the JS bridge (`assets/www/bridge/core.js` and the `assets/www/features/*.js` scripts). For example, the map hash is passed to `loadVenue` as `vg_maphash`: a `hash` key, used by older SDK releases, is silently ignored and the map fails to load.

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
- **[Custom map server](docs/features/custom-base-url.md)** — points the SDK at a different map server than the default Visioglobe SaaS.
- **[Custom navigation trace](docs/features/custom-navigation-trace.md)** — restyles the computed itinerary's route line with a custom color preset.
- **[Exclude modalities](docs/features/navigation-exclude-modalities.md)** — computes a route while excluding a segment attribute or modality (e.g. elevator) from the routing graph.
- **[Accessible mode](docs/features/accessible-mode.md)** — computes a route that only uses the venue's accessible route (e.g. avoiding stairs).
- **[3D icon marker](docs/features/3d-icon-marker.md)** — places a custom image (icon) at a spot on the 3D map, with a live-switchable orientation behavior.
- **[Custom text label](docs/features/custom-text-label.md)** — places your own text on the map next to a POI and restyles it live (color, size, rotation).
- **[HTML overlay marker](docs/features/html-overlay-marker.md)** — pins a tappable HTML badge on the map, drawn above the 3D scene, whose taps reach the Dart side.
- **[Custom theme](docs/features/custom-theme.md)** — switches the 3D scene's lighting theme (`view.setTheme`) and recolors the SDK's own UI buttons (`accentColor` / `textAccentColor`) live.
- **[Accuracy circle style](docs/features/accuracy-circle-style.md)** — recolors the tracked position's precision circle (`view.updatePositionTrackerGraphicOptions`) live, on top of "Simulated position".
- **[Camera projection](docs/features/camera-projection-toggle.md)** — switches between a 3D perspective view and a flat orthographic view (`createView`'s `cameraProjection` option, which reloads the map).
- **[Camera showcase](docs/features/camera-showcase-carousel.md)** — automatic camera tour of a list of POIs (`goToFloor` + `goToPOI` with orientation), for kiosks and lobby screens; pauses on touch and resumes after 10 s idle.
- **[Protected map (token)](docs/features/auth-token.md)** — code sample (placeholder values, not run by the demo): loads a map protected by an authorization token (`LoadOptions.authorizationToken`), refreshes it with `venue.setAuthorizationToken`, and reports `UnauthorizedError` distinctly.

## How it works

The VisioOne SDK (`@visioglobe/visioone` on npm) is a **JS/WebGL** SDK — there is no native Dart port. The app embeds it as:

- the SDK's **UMD** bundle (`assets/www/visioone.umd.cjs`, vendored from npm — see "Refresh the vendored SDK bundle" above to update it),
- a host page (`assets/www/map.html`) that loads that bundle, then the JS side of the bridge (`window.MapBridge`) as classic `<script>` tags: `assets/www/bridge/core.js` (map loading, message channel, shared helpers) and one `assets/www/features/<slug>.js` per feature,
- displayed full-screen in a `WebView` via the [`webview_flutter`](https://pub.dev/packages/webview_flutter) package.

The **UMD** build is used deliberately, instead of the ESM build (`visioone.js`) (see `docs/ARCHITECTURE.md`): a module's dynamic `import()` calls fail under WebKit's `file://` CORS restrictions, while a classic `<script>` tag works identically whether the WebView serves the page over `file://` (iOS) or an internal origin (Android, via `loadFlutterAsset`).

Native code talks to the SDK through a bidirectional bridge:

| Direction | Mechanism | Details |
|---|---|---|
| Native → JS | `WebViewController.runJavaScript()` calling `window.MapBridge.<method>(...)` | `send()` / `request()` in [`lib/visio_one/visio_one_controller.dart`](lib/visio_one/visio_one_controller.dart); each feature's commands in `lib/features/<slug>/<feature>_bridge.dart` |
| JS → Native | a single `JavaScriptChannel` (`VisioOneBridge`), envelope `{type, data}` | [`lib/visio_one/visio_one_message.dart`](lib/visio_one/visio_one_message.dart) |

See [`docs/COMMUNICATION_GUIDE.md`](docs/COMMUNICATION_GUIDE.md) for the full bridge contract and [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the overall picture.

## Where is the code of feature X?

Every feature uses the same slug (e.g. `goto-poi`) in three places:

| What | Where |
|---|---|
| The SDK calls (`venue.*`, `view.*`, event listeners) | `assets/www/features/<slug>.js` |
| The Dart commands that call them (`window.MapBridge.<method>`) | `lib/features/<slug>/<feature>_bridge.dart`, an `extension` on `VisioOneController` with the same method names |
| The panel (native UI) and any state that outlives it | `lib/features/<slug>/<feature>_overlay.dart`, plus `<feature>_session.dart` for loops and SDK-state mirrors |
| The developer doc | `docs/features/<slug>.md` |

The menu entry (title, description, map options) is one `FeatureSpec` in `lib/features/feature.dart`. Code shared by several features stays in one place: map loading and the POI position helpers in `assets/www/bridge/core.js`, the bridge core in `lib/visio_one/`, and the From/To form, color chip and error texts in `lib/features/shared/`.

A few features reuse another one's code instead of duplicating it:

| Feature | Reuses |
|---|---|
| `accessible-mode`, `custom-navigation-trace` | `compute-navigation` (`startItinerary`) |
| `camera-lock-on-position`, `geofencing`, `accuracy-circle-style` | `simulated-position` (panel and `SimulatedPositionSession`) |
| `native-ui-replacement` | `floor-selector` (panel) and `ui-part-visibility` (`setUIPartVisible`) |
| `3d-icon-marker`, `custom-text-label`, `html-overlay-marker` | `goto-poi` (`goToPOI`, to show the floor of the placed object) |
| `add-locale` | `runtime-locale` (`setCurrentLocale`) |
| `custom-base-url` | no JS file: the `baseURL` option is handled by `setup` in `assets/www/bridge/core.js` |

To add a feature: create `assets/www/features/<slug>.js` (register its commands with `MapCore.register({...})`) and add its `<script>` tag to `assets/www/map.html`, create `lib/features/<slug>/` with its bridge extension and panel, then add its `FeatureSpec` to `kFeatures`.

## Repo structure

```
lib/
  main.dart                          entry point, MaterialApp
  demo_map.dart                      demo map hash + POI ids used as field defaults (replace with your own)
  l10n/                              UI strings (app_en.arb, app_fr.arb; Dart code generated by `flutter gen-l10n`)
  features/
    feature.dart                     FeatureSpec table: one entry per feature (slug, title, panel, map options, session)
    feature_menu_screen.dart         home screen listing all features
    feature_screen.dart              full-screen host for one feature's map + panel
    <slug>/                          one folder per feature, e.g. goto-poi/:
      <feature>_bridge.dart            its Native -> JS commands (extension on VisioOneController)
      <feature>_overlay.dart           its panel, shown in the bottom sheet
      <feature>_session.dart           (some features) state that outlives the panel: loops, SDK-state mirrors
    shared/                          From/To navigation form, color chip, bridge error texts
  visio_one/
    visio_one_map_shell.dart         shared map screen: loads the SDK, loading/ready/error states, panel
    visio_one_controller.dart        bridge core: WebView, setup(), send(), request(), panel state, session
    visio_one_message.dart           JSON envelope for the JS -> Native channel
    feature_session.dart             base class of per-screen feature sessions
    panel_state.dart                 values typed in a panel, kept while the screen is open
assets/www/
  map.html                           host page: <div> + <script> tags only
  bridge/core.js                     MapBridge.setup, {type, data} channel, shared POI helpers, MapCore registration API
  features/<slug>.js                 one file per feature: its MapBridge commands and view listeners
  visioone.umd.cjs                   vendored VisioOne SDK (UMD build, from npm)
docs/
  ARCHITECTURE.md                    why UMD, asset loading, app structure, lifecycle
  COMMUNICATION_GUIDE.md             full bridge contract, threading, security, debugging
  features/                          one doc per demonstrated feature, SDK usage focused
```
