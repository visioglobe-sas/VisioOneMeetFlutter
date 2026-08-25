# Floor Selector

## Description

Switches building and/or floor via `view.goToFloor(floor)` / `view.goToBuilding(building)`. Since `Building`/`Floor` objects carry only opaque IDs, a second call, `getVenueLayout()`, fetches the venue's actual building/floor structure asynchronously so a caller can know what IDs exist before switching to one.

This feature intentionally coexists with the SDK's own built-in floor selector (a UI part named `floorSelector`, see `ui-part-visibility`): building a custom panel on top doesn't replace it. Both stay in sync because both react to the same SDK event, `currentfloorchanged`.

## SDK usage

```js
// window.MapBridge, JS side (assets/www/map.html)
goToFloor: function (buildingId, floorId) {
  if (!venue || !view) return;
  var building = venue.venueLayout.buildings.find(function (b) { return b.id === buildingId; });
  if (!building) return;
  if (floorId) {
    var floor = building.floors.find(function (f) { return f.id === floorId; });
    if (floor) view.goToFloor(floor);
  } else {
    view.goToBuilding(building);
  }
},

getVenueLayout: function () {
  if (!venue || !view) return;
  sendToNative('venueLayout', {
    currentBuildingId: view.currentBuilding ? view.currentBuilding.id : null,
    currentFloorId: view.currentFloor ? view.currentFloor.id : null,
    buildings: venue.venueLayout.buildings.map(function (building) {
      return {
        id: building.id,
        defaultFloorId: building.defaultFloorID,
        floors: building.floors
          .slice()
          .sort(function (a, b) { return b.levelIndex - a.levelIndex; })
          .map(function (floor) { return { id: floor.id, levelIndex: floor.levelIndex }; }),
      };
    }),
  });
},
```

```dart
// lib/visio_one/visio_one_controller.dart
Future<void> goToFloor({required String buildingId, String? floorId}) =>
    _call('goToFloor', [buildingId, floorId]);

Future<void> getVenueLayout() => _run('window.MapBridge.getVenueLayout()');
```

`getVenueLayout()` is fire-and-forget on the Dart side; its result arrives asynchronously as a `venueLayout` message on `VisioOneController.messages` (`{currentBuildingId, currentFloorId, buildings: [{id, defaultFloorId, floors: [{id, levelIndex}]}]}`) — the same request/response pattern used by `startItinerary`/`itineraryComputed` (see `compute-navigation`).

## Things to know

- **`Building`/`Floor` expose no name or label on the SDK side** (`@visioglobe/visioone`'s `Building.d.ts`/`Floor.d.ts`: `Building` only has `id`, `floors`, `defaultFloorID`; `Floor` only has `id`, `altitude`, `levelIndex`). The SDK's own built-in floor selector displays only `levelIndex.toString()`, for lack of anything better. A caller who wants human-readable labels ("Ground floor", "Level 1"...) has to derive them itself — a static `floorId -> label` mapping, or a naming convention on the IDs published by VisioMapEditor — not from this SDK call.
- **Changing building without specifying a floor** (`floorId: null`) falls back to the building's default floor (`view.goToBuilding(building)`, which uses `defaultFloorID` internally) — that's SDK behavior, not something this bridge recomputes.
- **`goToFloor` fails silently if `buildingId`/`floorId` doesn't match anything** (same `Array.find` pattern as `goToPOI`) — no error surfaces back.
- **`venue.venueLayout.buildings[].floors` order is not documented as sorted** — the JS side sorts floors by descending `levelIndex` itself before sending them, to present them like a classic elevator panel (highest floor first); don't assume the SDK returns them pre-sorted.
- The SDK emits `currentfloorchanged` on `view` whenever the floor changes, from any source (this call, the SDK's own floor selector, or `goToPOI` elsewhere) — listen to it to keep a custom UI in sync rather than tracking floor state only from your own calls.

## Learn more

See `docs/COMMUNICATION_GUIDE.md` in this repo (section 3, and sections 6/7 for the procedure this feature follows: adding a command **and** a response event).
