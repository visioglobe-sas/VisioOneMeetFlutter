# Dynamic POI CRUD

## Description

Creates, updates, and removes a POI at runtime, without republishing the map in VisioMapEditor — `venue.createPOI()` / `venue.updatePOI()` / `venue.removePOI()`, plus `venue.createLabel()` / `venue.updateLabel()` to give the created POI a visible, editable footprint on the map.

## SDK usage

```dart
// lib/visio_one/visio_one_controller.dart
Future<void> createDynamicPOI(
  String requestId, {
  required String newId,
  required String anchorId,
  required String labelText,
}) => _call('createDynamicPOI', [requestId, newId, anchorId, labelText]);

Future<void> updateDynamicPoiLabelText(String requestId, String text) =>
    _call('updateDynamicPoiLabelText', [requestId, text]);

Future<void> removeDynamicPOI(String requestId) => _call('removeDynamicPOI', [requestId]);
```

```js
// window.MapBridge, JS side (assets/www/map.html)
createDynamicPOI: function (requestId, newId, anchorId, labelText) {
  if (!venue) {
    sendToNative('dynamicPoiCreated', { requestId: requestId, success: false, message: 'Map not ready.' });
    return;
  }

  var anchor = venue.pois.find(function (p) { return p.id === anchorId; });
  if (!anchor) {
    sendToNative('dynamicPoiCreated', { requestId: requestId, success: false, message: 'Anchor POI "' + anchorId + '" not found.' });
    return;
  }

  var source = anchor.labels[0] || anchor.markers[0];
  if (!source) {
    sendToNative('dynamicPoiCreated', { requestId: requestId, success: false, message: 'Anchor POI "' + anchorId + '" has no label or marker to copy a position from.' });
    return;
  }

  var poi;
  try {
    poi = venue.createPOI({ id: newId });
  } catch (error) {
    // POIAlreadyExistsError — a normal, demoable state, not a crash.
    sendToNative('dynamicPoiCreated', { requestId: requestId, success: false, message: error && error.message ? error.message : 'Could not create POI "' + newId + '".' });
    return;
  }

  var label = venue.createLabel({ poi: poi, position: source.position, width: 2, text: labelText });

  dynamicPoi = poi;
  dynamicPoiLabel = label;
  sendToNative('dynamicPoiCreated', { requestId: requestId, success: true, poiId: newId, text: labelText });
},

updateDynamicPoiLabelText: function (requestId, text) {
  if (!dynamicPoiLabel) {
    sendToNative('dynamicPoiLabelUpdated', { requestId: requestId, success: false, message: 'No dynamic POI tracked.' });
    return;
  }
  venue.updateLabel(dynamicPoiLabel, { text: text });
  sendToNative('dynamicPoiLabelUpdated', { requestId: requestId, success: true, text: text });
},

removeDynamicPOI: function (requestId) {
  if (!dynamicPoi) {
    sendToNative('dynamicPoiRemoved', { requestId: requestId, success: false, message: 'No dynamic POI tracked.' });
    return;
  }
  venue.removePOI(dynamicPoi);
  dynamicPoi = null;
  dynamicPoiLabel = null;
  sendToNative('dynamicPoiRemoved', { requestId: requestId, success: true });
},
```

Each action is a request/response round trip (same `requestId`-correlated pattern as `custom-data`'s `loadCustomData` / `customDataLoaded`): the Native → JS call is fire-and-forget, and the JS side reports back asynchronously with `dynamicPoiCreated` / `dynamicPoiLabelUpdated` / `dynamicPoiRemoved`, each carrying the same `requestId` and a `success` boolean, plus a `message` explaining any failure.

The real SDK surface involved, all on `Venue` (`visioone/src/VisioOne/Venue/Venue.ts`), `POI` (`POI.ts`), and `Label` (`Label.ts`):

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
  categories: Category[]; // the only updatable field
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

The anchor POI's position is resolved the same way `resolvePoiPosition` (used by `simulated-position`) does it: `venue.pois.find(p => p.id === anchorId)`, then that POI's first `Label`'s `.position`, falling back to its first `Marker`'s `.position` if it has no label. There is no "tap the map to place a pin" UI in this demo — the new POI's position is always copied from an existing POI, never freehand.

## Things to know

- **A freshly created POI has no visual footprint by itself.** `venue.createPOI({ id })` only registers a logical id (+ optional floor/categories) in the venue — `images`, `labels`, `lines`, `surfaces`, and `markers` are all empty arrays on the object it returns. Nothing appears on the map until you separately attach a visual element (here, `venue.createLabel({ poi, ... })`) to that POI. This is why the demo immediately follows `createPOI` with `createLabel` rather than treating the POI alone as "done".
- **`updatePOI` can only change categories — nothing visual.** `POIUpdateOptions` has exactly one field, `categories: Category[]`; there is no way to move a POI, resize it, or touch any of its attached visual elements through `updatePOI`. Passing `[]` clears all of a POI's categories rather than being a no-op. The "Update text" action in this demo therefore calls `venue.updateLabel()` on the POI's attached `Label` instead — that is the actual "edit a dynamic POI's content" story for this SDK.
- **`removePOI` cascades to its visual elements.** Removing a POI automatically removes any `Image`/`Label`/`Line`/`Marker`/`Surface` still attached to it from the view — there is no need to separately call `removeLabel()` on the label created above before calling `removePOI()`.
- **`createPOI` throws `POIAlreadyExistsError` synchronously** (`visioone/src/VisioOne/Venue/Errors/POIAlreadyExistsError.ts`) when `id` is already used anywhere in the venue — including an id that belongs to a POI authored in VisioMapEditor itself, not just one created dynamically. The JS bridge code above wraps the call in try/catch and reports it back as a normal `success: false` state (with the SDK's own message, e.g. "Cannot create POI, provided ID already exist."), not as a crash.
- The anchor-position lookup (`anchorPoi.labels[0]?.position` / `anchorPoi.markers[0]?.position`) can come up empty for a POI that has neither — e.g. a POI that only has a `Surface`/`Line`/`Image`. That is reported back as a normal "no position to copy" failure rather than throwing, since `Image` isn't checked as a further fallback here (kept simple; a production app could add it).

## Learn more

See `custom-data` for the same `requestId`-correlated bridge request/response idiom this feature reuses, and `goto-poi` for the same Place-ID-resolution pattern used to find the anchor POI.
