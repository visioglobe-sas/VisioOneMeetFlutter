# Accuracy Circle Style

## Description

Recolors the tracked-position marker (the "blue dot") **and** its precision circle at runtime, via `view.updatePositionTrackerGraphicOptions({ color, opacity })`. The circle's size is driven separately, by `precisionCircleRadius` (meters) on each `view.injectTrackedPosition(...)` call.

Like `camera-lock-on-position` and `geofencing`, this feature builds on `simulated-position`: a tracked position animated back and forth between two POIs (here `B4-UL00-ID0009` and `B4-UL00-ID0010` on the shared demo map), re-injected every ~150 ms. On top of it, the demo offers four color presets (SDK default `#0094f0`, red `#e53935`, green `#43a047`, purple `#8e24aa`), an opacity slider (0.1 to 1.0, default 0.3) and the precision radius slider (default 6 m).

## SDK usage

```js
// window.MapBridge, JS side (assets/www/map.html)
updatePositionTrackerGraphicOptions: function (color, opacity) {
  if (!view) return;
  try {
    view.updatePositionTrackerGraphicOptions({ color: color, opacity: opacity });
  } catch (error) {
    console.error('[MapBridge] updatePositionTrackerGraphicOptions failed:', error);
  }
},

// Existing simulated-position entry point, called on every tick:
injectTrackedPosition: function (latitude, longitude, precisionCircleRadius) {
  if (!view) return;
  view.allowTracking = true;
  view.injectTrackedPosition({
    position: { latitude: latitude, longitude: longitude },
    precisionCircleRadius: precisionCircleRadius,
  });
},
```

```dart
// lib/visio_one/visio_one_controller.dart
Future<void> updatePositionTrackerGraphicOptions({
  required String color,
  required double opacity,
}) => _call('updatePositionTrackerGraphicOptions', [color, opacity]);
```

The Dart side calls it whenever the user picks a color or moves the opacity slider, and once more at every start of the simulation, right before the first `injectTrackedPosition` (see "Things to know"):

```dart
// lib/visio_one/simulated_position_session.dart, in start()
if (color != null && opacity != null) {
  _controller.updatePositionTrackerGraphicOptions(color: color, opacity: opacity);
}
_tick(); // -> injectTrackedPosition(...)
```

## Things to know

- **One style for both shapes.** `color` and `opacity` apply to the dot *and* the precision circle together; there is no separate style for each.
- **The options are stored, not applied immediately.** `updatePositionTrackerGraphicOptions` only records the new values; they become visible at the **next** `injectTrackedPosition` call. With a live position feed (here every ~150 ms) it looks instant; with a slow or stopped feed, nothing changes on screen until the next position arrives. Calling it while tracking is off is fine — the values are used at the next injection.
- **The SDK resets the style whenever tracking stops.** Setting `view.allowTracking = false` (the only way to remove the dot/circle from the map) restores the SDK defaults (`#0094f0`, opacity `0.3`). Re-apply your style after every restart, before or together with the first `injectTrackedPosition`. Setting `allowTracking = true` again while it is already `true` does not reset anything.
- **No getter.** The SDK exposes no way to read the current graphic options back; keep the selected color/opacity in your own app state.
- **The radius is not a graphic option.** The circle's size is `precisionCircleRadius` (meters), passed with each `injectTrackedPosition`; omitting it (or passing `0`) draws no circle at all.
- **Validation throws.** An invalid `color` throws (accepted formats: hex such as `#e53935`, `rgba(...)`, `hsl(...)`). A non-number `opacity` throws `"Blue dot's opacity must be a number."`. Note that the opacity check is a falsy test, so `0` slips through without validation — this demo's slider starts at `0.1` for that reason.

## Learn more

- See `simulated-position` for `injectTrackedPosition` / `allowTracking` (prerequisites for this feature).
- See `docs/COMMUNICATION_GUIDE.md` in this repo (section 3) for the `updatePositionTrackerGraphicOptions` entry in the Native -> JS table.
