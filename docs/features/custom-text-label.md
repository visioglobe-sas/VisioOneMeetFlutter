# Custom text label

## Description

Places your own free text on the map (opening hours, a price, a zone name…) next to an existing POI, and restyles it live — `venue.createLabel()` / `venue.updateLabel()` / `venue.removeLabel()`. The label is independent of the map's own labels: the anchor POI keeps its published label untouched.

## SDK usage

```dart
// lib/visio_one/visio_one_controller.dart
Future<void> placeTextLabel(
  String requestId, {
  required String anchorId,
  required String text,
  required String color,   // '#E53935'
  required double width,   // meters
  required double height,  // meters, always sent
  required int rotation,   // degrees
}) => _call('placeTextLabel', [requestId, anchorId, text, color, width, height, rotation]);

// changes = {'text': ...} | {'color': ...} | {'width': ..., 'height': ...}
Future<void> updateTextLabel(String requestId, Map<String, Object> changes) =>
    _call('updateTextLabel', [requestId, changes]);

Future<void> rotateTextLabel(String requestId, int rotation) =>
    _call('rotateTextLabel', [requestId, rotation]);

Future<void> removeTextLabel(String requestId) => _call('removeTextLabel', [requestId]);
```

The SDK's `Label` object can't cross the bridge, so the JS side keeps it (and the options it was created with) in a variable:

```js
// window.MapBridge, JS side (assets/www/map.html)
var textLabel = null;
var textLabelOptions = null;

// Shared with dynamic-poi-crud and 3d-icon-marker: resolve an existing POI and the position to copy from it.
function resolveAnchor(anchorId) {
  var poi = venue.pois.find(function (p) { return p.id === anchorId; });
  if (!poi) return { error: 'notFound' };
  var source = poi.labels[0] || poi.markers[0];
  if (!source) return { poi: poi, error: 'noPosition' };
  return { poi: poi, position: source.position };
}

placeTextLabel: function (requestId, anchorId, text, color, width, height, rotation) {
  if (textLabel) {                       // one label at a time
    venue.removeLabel(textLabel);
    textLabel = null;
  }
  if (!text || !String(text).trim()) {   // the SDK would throw "Cannot create Label, text is required"
    sendToNative('textLabelPlaced', { requestId: requestId, success: false, error: 'textRequired' });
    return;
  }
  var anchor = resolveAnchor(anchorId);  // error: 'notFound' | 'noPosition'
  // ...
  var position = {
    latitude: anchor.position.latitude + 0.00004,   // ~4 m offset, so the text doesn't
    longitude: anchor.position.longitude + 0.00004, // overlap the POI's own label
  };
  if (anchor.position.altitude !== undefined) position.altitude = anchor.position.altitude;
  var options = {
    poi: anchor.poi,       // the anchor POI owns the label
    position: position,    // WGS84
    width: width,          // meters
    height: height,        // meters — always pass it, see "Things to know"
    text: text,
    color: color,          // '#RRGGBB', rgb() or hsl()
    rotation: rotation,    // degrees, create-only
  };
  try {
    textLabel = venue.createLabel(options);
    textLabelOptions = options;
  } catch (error) {
    sendToNative('textLabelPlaced', { requestId: requestId, success: false, error: 'sdk', message: error.message });
    return;
  }
  sendToNative('textLabelPlaced', { requestId: requestId, success: true, poiId: anchorId });
},

updateTextLabel: function (requestId, changes) {
  // ... reject a missing label ('noLabel') or a blank changes.text ('textRequired'), then:
  venue.updateLabel(textLabel, changes);  // { text } | { color } | { width, height }
},

rotateTextLabel: function (requestId, rotation) {
  // rotation is not part of LabelUpdateOptions: remove and recreate with the same values.
  var options = Object.assign({}, textLabelOptions, { rotation: rotation });
  venue.removeLabel(textLabel);
  textLabel = venue.createLabel(options);
  textLabelOptions = options;
},

removeTextLabel: function (requestId) {
  // ... 'noLabel' if nothing is placed (the SDK would throw "Provided label is not registered"), else:
  venue.removeLabel(textLabel);
  textLabel = null;
},
```

After a successful placement, the demo calls the existing `goToPOI(anchorId)` bridge method (see `goto-poi`) so that the anchor's floor — and therefore the label — is actually displayed.

Each action is a `requestId`-correlated request/response round trip (same pattern as `dynamic-poi-crud` and `3d-icon-marker`): `textLabelPlaced` / `textLabelUpdated` / `textLabelRemoved`, each with `success` and, on failure, an `error` code (`textRequired`, `notFound`, `noPosition`, `noLabel`, or `sdk` with the SDK's own `message`).

The real SDK surface, on `Venue` (`Venue.ts`), `LabelCreateOptions` and `LabelUpdateOptions`:

```ts
createLabel(options: LabelCreateOptions): Label;
updateLabel(label: Label, options: LabelUpdateOptions): void;
removeLabel(label: Label): void;

interface LabelCreateOptions {
  readonly poi: POI;            // owner, must belong to this venue
  readonly position: Position;  // WGS84: { latitude, longitude, altitude? }
  readonly width: number;       // meters
  readonly height?: number;     // meters, defaults to width
  readonly text: string;        // required, non-empty
  readonly color?: Color;       // hex, rgb() or hsl()
  readonly rotation?: number;   // degrees, relative to the map's orientation
}

interface LabelUpdateOptions {
  readonly position?: Position;
  readonly width?: number;      // alone, updates width AND height
  readonly height?: number;     // alone, has no effect
  readonly text?: string;
  readonly isVisible?: boolean;
  readonly color?: Color;
  // no rotation
}
```

## Things to know

- **Always pass `height` to `createLabel`.** It is optional and defaults to `width`, which gives a square box: the text is fitted into it and comes out huge or wrapped. For a one-line text, use a wide, short box (e.g. 16 × 3 m).
- **Always send `width` and `height` together to `updateLabel`.** `updateLabel(label, { width })` alone also sets `height = width` (documented in `LabelUpdateOptions`), garbling the text; `{ height }` alone has no effect.
- **`rotation` is create-only.** It exists in `LabelCreateOptions` but not in `LabelUpdateOptions`. To rotate a placed label, `removeLabel()` it and `createLabel()` again with the same values and the new rotation. Passing `rotation` to `updateLabel` anyway does rotate the rendering, but `label.rotation` keeps reporting the old value — undocumented, don't rely on it.
- **Validation errors are thrown synchronously.** An empty `text` throws `Cannot create Label, text is required`; a `color` that isn't hex / `rgb()` / `hsl()` (e.g. `'red'`) throws `Invalid color format provided, it should be hex color, rgba color or hsl color.` (alpha is ignored). Wrap the calls in try/catch.
- **A removed label is no longer registered.** A second `removeLabel()`, or an `updateLabel()` after removal, throws `Provided label is not registered` — forget your reference once removed.
- **The label belongs to the anchor POI.** `createLabel` appends it to `poi.labels`, next to the map's own label, which it doesn't alter. `removeLabel` only removes yours; `removePOI` on the owner would remove every visual element attached to it, yours included.
- **The anchor's floor must be displayed.** A label is attached to its owner POI's floor and only renders while that floor is shown — not from the default global view of a multi-building venue. Move the camera to the anchor (`view.goToFloor(poi.floor)` then `view.goToPOI(poi)`) after placing it.
- **Text is fitted inside `width × height`** (meters, so the on-screen size follows the camera zoom); a long text wraps to two lines.
- **Offset the position** if you anchor on a POI that already has a label: copying its position as-is draws your text right on top of it. A small lat/lng offset (here +0.00004°, ≈ 4 m) keeps both readable.
- A POI with neither `labels[0]` nor `markers[0]` has no position to copy — report it as an explicit "no position" state rather than passing `undefined` to `createLabel`.

## Learn more

- [`dynamic-poi-crud.md`](dynamic-poi-crud.md): `createLabel` / `updateLabel` used to give a runtime-created POI a visible footprint, with the same anchor-position helper.
- [`3d-icon-marker.md`](3d-icon-marker.md): the image counterpart (`createImage` / `updateImage` / `removeImage`).
- [`goto-poi.md`](goto-poi.md): `view.goToPOI()`, used here to bring the anchor's floor into view.
