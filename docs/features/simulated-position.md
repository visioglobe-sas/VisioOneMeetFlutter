# Simulated Position

## Description

Animates a simulated tracked position (with its precision circle) moving between two POIs, via `view.allowTracking = true` followed by repeated calls to `view.injectTrackedPosition({ position, precisionCircleRadius })`. There's no real indoor positioning behind it — a periodic timer linearly interpolates between an origin and a destination position, in place of a real BLE/Wi-Fi/UWB feed; a real integration would call `injectTrackedPosition` from whatever positioning source it has instead.

Since a POI doesn't expose latitude/longitude directly, a `resolvePoiPosition` request/response round-trip is used to convert a Place ID into WGS84 coordinates before they can be fed into `injectTrackedPosition`.

## SDK usage

```js
// assets/www/features/simulated-position.js, inside core.register({ ... })
// (`core` = window.MapCore; `venue` / `view` = core.venue / core.view)
// core.poiDisplayPosition(poi): first label's position, else first image's or marker's,
// else the centre of the first surface (see docs/COMMUNICATION_GUIDE.md).
resolvePoiPosition: function (requestId, poiId) {
  var poi = core.findPoi(poiId);
  var found = poi ? core.poiDisplayPosition(poi) : null;
  var position = found ? { latitude: found.latitude, longitude: found.longitude } : null;
  core.sendToNative('poiPositionResolved', { requestId: requestId, poiId: poiId, position: position });
},

injectTrackedPosition: function (latitude, longitude, precisionCircleRadius) {
  if (!view) return;
  if (!view.allowTracking) view.allowTracking = true;
  view.injectTrackedPosition({
    position: { latitude: latitude, longitude: longitude },
    precisionCircleRadius: precisionCircleRadius,
  });
},

stopTrackedPosition: function () {
  if (!view) return;
  view.allowTracking = false;
},
```

```dart
// lib/features/simulated-position/simulated_position_bridge.dart
extension SimulatedPositionBridge on VisioOneController {
  Future<SimulatedPosition?> resolvePoiPosition(String poiId) async {
    final result = await request('resolvePoiPosition', [poiId]);
    return SimulatedPosition.fromJson(result?['position']);
  }

  Future<void> injectTrackedPosition({
    required double latitude,
    required double longitude,
    required double precisionCircleRadius,
  }) => send('injectTrackedPosition', [latitude, longitude, precisionCircleRadius]);

  Future<void> stopTrackedPosition() => send('stopTrackedPosition');
}
```

`resolvePoiPosition` is a request/response round trip: `VisioOneController.request()` adds a fresh `requestId` as first JS argument and completes with the data of the response carrying it (or `null` after 5 s). The JS side answers with a `poiPositionResolved` message (`{requestId, poiId, position: {latitude, longitude} | null}`); `requestId` is echoed back as-is so several concurrent requests (e.g. resolving an origin and a destination at once) are matched to their own responses.

## Things to know

- **`injectTrackedPosition` requires `view.allowTracking = true` beforehand**, or the SDK throws an exception (see the doc comment on `allowTracking` in the SDK's typings: "Setting it to true is mandatory for the features to work"). This bridge sets it inside `injectTrackedPosition` rather than exposing a separate toggle, since the flag has no other use here. It only sets it when the flag is still `false`: every `allowTracking = true` assignment also forces `lockCameraPositionOnTracking = true` (the camera follows the position again). Setting it on every update would undo any user pan or unlock every ~150 ms. See `camera-lock-on-position`.
- **There's no dedicated SDK method to clear the simulated marker/circle.** Setting `allowTracking = false` is what removes them from the map — there's no `clearTrackedPosition`/`removeTrackedPosition` method. That's why `stopTrackedPosition()` only flips that flag.
- **A POI doesn't expose latitude/longitude directly.** `POI` (see `POI.d.ts` in the `@visioglobe/visioone` package) only carries `labels`, `images`, `markers`, `surfaces` — the WGS84 position is taken from `labels[0].position`, else `images[0].position` or `markers[0].position`, else the centre of `surfaces[0].positions` (all `Position`, `{latitude, longitude, altitude?}`, the shape `injectTrackedPosition` expects). If the POI has none of them or the ID doesn't resolve, `resolvePoiPosition` responds with `position: null`.
- **`lockCameraPositionOnTracking` (see `camera-lock-on-position`) only has an effect once `allowTracking` is `true`** — unlike `injectTrackedPosition`, which throws if called too early, that one is a silent no-op if tracking isn't enabled yet.

## Learn more

- See `docs/COMMUNICATION_GUIDE.md` in this repo (section 3 for the full message contract, sections 5/6 for the procedure this feature follows: adding commands **and** a response event).
- Related: `floor-selector` is this repo's other example of the request/response message pattern.
- Related: `camera-lock-on-position` builds directly on top of this feature's tracked position.
