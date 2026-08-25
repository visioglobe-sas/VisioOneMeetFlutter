# Camera Lock on Position

## Description

Locks the camera's focus on the currently tracked position (see `simulated-position`), like a "recenter on my position" toggle in a GPS app, via `view.lockCameraPositionOnTracking` (a boolean property).

This feature depends directly on `simulated-position`: locking the camera onto a position that never moves wouldn't demonstrate anything, so it only makes sense combined with a running tracked-position feed.

`lockCameraPositionOnTracking` has a sibling, `lockCameraOrientationOnTracking` (also locks the camera's *orientation*, based on the device's orientation sensor data) — not covered here, which only demonstrates the *position* lock.

## SDK usage

```js
// window.MapBridge, JS side (assets/www/map.html)
setCameraLockOnPosition: function (locked) {
  if (!view) return;
  view.lockCameraPositionOnTracking = !!locked;
},
```

```dart
// lib/visio_one/visio_one_controller.dart
Future<void> setCameraLockOnPosition(bool locked) =>
    _call('setCameraLockOnPosition', [locked]);
```

## Things to know

- **`lockCameraPositionOnTracking` only has an effect if `allowTracking` is already `true`.** Per the SDK's `View.ts` comment: *"Set it to true to bind camera focus on tracking position. This won't have any effect if flag 'allowTracking' isn't set to true."* Unlike `injectTrackedPosition`, which throws if `allowTracking` is still `false` (see `simulated-position`), this one is a silent no-op, not an error — worth checking `allowTracking` state if the lock appears to do nothing.
- **No dedicated method to query the current lock state** — `lockCameraPositionOnTracking` is a plain boolean property on `view`, set and (if needed) read back directly; there's no getter/setter pair or change event for it.
- **`lockCameraOrientationOnTracking` is a separate, unrelated property** — enabling position lock does not enable orientation lock, and vice versa. An orientation-lock demo would additionally need a device orientation sensor feed, which this bridge doesn't provide.

## Learn more

- See `simulated-position`: a direct prerequisite for this feature, in particular for `injectTrackedPosition`/`allowTracking`.
- See `docs/COMMUNICATION_GUIDE.md` in this repo (section 3) for the `setCameraLockOnPosition` entry in the Native -> JS table.
