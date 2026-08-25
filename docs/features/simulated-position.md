# Simulated Position

## Description

Animates a simulated tracked position (with its precision circle) moving between two POIs, via `view.allowTracking = true` followed by repeated calls to `view.injectTrackedPosition({ position, precisionCircleRadius })`. There's no real indoor positioning behind it — a periodic timer linearly interpolates between an origin and a destination position, in place of a real BLE/Wi-Fi/UWB feed; a real integration would call `injectTrackedPosition` from whatever positioning source it has instead.

Since a POI doesn't expose latitude/longitude directly, a `resolvePoiPosition` request/response round-trip is used to convert a Place ID into WGS84 coordinates before they can be fed into `injectTrackedPosition`.

## SDK usage

```js
// window.MapBridge, JS side (assets/www/map.html)
resolvePoiPosition: function (requestId, poiId) {
  if (!venue) return;
  var poi = venue.pois.find(function (p) { return p.id === poiId; });
  var source = poi
    ? (poi.markers[0] || poi.labels[0] || poi.images[0])
    : null;
  var position = source
    ? { latitude: source.position.latitude, longitude: source.position.longitude }
    : null;
  sendToNative('poiPositionResolved', { requestId: requestId, poiId: poiId, position: position });
},

injectTrackedPosition: function (latitude, longitude, precisionCircleRadius) {
  if (!view) return;
  view.allowTracking = true;
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
// lib/visio_one/visio_one_controller.dart
Future<void> resolvePoiPosition(String requestId, String poiId) =>
    _call('resolvePoiPosition', [requestId, poiId]);

Future<void> injectTrackedPosition({
  required double latitude,
  required double longitude,
  required double precisionCircleRadius,
}) => _call('injectTrackedPosition', [latitude, longitude, precisionCircleRadius]);

Future<void> stopTrackedPosition() => _run('window.MapBridge.stopTrackedPosition()');
```

`resolvePoiPosition` is fire-and-forget on the Dart side; its result arrives asynchronously as a `poiPositionResolved` message (`{requestId, poiId, position: {latitude, longitude} | null}`) on `VisioOneController.messages`. `requestId` is echoed back as-is so a caller can match multiple concurrent requests (e.g. resolving an origin and a destination at once) to their responses.

## Things to know

- **`injectTrackedPosition` requires `view.allowTracking = true` beforehand**, or the SDK throws an exception (see the SDK's `View.ts`, comment on `allowTracking`: "Setting it to true is mandatory for the features to work"). This bridge sets it to `true` on every call rather than exposing a separate toggle, since the flag has no other use here.
- **There's no dedicated SDK method to clear the simulated marker/circle.** Setting `allowTracking = false` is what removes them from the map — there's no `clearTrackedPosition`/`removeTrackedPosition` method. That's why `stopTrackedPosition()` only flips that flag.
- **A POI doesn't expose latitude/longitude directly.** `POI` (see `POI.d.ts` in the `@visioglobe/visioone` package) only carries `markers`, `labels`, `images`, `surfaces` — the WGS84 position comes from whichever of `markers[0].position`, `labels[0].position`, or `images[0].position` exists first (all three are a `Position`, `{latitude, longitude, altitude?}`, the exact shape `injectTrackedPosition` expects). If none exist (a purely surface-based POI with no marker/label/image) or the ID doesn't resolve, `resolvePoiPosition` responds with `position: null`.
- **`lockCameraPositionOnTracking` (see `camera-lock-on-position`) only has an effect once `allowTracking` is `true`** — unlike `injectTrackedPosition`, which throws if called too early, that one is a silent no-op if tracking isn't enabled yet.

## Learn more

- See `docs/COMMUNICATION_GUIDE.md` in this repo (section 3 for the full message contract, sections 6/7 for the procedure this feature follows: adding commands **and** a response event).
- Related: `floor-selector` is this repo's other example of the request/response message pattern.
- Related: `camera-lock-on-position` builds directly on top of this feature's tracked position.
