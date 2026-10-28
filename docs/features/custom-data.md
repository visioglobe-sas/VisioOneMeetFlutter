# Custom data

## Description

Reads business `CustomData` — free-form key/value strings (price, opening hours, product reference, ...) attached to a POI while editing the map in VisioMapEditor — via `venue.getPOICustomData(poi)`, preceded by `venue.refreshCustomData()` to (re)load the data from the server.

## SDK usage

```dart
// lib/features/custom-data/custom_data_bridge.dart
extension CustomDataBridge on VisioOneController {
  Future<Map<String, Object?>?> loadCustomData(String poiId) => request('loadCustomData', [poiId]);
}
```

```js
// assets/www/features/custom-data.js, inside core.register({ ... })
// (`core` = window.MapCore; `venue` / `view` = core.venue / core.view)
loadCustomData: function (requestId, poiId) {
  if (!venue) {
    core.sendToNative('customDataLoaded', { requestId: requestId, poiId: poiId, found: false, customData: null });
    return;
  }
  venue
    .refreshCustomData()
    .catch(function (error) {
      // See "Things to know" below — a rejection here is a normal state
      // (no CustomData published yet), not an error to surface.
      console.warn('[MapBridge] refreshCustomData failed:', error);
    })
    .then(function () {
      var poi = venue.pois.find(function (p) { return p.id === poiId; });
      if (!poi) {
        core.sendToNative('customDataLoaded', { requestId: requestId, poiId: poiId, found: false, customData: null });
        return;
      }
      core.sendToNative('customDataLoaded', {
        requestId: requestId,
        poiId: poiId,
        found: true,
        customData: venue.getPOICustomData(poi),
      });
    });
},
```

This is a request/response round trip: `VisioOneController.request()` adds a fresh `requestId` as first JS argument and completes with the data of the response carrying it (or `null` after 5 s). The JS side answers with a `customDataLoaded` message carrying the same `requestId`, `found` (whether `poiId` resolved to a POI), and `customData`.

The two real SDK calls involved, both on `Venue` (`Venue.d.ts` in the SDK's typings):

```ts
// (Re)loads all CustomData from the server into the venue's cache.
refreshCustomData(): Promise<void>;

// Synchronous read of one POI's CustomData from that cache.
getPOICustomData(poi: POI): CustomData;

// CustomData is a free key/value map of strings, defined per-POI in VisioMapEditor:
interface CustomData {
  readonly [key: string]: string;
}
```

## Demo map

This feature demo loads a dedicated map hash (`kd9426d8cb3f1c532f22b5bcbd325c280bd351feb`, `kCustomDataMapHash` in `lib/demo_map.dart`), distinct from the rest of the app's shared demo map (`kDefaultMapHash`) — see the conditional in `lib/features/feature_screen.dart`. The shared demo map has no `CustomData` published yet, so it would only ever demonstrate the empty-state described above; every other feature screen keeps using `kDefaultMapHash` unchanged.

Three Place IDs are confirmed to carry real `CustomData` on that dedicated map (`DemoMap.customDataQuickIds` in `lib/demo_map.dart`):

- `B1` → `{"CSM ID":"BLBLA"}`
- `B3-UL00-ID0065` → `{"Sensor X":"17718393"}`
- `B3-UL00-ID0064` → `{"SENSOR":"DDDZEZHJF"}`

## Things to know

- **The CustomData cache starts empty and is never populated automatically.** `getPOICustomData` reads from an in-memory cache that starts as `{}` when the venue loads and is only filled by `refreshCustomData()`. Reading a POI's CustomData before ever calling `refreshCustomData()` always returns `{}`, even if that POI has real CustomData published on the server — call `refreshCustomData()` at least once first (this demo does it on every "Load" tap, so it's always fresh, but a production app should decide its own refresh cadence rather than reload on every read).
- **`getPOICustomData` always returns an object, never `null`/`undefined`.** Both "this POI has no CustomData at all" and "the cache hasn't been refreshed yet" resolve to the same `{}` — there is no way to distinguish those two cases from the return value alone. Treat `{}` as a normal empty state, not as an error.
- **`refreshCustomData()` rejects if no CustomData has been published for the map** (the underlying fetch of `customData.json` 404s in that case — see `CustomDataWebServiceFetcher`/`NotFoundError` in the SDK source). This is expected for a map that simply has no CustomData yet, not a failure — the JS bridge code above deliberately swallows that rejection (just a console warning) and continues to `getPOICustomData`, which still safely returns `{}`. Don't surface a raw `refreshCustomData()` rejection as a hard error to the user.
- `poiId` is a Place ID, resolved the same way as in `goto-poi` (`venue.pois.find(p => p.id === poiId)`) — an ID that doesn't match any POI resolves to `found: false`, not an error.

## Learn more

See `goto-poi` for the same Place-ID-resolution pattern, and `simulated-position` for the same `requestId`-correlated request/response bridge idiom this feature reuses.
