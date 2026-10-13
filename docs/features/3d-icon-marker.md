# 3D icon marker

## Description

Places a custom image (here a 96×96 PNG icon passed as a data URL) at a precise spot on the 3D map, above an existing POI — `venue.createImage()` / `venue.updateImage()` / `venue.removeImage()`. The image's orientation behavior (`'fixed'`, `'flat'`, `'facing'`) can be switched live on an image that is already placed.

## SDK usage

```dart
// lib/visio_one/visio_one_controller.dart
Future<void> placeIconImage(
  String requestId, {
  required String imageId,
  required String anchorId,
  required String url,
  required String orientationType,
}) => _call('placeIconImage', [requestId, imageId, anchorId, url, orientationType]);

Future<void> updateIconImageOrientation(String requestId, String imageId, String orientationType) =>
    _call('updateIconImageOrientation', [requestId, imageId, orientationType]);

Future<void> removeIconImage(String requestId, String imageId) =>
    _call('removeIconImage', [requestId, imageId]);
```

The SDK's `Image` object can't cross the bridge, so the JS side keeps it in a map keyed by an id chosen on the Dart side:

```js
// window.MapBridge, JS side (assets/www/map.html)
var iconImages = {};

// Shared with dynamic-poi-crud: resolve an existing POI and the position to copy from it.
function resolveAnchor(anchorId) {
  var poi = venue.pois.find(function (p) { return p.id === anchorId; });
  if (!poi) return { error: 'notFound' };
  var source = poi.labels[0] || poi.markers[0];
  if (!source) return { poi: poi, error: 'noPosition' };
  return { poi: poi, position: source.position };
}

placeIconImage: function (requestId, imageId, anchorId, url, orientationType) {
  var anchor = resolveAnchor(anchorId);
  if (anchor.error) {
    sendToNative('iconImagePlaced', { requestId: requestId, success: false, error: anchor.error });
    return;
  }
  var previousRemoved = false;
  try {
    if (iconImages[imageId]) {           // one image at a time: remove the previous one first
      venue.removeImage(iconImages[imageId]);
      delete iconImages[imageId];
      previousRemoved = true;
    }
    iconImages[imageId] = venue.createImage({
      poi: anchor.poi,                   // the anchor POI owns the image
      position: anchor.position,         // WGS84, copied from the anchor's label/marker
      width: 6,                          // meters
      height: 6,                         // meters
      url: url,                          // a data URL works
      orientationType: orientationType,  // 'fixed' | 'flat' | 'facing'
    });
  } catch (error) {
    sendToNative('iconImagePlaced', { requestId: requestId, success: false, error: 'sdk', message: error.message, previousRemoved: previousRemoved });
    return;
  }
  sendToNative('iconImagePlaced', { requestId: requestId, success: true, imageId: imageId, poiId: anchorId });
},

updateIconImageOrientation: function (requestId, imageId, orientationType) {
  // ... look up iconImages[imageId], then:
  venue.updateImage(image, { orientationType: orientationType });
},

removeIconImage: function (requestId, imageId) {
  // ... look up iconImages[imageId], then:
  venue.removeImage(image);
  delete iconImages[imageId];
},
```

After a successful placement, the demo calls the existing `goToPOI(anchorId)` bridge method (see `goto-poi`) so that the anchor's floor — and therefore the image — is actually displayed.

Each action is a `requestId`-correlated request/response round trip (same pattern as `dynamic-poi-crud`): `iconImagePlaced` / `iconImageUpdated` / `iconImageRemoved`, each with `success` and, on failure, an `error` code (`notFound`, `noPosition`, `noImage`, or `sdk` with the SDK's own `message`).

The real SDK surface, on `Venue` (`Venue.ts`), `Image` (`Image.ts`), and `OrientationType` (`OrientationType.ts`):

```ts
createImage(options: ImageCreateOptions): Image;
updateImage(image: Image, options: ImageUpdateOptions): void;
removeImage(image: Image): void;  // throws ImageNotFoundError if the image isn't registered

interface ImageCreateOptions {
  readonly poi: POI;              // required, must belong to this venue
  readonly position: Position;    // WGS84: { latitude, longitude, altitude? }
  readonly width: number;         // meters
  readonly height?: number;       // meters, defaults to width
  readonly rotation?: number;     // degrees, used when orientationType is 'fixed'
  readonly url: string;           // relative to baseURL, absolute, web URL, or data URL
  readonly orientationType?: OrientationType; // defaults to 'facing'
}

interface ImageUpdateOptions {
  readonly position?: Position;
  readonly width?: number;        // alone, updates width AND height
  readonly height?: number;       // alone, has no effect
  readonly rotation?: number;
  readonly url?: string;
  readonly orientationType?: OrientationType;
  readonly isVisible?: boolean;
}

type OrientationType =
  | 'fixed'   // flat on the ground, fixed heading
  | 'flat'    // flat on the ground, rotates to face the camera
  | 'facing'; // always camera-facing (billboard)
```

## Things to know

- **Data URLs work.** A base64 PNG data URL renders with no extra configuration or network request.
- **The anchor's floor must be displayed.** An image is attached to its owner POI's floor and only renders while that floor is shown — not from the default global view of a multi-building venue. Move the camera to the anchor (`view.goToFloor(poi.floor)` then `view.goToPOI(poi)`) after placing it.
- **The owner POI keeps its own images.** `createImage` appends to `poi.images`: a POI that already shows a pictogram from the published map ends up with two images. `removeImage` only removes yours; `removePOI` on the owner would remove every visual element attached to it, yours included.
- **One `Image` per `createImage` call.** Calling it again adds another image instead of replacing the previous one — keep the returned `Image` and `removeImage()` it first if you want only one.
- **Runtime `'flat'`/`'facing'` images require SDK ≥ 1.0.9.** In `@visioglobe/visioone` 1.0.5, an image created at runtime with `'flat'` or `'facing'` was not oriented by the camera (it lay on the ground under the anchor's label); this SDK bug is fixed in 1.0.9. `'fixed'` works on both versions.
- **Validation errors are thrown synchronously.** `createImage` throws `InvalidCreateOptionsError` for a missing/blank `url`, a missing `position` or `width`, a non-positive size, or an unknown `orientationType` (e.g. `updateImage(image, { orientationType: 'bogus' })` throws `Invalid orientation type`), and `POINotFoundError` if `poi` is not part of the venue. Wrap the calls in try/catch.
- **Sizes are in meters.** `width`/`height` are world sizes, so the icon's on-screen size follows the camera zoom.
- A POI with neither `labels[0]` nor `markers[0]` has no position to copy — report it as an explicit "no position" state rather than passing `undefined` to `createImage`.

## Learn more

- [`dynamic-poi-crud.md`](dynamic-poi-crud.md): the same "copy an anchor POI's position" helper, used there to attach a `Label` to a freshly created POI.
- [`goto-poi.md`](goto-poi.md): `view.goToPOI()`, used here to bring the anchor's floor into view.
