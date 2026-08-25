# Occupancy (Simulated)

## Description

Dynamically colors a POI's surface to reflect an occupancy status (free / soon occupied / occupied), via `venue.updateSurface(surface, { color })`. There's no real sensor behind it — a periodic timer cycles through colors in place of a real IoT feed, as a starting point for wiring in a real data source (websocket, API polling) without touching the SDK call itself.

## SDK usage

```js
// window.MapBridge, JS side (assets/www/map.html)
updateOccupancy: function (occupancy) {
  if (!venue) return;
  occupancy.forEach(function (entry) {
    var poi = venue.pois.find(function (p) { return p.id === entry.planId; });
    if (!poi) return;
    poi.surfaces.forEach(function (surface) {
      venue.updateSurface(surface, { color: entry.color });
    });
  });
},
```

```dart
// lib/visio_one/visio_one_controller.dart
Future<void> updateOccupancy(List<Map<String, Object?>> occupancy) =>
    _call('updateOccupancy', [occupancy]);
```

`occupancy` is a list of `{planId, color}` entries — `planId` is a POI's Place ID, `color` a CSS-style color value applied to every surface of that POI.

## Things to know

- **`planId` must be a real POI ID from the loaded map.** `venue.pois.find(...)` fails silently (no error surfaced) if the ID doesn't match anything.
- **`color: null` resets the surface's appearance** — the same mechanism `clearSelection` uses with `selectionColor: undefined` (see `goto-poi`). It's how you "return" a place to its normal look, not a hardcoded default color; always send `color: null` when a simulation/feed stops, or the surface stays stuck on the last color it was given.
- **Never call `JSON.parse()` on an argument received inside `window.MapBridge.*`.** Dart already encodes arguments via `jsonEncode` before interpolating them into the generated script, so by the time the JS method body runs, the argument is already a native JS value (here, a list of objects), not JSON text to re-parse. Calling `JSON.parse()` on it throws.

## Learn more

See `docs/COMMUNICATION_GUIDE.md` in this repo for the full bridge message contract.
