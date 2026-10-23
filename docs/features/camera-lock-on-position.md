# Camera Lock on Position

## Description

Locks the camera's focus on the currently tracked position (see `simulated-position`), like a "recenter on my position" toggle in a GPS app, via `view.lockCameraPositionOnTracking` (a boolean property).

This feature depends directly on `simulated-position`: locking the camera onto a position that never moves wouldn't demonstrate anything, so it only makes sense combined with a running tracked-position feed.

`lockCameraPositionOnTracking` has a sibling, `lockCameraOrientationOnTracking` (also locks the camera's *orientation*, based on the device's orientation sensor data) — not covered here, which only demonstrates the *position* lock.

## SDK usage

The toggle sets the property; the SDK then reports every lock change (including the ones it makes by itself) through three view events, which the bridge relays so the UI always mirrors the SDK state:

```js
// window.MapBridge, JS side (assets/www/map.html)
setCameraLockOnPosition: function (locked) {
  if (!view) return;
  view.lockCameraPositionOnTracking = !!locked;
},

// Subscribed once, right after createView():
function forwardCameraLock() {
  // The events carry no value: read the property inside the handler.
  sendToNative('cameraLockChanged', { locked: !!v.lockCameraPositionOnTracking });
}
v.addEventListener('trackingon', forwardCameraLock);
v.addEventListener('trackingoff', forwardCameraLock);
v.addEventListener('trackingchanged', forwardCameraLock);
```

```dart
// lib/visio_one/visio_one_controller.dart
Future<void> setCameraLockOnPosition(bool locked) =>
    _call('setCameraLockOnPosition', [locked]);

// In the JS -> Dart message handler: the toggle's value only comes from here.
if (parsed.type == 'cameraLockChanged') {
  final locked = parsed.data is Map ? (parsed.data as Map)['locked'] : null;
  if (locked is bool) simulatedPosition.onCameraLockChanged(locked);
}
```

## Things to know

- **`view.allowTracking = true` turns the lock on by itself.** Setting it forces `lockCameraPositionOnTracking = true` (and `lockCameraOrientationOnTracking = true`) and dispatches `trackingon`. So right after tracking starts, the camera already follows the position: a toggle that starts "off" would be wrong.
- **`view.allowTracking = false` turns both locks off** and dispatches `trackingoff`.
- **A user pan turns the lock off.** When the user drags or otherwise moves the map while tracking, the SDK sets `lockCameraPositionOnTracking = false` and dispatches `trackingchanged`. Your app is not told any other way.
- **Use `trackingon` / `trackingoff` / `trackingchanged` to keep a UI in sync**, and treat `view.lockCameraPositionOnTracking` as the only source of truth. The events carry no lock value: read the property inside the handler. Setting the property yourself also dispatches `trackingchanged`. The setter does nothing (and dispatches nothing) if the value doesn't change or if `allowTracking` is `false`. You may get the same value twice in a row, so handlers should be idempotent.
- **Don't set `allowTracking = true` on every position update.** Each assignment locks the camera again, so a position feed that sets it on every tick (here every ~150 ms) undoes the user's "unlock" or pan almost at once. Set it only when it goes from false to true (`if (!view.allowTracking) view.allowTracking = true;`).
- **`lockCameraPositionOnTracking` only has an effect if `allowTracking` is already `true`.** Per its doc comment in the SDK's typings: *"Set it to true to bind camera focus on tracking position. This won't have any effect if flag 'allowTracking' isn't set to true."* Unlike `injectTrackedPosition`, which throws if `allowTracking` is still `false` (see `simulated-position`), this one silently does nothing. It is not an error.
- **`lockCameraOrientationOnTracking` is a separate property.** This demo never sets it directly. `allowTracking` turns it on and off along with the position lock. A real orientation-lock demo would also need data from the device's orientation sensor, which this bridge doesn't provide.

## Learn more

- See `simulated-position`: a direct prerequisite for this feature, in particular for `injectTrackedPosition`/`allowTracking`.
- See `docs/COMMUNICATION_GUIDE.md` in this repo (section 3) for the `setCameraLockOnPosition` entry in the Native -> JS table.
