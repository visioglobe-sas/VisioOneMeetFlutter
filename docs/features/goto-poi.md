# Go to POI

## Description

Centers the camera on a given POI (by ID) and selects it visually, via `view.goToPOI(poi)` — preceded by `view.goToFloor(poi.floor)` to switch to the right floor first. Also demonstrates `clearSelection()`, which removes the current visual selection across the whole venue.

## SDK usage

```dart
// lib/visio_one/visio_one_controller.dart
Future<void> goToPOI(String poiId) => _call('goToPOI', [poiId]);
Future<void> clearSelection() => _run('window.MapBridge.clearSelection()');
```

```js
// window.MapBridge, JS side (assets/www/map.html)
goToPOI: function (poiId) {
  if (!venue || !view) return;
  var poi = venue.pois.find(function (p) { return p.id === poiId; });
  if (!poi) return;
  view.goToFloor(poi.floor).then(function () {
    view.goToPOI(poi);
  });
},

clearSelection: function () {
  if (!venue) return;
  venue.pois.forEach(function (poi) {
    poi.surfaces.forEach(function (surface) {
      venue.updateSurface(surface, { selectionColor: undefined });
    });
  });
},
```

`poiId` is a Place ID, resolved via `venue.pois.find(p => p.id === poiId)` — not a coordinate or a display name.

## Things to know

- `goToPOI` fails silently if the ID doesn't match any POI (`venue.pois.find(...)` returns `undefined`, the function returns without doing anything) — no error is surfaced; an invalid ID just results in a camera that doesn't move.
- `goToPOI` also switches floor if needed (`view.goToFloor(poi.floor)` before `view.goToPOI(poi)`), unlike `goToGlobal` (see `reset-view`), which only recenters the camera without touching the currently displayed floor.
- `view.goToFloor()` returns a promise — chain `view.goToPOI(poi)` in its `.then()` so the camera move happens after the floor switch completes, not before.
- `clearSelection()` doesn't need to know which `poiId` is currently selected: visual selection is global SDK state, so it iterates every POI's surfaces and resets `selectionColor` to `undefined` — there's no per-POI state to track on the calling side.

## Learn more

See `docs/COMMUNICATION_GUIDE.md` in this repo (section 5), which uses `goToPOI` as the reference example for JSON-encoding Dart -> JS arguments and the `JSON.parse()` warning.
