# Custom theme

## Description

White-label styling beyond the defaults, applied live with no reload:

- **3D scene theme**: `view.themes` (read-only list of registered theme ids — `['day', 'night', 'goldenHour']` as of SDK 1.1.0) and `view.setTheme(name)`, which changes the lighting of the 3D scene.
- **UI accent colors**: `view.accentColor` and `view.textAccentColor`, two settable properties that recolor the SDK's own UI buttons (the POI card's "Go" button, "Add a step", "Remove step"…).

The SDK public API (as of 1.1.0) has no font option.

## SDK usage

### Creating the view with lights enabled

Themes only change the scene lights, and lights are only rendered when the view is created with `enableShadows: true` (`ViewCreateOptions`). The option is passed as the third argument of `createView`:

```dart
// lib/visio_one/visio_one_controller.dart
// viewOptions is forwarded as-is to createView; null = SDK defaults.
Future<void> setup(String hash, {String? baseURL, Map<String, Object>? viewOptions}) =>
    _call('setup', [hash, baseURL, viewOptions]);

// The custom-theme screen:
controller.setup(hash, viewOptions: {'enableShadows': true});
```

```js
// window.MapBridge, JS side (assets/www/map.html)
setup: function (hash, baseURL, viewOptions) {
  // ...
  visioOne.loadVenue({ vg_maphash: hash }, container)
    .then(function (v) {
      venue = v;
      return viewOptions
        ? visioOne.createView(container, venue, viewOptions)  // { enableShadows: true }
        : visioOne.createView(container, venue);
    })
    // ...
},
```

### Theme

```dart
// lib/visio_one/visio_one_controller.dart
// Response: message `themesLoaded` {requestId, themes: ['day', 'night', 'goldenHour']}
Future<void> getThemes(String requestId) => _call('getThemes', [requestId]);

// Response: message `themeApplied` {success, theme, message?}
Future<void> setTheme(String name) => _call('setTheme', [name]);
```

```js
// window.MapBridge, JS side (assets/www/map.html)
getThemes: function (requestId) {
  sendToNative('themesLoaded', { requestId: requestId, themes: view ? view.themes.slice() : [] });
},

setTheme: function (name) {
  try {
    view.setTheme(name);
    sendToNative('themeApplied', { success: true, theme: name });
  } catch (error) {
    // "Cannot apply given theme <name> as it isn't registered."
    sendToNative('themeApplied', { success: false, theme: name, message: error.message });
  }
},
```

The demo builds its theme choices from `view.themes` at runtime and shows the raw SDK ids.

### Accent colors

```dart
// lib/visio_one/visio_one_controller.dart
// Response: message `accentColorsApplied` {success, message?}
Future<void> setAccentColors({required String accent, required String textAccent}) =>
    _call('setAccentColors', [accent, textAccent]);

controller.setAccentColors(accent: '#E53935', textAccent: '#FFEB3B');
```

```js
// window.MapBridge, JS side (assets/www/map.html)
setAccentColors: function (accentColor, textAccentColor) {
  try {
    view.accentColor = accentColor;          // background of accent buttons
    view.textAccentColor = textAccentColor;  // text/icon color on them
    sendToNative('accentColorsApplied', { success: true });
  } catch (error) {
    // "Invalid color format provided, it should be hex color, rgba color or hsl color."
    sendToNative('accentColorsApplied', { success: false, message: error.message });
  }
},
```

The real SDK surface, from the SDK's typings (`View.d.ts`, `ViewCreateOptions`):

```ts
interface View {
  accentColor: Color;          // default '#0094f0'
  textAccentColor: Color;      // default '#ffffff'
  readonly themes: string[];
  setTheme(themeName: string): void;
}

interface ViewCreateOptions {
  // "Set this parameter to true to enable shadows and lights rendering.
  //  Shadows are computationally expensive and may hurt performance."
  readonly enableShadows?: boolean;
}
```

## Things to know

- **`setTheme` does nothing visible without `enableShadows: true`.** A theme only changes the 3D scene lighting (the color and position of the directional and ambient lights). It never changes the UI. If the view was created without `enableShadows`, every theme renders exactly the same pixels, even at quality `high`. With it, `night` is bluish and darker and `goldenHour` is warm and muted. `enableShadows` can only be set at `createView` time, so turning it on means recreating the view.
- **`enableShadows` costs performance**: the SDK documents shadows as "computationally expensive". Only turn it on for the screens or apps that need themes. The SDK also ignores it when the view's quality preset is `low` (shadows are only allowed at `medium` and `high`), so on low-quality devices themes stay invisible too.
- **Not visible in the iOS Simulator.** On the iOS 18.1 Simulator (both in this app's `WKWebView` and in Mobile Safari, quality tier `medium`, `enableShadows: true`), every theme rendered exactly the same pixels, even after moving the camera. This was observed on the iOS Simulator only: themes work in desktop Chromium and WebKit, and are unverified on a physical iOS device.
- **Only pass ids from `view.themes`.** `setTheme('unknown')` throws `Cannot apply given theme unknown as it isn't registered.`
- **There is no getter for the current theme** (as of SDK 1.1.0). Track the selected theme on the app side. `day` is the initial theme.
- **Switching back to `day` may not restore the initial look exactly.** In our tests (SDK 1.0.9, Chromium on Apple M1), `setTheme('day')` right after the view loads changed no pixels. After another theme had been applied, though, `setTheme('day')` gave a slightly different render than the initial one (more visible shadows).
- **Accent colors apply live to SDK UI only**: the POI card's "Go" button (background = `accentColor`, text and icon = `textAccentColor`), "Add a step", "Remove step". They do **not** change the color of a selected surface, which is a separate property, `view.surfaceSelectionColor`.
- **An invalid color throws** `Invalid color format provided, it should be hex color, rgba color or hsl color.` Accepted formats are hex, `rgba()` and `hsl()`. In the bridge above, a throw on `accentColor` stops before `textAccentColor` is assigned. A throw on `textAccentColor` leaves the new `accentColor` applied.

## Learn more

- Both accent colors can also be set at load time with the `accentColor` / `textAccentColor` URL parameters, which the SDK reads from the page URL (`URLParameters`).
- [Clickable surface](clickable-surface.md) covers surface colors (`hoverColor` / `selectionColor`), which accent colors don't affect.
