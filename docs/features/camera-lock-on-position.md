# Camera Lock on Position

## Description

Locks the camera's focus on the currently tracked position (see `simulated-position`), like a "recenter on my position" toggle in a GPS app, via `view.lockCameraPositionOnTracking` (a boolean property).

This feature depends directly on `simulated-position`: locking the camera onto a position that never moves wouldn't demonstrate anything, so it only makes sense combined with a running tracked-position feed.

`lockCameraPositionOnTracking` has a sibling, `lockCameraOrientationOnTracking` (also locks the camera's *orientation*, based on the device's orientation sensor data) — not covered here, which only demonstrates the *position* lock.

## SDK usage

The toggle sets the property; the SDK then reports every lock change (including the ones it makes by itself) through three view events, which the bridge relays so the UI always mirrors the SDK state:

```js
// assets/www/features/camera-lock-on-position.js (`core` = window.MapCore)
core.register({
  setCameraLockOnPosition: function (locked) {
    var view = core.view;
    if (!view) return;
    view.lockCameraPositionOnTracking = !!locked;
  },
});

// Called for every view created, right after createView():
core.onViewCreated(function (view) {
  function forwardCameraLock() {
    // The events carry no value: read the property inside the handler.
    core.sendToNative('cameraLockChanged', { locked: !!view.lockCameraPositionOnTracking });
  }
  view.addEventListener('trackingon', forwardCameraLock);
  view.addEventListener('trackingoff', forwardCameraLock);
  view.addEventListener('trackingchanged', forwardCameraLock);
});
```

```dart
// lib/features/camera-lock-on-position/camera_lock_on_position_bridge.dart
extension CameraLockOnPositionBridge on VisioOneController {
  Future<void> setCameraLockOnPosition(bool locked) => send('setCameraLockOnPosition', [locked]);
}

// lib/features/simulated-position/simulated_position_session.dart: the toggle's
// value only comes from this message, even while the panel is closed.
_subscription = _controller.messages.listen((message) {
  if (message.type != 'cameraLockChanged') return;
  final data = message.data;
  final locked = data is Map ? data['locked'] : null;
  if (locked is bool) onCameraLockChanged(locked);
});
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
