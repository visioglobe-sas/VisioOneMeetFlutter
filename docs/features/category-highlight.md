# Category highlight

## Description

Highlights every POI belonging to a chosen category in one action (e.g. all restaurants, all shops), using two `Venue` collections — `venue.categories` (the venue's full category list) and `poi.categories` (the categories attached to a given POI) — combined with the same `venue.updateSurface` surface-coloring primitive used by `clickable-surface` and `occupancy-simulated`. There is no dedicated "highlight by category" SDK method; this feature is built entirely from those primitives.

## SDK usage

```dart
// lib/visio_one/visio_one_controller.dart
Future<void> getCategories(String requestId) => _call('getCategories', [requestId]);

Future<void> highlightCategory(String categoryId) async {
  final previous = highlightedCategoryId.value;
  if (previous == categoryId) return;
  if (previous != null) {
    await _call('clearCategoryHighlight', [previous]);
  }
  highlightedCategoryId.value = categoryId;
  await _call('highlightCategory', [categoryId]);
}

Future<void> clearCategoryHighlight() async {
  final current = highlightedCategoryId.value;
  if (current == null) return;
  highlightedCategoryId.value = null;
  await _call('clearCategoryHighlight', [current]);
}
```

```js
// window.MapBridge, JS side (assets/www/map.html)
getCategories: function (requestId) {
  if (!venue) {
    sendToNative('categoriesLoaded', { requestId: requestId, categories: [] });
    return;
  }
  var locale = venue.currentLocale;
  sendToNative('categoriesLoaded', {
    requestId: requestId,
    categories: venue.categories.map(function (c) {
      var translated = venue.translator.translateCategory(c, locale);
      return { id: c.id, label: (translated && translated.name) || c.id };
    }),
  });
},

highlightCategory: function (categoryId) {
  if (!venue) return;
  venue.pois
    .filter(function (poi) {
      return poi.categories.some(function (c) { return c.id === categoryId; });
    })
    .forEach(function (poi) {
      poi.surfaces.forEach(function (surface) {
        venue.updateSurface(surface, { color: '#FF6B00' });
      });
    });
},

clearCategoryHighlight: function (categoryId) {
  if (!venue) return;
  venue.pois
    .filter(function (poi) {
      return poi.categories.some(function (c) { return c.id === categoryId; });
    })
    .forEach(function (poi) {
      poi.surfaces.forEach(function (surface) {
        venue.updateSurface(surface, { color: 'initial' });
      });
    });
},
```

The relevant `Venue`/`POI` surface (`visioone/src/VisioOne/Venue/`):

```ts
interface Category {
  readonly id: string;
}

interface Venue {
  readonly categories: Category[];
  readonly pois: POI[];
  updateSurface(surface: Surface, options: SurfaceUpdateOptions): void;
}

interface POI {
  readonly categories: Category[];
  readonly surfaces: Surface[];
}
```

`getCategories` is a request/response round trip (same `requestId`-correlated pattern as `custom-data`'s `loadCustomData` / `customDataLoaded`): the Native → JS call is fire-and-forget, and the JS side reports back asynchronously with a `categoriesLoaded` message carrying the same `requestId` and a `categories` array of `{ id, label }` pairs — `id` is `Category.id` (used for filtering/highlighting), `label` is the name resolved via `venue.translator.translateCategory()` (used for display only, see "Things to know"). `highlightCategory`/`clearCategoryHighlight` are plain fire-and-forget one-way calls — no response needed, since the result is directly observable on the map.

Matching POIs are found with `venue.pois.filter(poi => poi.categories.some(c => c.id === categoryId))` — `poi.categories` is an array because a POI can belong to more than one category, so `.some(...)` is required rather than a direct equality check. For each matched POI, `poi.surfaces.forEach(surface => venue.updateSurface(surface, { color }))` applies (or reverts) the highlight color, one call per surface, exactly like `clickable-surface`/`occupancy-simulated`.

Only one category is ever highlighted at a time: the "revert previous, then highlight new" sequencing lives in `VisioOneController.highlightCategory`, keyed off `highlightedCategoryId` — a `ValueNotifier<String?>` held by the controller (not the overlay) precisely so it survives the bottom sheet being closed and reopened, the same reasoning documented on `SimulatedPositionSession`.

## Things to know

- **Not every POI has surfaces.** `poi.surfaces` is an empty array for point/marker-only POIs (no footprint drawn on the floor plan) — `poi.surfaces.forEach(...)` on such a POI simply does nothing. Those POIs are correctly matched by the category filter but never visually highlight via `updateSurface`. This is expected, not a bug; a production app wanting a visible cue for marker-only POIs would need a different mechanism (e.g. restyling the marker/label instead of the surface).
- **`'initial'` vs `undefined` when reverting.** `SurfaceUpdateOptions.color` must be set to the literal string `'initial'` to restore the color the map bundle originally authored for that surface — omitting the `color` key (or passing `undefined`) leaves whatever color was last applied in place instead of resetting it. Same gotcha already documented for `clickable-surface`'s `setSurfaceInteractive`.
- **`Category.id` is a raw internal identifier, not a display name.** On the shared demo map used by this feature (`kDefaultMapHash`, no dedicated map needed here), `id` values are opaque numeric strings (`"1"`, `"2"`, ... `"11"`, confirmed live — 10 categories, `"8"` absent from this particular map). The human-readable name (`Shops`, `Food and Beverage`, ...) comes from `venue.translator.translateCategory(category, venue.currentLocale).name`, the SDK's own dedicated label API — the same idiom used for building/floor labels elsewhere. `id` remains what filtering/highlighting must use; `label` is for display only (see the chip labels in `CategoryHighlightOverlay`).
- A `categoryId` that matches no POI (e.g. stale data) simply highlights nothing — `venue.pois.filter(...)` returns an empty array, no error is thrown.

## Learn more

See `docs/features/clickable-surface.md` for the sibling `venue.updateSurface`/`'initial'` pattern this feature reuses, `docs/features/occupancy-simulated.md` for another `color`-only `updateSurface` use case, and `docs/features/custom-data.md` for the same `requestId`-correlated bridge request/response idiom used by `getCategories`.
