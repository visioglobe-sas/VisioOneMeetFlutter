# Dynamic POI CRUD

## Description

Creates, updates, and removes a POI at runtime, without republishing the map in VisioMapEditor — `venue.createPOI()` / `venue.updatePOI()` / `venue.removePOI()`, plus `venue.createLabel()` / `venue.updateLabel()` to give the created POI a visible, editable footprint on the map.

## SDK usage

```dart
// lib/features/dynamic-poi-crud/dynamic_poi_crud_bridge.dart
extension DynamicPoiCrudBridge on VisioOneController {
  Future<Map<String, Object?>?> createDynamicPOI({
    required String newId,
    required String anchorId,
    required String labelText,
  }) => request('createDynamicPOI', [newId, anchorId, labelText]);

  Future<Map<String, Object?>?> updateDynamicPoiLabelText(String text) =>
      request('updateDynamicPoiLabelText', [text]);

  Future<Map<String, Object?>?> removeDynamicPOI() => request('removeDynamicPOI');
}
```

```js
// assets/www/features/dynamic-poi-crud.js, inside core.register({ ... })
// (`core` = window.MapCore; `venue` / `view` = core.venue / core.view)
createDynamicPOI: function (requestId, newId, anchorId, labelText) {
  if (!venue) {
    core.sendToNative('dynamicPoiCreated', { requestId: requestId, success: false, error: 'notReady' });
    return;
  }

  // core.resolveAnchor(): venue.pois.find(p => p.id === anchorId), then its display
  // position — first label, else image/marker, else surface centre.
  var anchor = core.resolveAnchor(anchorId);
  if (anchor.error) {   // 'notFound' | 'noPosition'
    core.sendToNative('dynamicPoiCreated', { requestId: requestId, success: false, error: anchor.error });
    return;
  }

  var poi;
  try {
    poi = venue.createPOI({ id: newId });
  } catch (error) {
    // POIAlreadyExistsError — a normal, demoable state, not a crash.
    core.sendToNative('dynamicPoiCreated', { requestId: requestId, success: false, error: 'alreadyExists', message: error.message });
    return;
  }

  var label = venue.createLabel({ poi: poi, position: anchor.position, width: 2, text: labelText });

  dynamicPoi = poi;
  dynamicPoiLabel = label;
  core.sendToNative('dynamicPoiCreated', { requestId: requestId, success: true, poiId: newId, text: labelText });
},

updateDynamicPoiLabelText: function (requestId, text) {
  if (!dynamicPoiLabel) {
    core.sendToNative('dynamicPoiLabelUpdated', { requestId: requestId, success: false, error: 'noPoi' });
    return;
  }
  venue.updateLabel(dynamicPoiLabel, { text: text });
  core.sendToNative('dynamicPoiLabelUpdated', { requestId: requestId, success: true, text: text });
},

removeDynamicPOI: function (requestId) {
  if (!dynamicPoi) {
    core.sendToNative('dynamicPoiRemoved', { requestId: requestId, success: false, error: 'noPoi' });
    return;
  }
  venue.removePOI(dynamicPoi);
  dynamicPoi = null;
  dynamicPoiLabel = null;
  core.sendToNative('dynamicPoiRemoved', { requestId: requestId, success: true });
},
```

Each action is a request/response round trip (`VisioOneController.request()` adds a fresh `requestId` as first JS argument and completes with the data of the response carrying it (or `null` after 5 s)): the JS side reports back with `dynamicPoiCreated` / `dynamicPoiLabelUpdated` / `dynamicPoiRemoved`, each carrying the same `requestId` and a `success` boolean, plus a `message` explaining any failure.

The real SDK surface involved, from the SDK's typings (`Venue.d.ts`, `POI.d.ts`, `Label.d.ts`):

```ts
// Venue
createPOI(options: POICreateOptions): POI;      // throws POIAlreadyExistsError if `id` is already used
removePOI(poi: POI): void;                       // cascades: removes any attached visual element too
updatePOI(poi: POI, options: POIUpdateOptions): void; // categories only — see "Things to know"
createLabel(options: LabelCreateOptions): Label;
updateLabel(label: Label, options: LabelUpdateOptions): void;

interface POICreateOptions {
  readonly id: string;
  readonly floor?: Floor;
  readonly categories?: Category[];
}

interface POIUpdateOptions {
  readonly categories: Category[]; // the only updatable field
}

interface POI {
  readonly id: string;
  readonly floor?: Floor;
  readonly images: Image[];
  readonly labels: Label[];
  readonly lines: Line[];
  readonly surfaces: Surface[];
  readonly markers: Marker[];
  readonly categories: Category[];
}

interface LabelCreateOptions {
  readonly poi: POI;
  readonly position: Position;   // WGS84: { latitude, longitude, altitude? }
  readonly width: number;        // meters
  readonly height?: number;      // meters
  readonly text: string;
  readonly color?: Color;
  readonly rotation?: number;    // degrees
}

interface LabelUpdateOptions {
  readonly position?: Position;
  readonly width?: number;
  readonly height?: number;
  readonly text?: string;
  readonly isVisible?: boolean;
  readonly color?: Color;
}
```

The anchor POI's position is resolved the same way `resolvePoiPosition` (used by `simulated-position`) does it: `venue.pois.find(p => p.id === anchorId)`, then that POI's first label's `.position`, else its first image's or marker's, else the centre of its first surface's `positions`. There is no "tap the map to place a pin" UI in this demo — the new POI's position is always copied from an existing POI, never freehand.

## Things to know

- **A freshly created POI has no visual footprint by itself.** `venue.createPOI({ id })` only registers a logical id (+ optional floor/categories) in the venue — `images`, `labels`, `lines`, `surfaces`, and `markers` are all empty arrays on the object it returns. Nothing appears on the map until you separately attach a visual element (here, `venue.createLabel({ poi, ... })`) to that POI. This is why the demo immediately follows `createPOI` with `createLabel` rather than treating the POI alone as "done".
- **`updatePOI` can only change categories — nothing visual.** `POIUpdateOptions` has exactly one field, `categories: Category[]`; there is no way to move a POI, resize it, or touch any of its attached visual elements through `updatePOI`. Passing `[]` clears all of a POI's categories rather than being a no-op. The "Update text" action in this demo therefore calls `venue.updateLabel()` on the POI's attached `Label` instead — that is the actual "edit a dynamic POI's content" story for this SDK.
- **`removePOI` cascades to its visual elements.** Removing a POI automatically removes any `Image`/`Label`/`Line`/`Marker`/`Surface` still attached to it from the view — there is no need to separately call `removeLabel()` on the label created above before calling `removePOI()`.
- **`createPOI` throws `POIAlreadyExistsError` synchronously** when `id` is already used anywhere in the venue — including an id that belongs to a POI authored in VisioMapEditor itself, not just one created dynamically. The JS bridge code above wraps the call in try/catch and reports it back as a normal `success: false` state (`error: 'alreadyExists'`, plus the SDK's own message, e.g. "Cannot create POI, provided ID already exist."), not as a crash. `POIAlreadyExistsError` is not exported by the UMD bundle, so no `instanceof` check is possible.
- The anchor-position lookup can come up empty for a POI with no label, image, marker or surface (e.g. one that only has a `Line`). That is reported back as a normal `noPosition` failure rather than throwing.

## Learn more

See `custom-data` for the same `requestId`-correlated bridge request/response idiom this feature reuses, and `goto-poi` for the same Place-ID-resolution pattern used to find the anchor POI.
