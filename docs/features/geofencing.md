# Geofencing

## Description

Triggers a visual alert when a simulated tracked position enters a zone defined on the map. Builds directly on [simulated position](./simulated-position.md): the "zone" is the first `Surface` of an existing POI, and the containment test runs on every tick of that feature's tracking loop against `view.injectTrackedPosition`'s current coordinates. On entering the zone, the zone POI's surface is recolored as an alert (`venue.updateSurface`); on exiting, its color is restored.

## SDK usage

Resolving the zone's polygon (WGS84 vertices of the zone POI's first surface):

```dart
// lib/visio_one/visio_one_controller.dart
Future<void> resolvePoiZone(String requestId, String poiId) =>
    _call('resolvePoiZone', [requestId, poiId]);
```

```js
// window.MapBridge, JS side (assets/www/map.html)
resolvePoiZone: function (requestId, poiId) {
  if (!venue) {
    sendToNative('poiZoneResolved', { requestId: requestId, poiId: poiId, positions: null });
    return;
  }
  var poi = venue.pois.find(function (p) { return p.id === poiId; });
  if (!poi) {
    sendToNative('poiZoneResolved', { requestId: requestId, poiId: poiId, positions: null });
    return;
  }
  var surface = poi.surfaces[0];
  var positions = surface
    ? surface.positions.map(function (pos) {
        return { latitude: pos.latitude, longitude: pos.longitude };
      })
    : [];
  sendToNative('poiZoneResolved', { requestId: requestId, poiId: poiId, positions: positions });
},
```

Applying the visual alert on entry/exit, once the containment check has run natively:

```dart
// lib/visio_one/visio_one_controller.dart
Future<void> setZoneAlert(String placeId, bool active) =>
    _call('setZoneAlert', [placeId, active]);
```

```js
// window.MapBridge, JS side (assets/www/map.html)
setZoneAlert: function (placeId, active) {
  if (!venue) return;
  var poi = venue.pois.find(function (p) { return p.id === placeId; });
  if (!poi) return;
  poi.surfaces.forEach(function (surface) {
    venue.updateSurface(surface, { color: active ? '#E74C3C' : 'initial' });
  });
},
```

`Surface.positions` (`Position[]`, `{latitude, longitude, altitude?}`) is the same WGS84 shape consumed by `injectTrackedPosition` — no coordinate conversion needed between zone geometry and tracked position. The point-in-zone test itself (`isPointInPolygon` in `lib/visio_one/geofence_utils.dart`, a standard ray-casting/PNPOLY check) runs entirely on the native side, on every ~150ms tick of the existing `simulated-position` tracking loop (`SimulatedPositionSession._tick`) — there is no SDK event fired on tracked-position change to hook into instead.

## Things to know

- **The SDK has no geofencing/point-in-polygon primitive.** There is no `Zone`/`Geofence` type, no containment method, and no `trackedpositionchanged` event. This demo builds the whole feature from two things the SDK already exposes for other purposes: a POI's `Surface.positions` (its render polygon) as the zone boundary, and the already-running `injectTrackedPosition` tracking loop as the position source. The containment math itself (ray casting, latitude/longitude treated as planar x/y) is plain app code, accurate enough at building scale but not a real geodesic calculation.
- **A "zone" is just a POI's first surface.** `poi.surfaces` can hold more than one `Surface`; this demo only tests against `poi.surfaces[0]`, so a multi-surface POI's other surfaces are ignored for containment (though `setZoneAlert` does color every surface of the POI, for a consistent visual response).
- **`resolvePoiZone` distinguishes two failure shapes.** `positions: null` means the POI ID doesn't exist at all; `positions: []` (empty array) means the POI exists but has no surface to use as a zone — these are different, worth surfacing as different messages to the integrator/user rather than collapsing into one generic error.
- **The alert color is applied via `'initial'` to revert, not `undefined`.** Same `SurfaceUpdateOptions` quirk as [clickable surface](./clickable-surface.md): only the string `'initial'` restores the color originally authored in the map bundle.

## Learn more

See [simulated position](./simulated-position.md) for the tracking loop and POI-to-WGS84-position resolution this feature reuses, and [clickable surface](./clickable-surface.md) for the sibling `venue.updateSurface`/`'initial'` pattern used here for the alert color.
