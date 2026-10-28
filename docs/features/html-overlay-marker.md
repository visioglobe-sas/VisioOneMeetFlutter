# HTML overlay marker

## Description

Pins an HTML element (here a small badge, e.g. `Open now · 12:00–14:00`) on the map at a geographic position, with `venue.createMarker({ poi, position, element })`. Unlike a `Label` or an `Image`, which live inside the 3D scene, an HTML marker is drawn **above** it: it always faces the screen, keeps a constant on-screen size, and is never hidden by walls or other 3D geometry. And because it is plain DOM, it is **interactive**: a tap on the badge is caught in JavaScript and forwarded to the Dart side over the bridge. It is shown/hidden with `venue.updateMarker(marker, { isVisible })` and removed with `venue.removeMarker(marker)`.

## SDK usage

```dart
// lib/features/html-overlay-marker/html_overlay_marker_bridge.dart
extension HtmlOverlayMarkerBridge on VisioOneController {
  Future<Map<String, Object?>?> placeHtmlBadge({required String anchorId, required String text}) =>
      request('placeHtmlBadge', [anchorId, text]);

  Future<Map<String, Object?>?> updateHtmlBadgeText(String text) => request('updateHtmlBadgeText', [text]);

  Future<Map<String, Object?>?> setHtmlBadgeVisible(bool visible) => request('setHtmlBadgeVisible', [visible]);

  Future<Map<String, Object?>?> removeHtmlBadge() => request('removeHtmlBadge');
}
```

Each call is a `requestId`-correlated request/response round trip, answered by an `htmlBadgePlaced` / `htmlBadgeUpdated` / `htmlBadgeRemoved` message with `success` and, on failure, an `error` code (`textRequired`, `notFound`, `noPosition`, `noBadge`, or `sdk` with the SDK's own `message`). Taps on the badge arrive unsolicited as `htmlBadgeTapped` messages carrying a running `count`:

```dart
controller.messages.where((m) => m.type == 'htmlBadgeTapped').listen((m) {
  final count = (m.data as Map)['count'] as int;
  // react in your Flutter UI
});
```

The SDK's `Marker` object and its DOM element can't cross the bridge, so the JS side keeps them:

```js
// assets/www/features/html-overlay-marker.js — the feature's own state, cleared in core.onReset(...)
// (`core` = window.MapCore; `venue` / `view` = core.venue / core.view)
var htmlBadge = null;
var htmlBadgeTapCount = 0;

// Shared helpers, in assets/www/bridge/core.js (core.poiDisplayPosition / core.resolveAnchor).
// Display position of a POI, same priority everywhere in this repo: first label,
// else first image or marker, else the centre of its first surface.
// `ignored`: objects created by the demos themselves, never used as a source.
function poiDisplayPosition(poi, ignored) {
  var skip = ignored || [];
  function first(list) { return list.filter(function (o) { return skip.indexOf(o) === -1; })[0]; }
  var source = first(poi.labels) || first(poi.images) || first(poi.markers);
  if (source) return source.position;
  var surface = poi.surfaces[0];
  if (!surface || !surface.positions.length) return null;
  var lat = 0, lng = 0;
  surface.positions.forEach(function (p) { lat += p.latitude; lng += p.longitude; });
  return { latitude: lat / surface.positions.length, longitude: lng / surface.positions.length };
}

// Resolve an existing anchor POI and the position to copy from it.
function resolveAnchor(anchorId) {
  var poi = venue.pois.find(function (p) { return p.id === anchorId; });
  if (!poi) return { error: 'notFound' };
  var position = poiDisplayPosition(poi, demoCreatedObjects()); // objects declared with core.registerCreatedObjects
  if (!position) return { poi: poi, error: 'noPosition' };
  return { poi: poi, position: position };
}

// The feature's commands, in assets/www/features/html-overlay-marker.js, inside core.register({ ... }):

placeHtmlBadge: function (requestId, anchorId, text) {
  // 1. Validate everything first: a failed placement leaves the current badge untouched.
  if (!text || !String(text).trim()) { /* reply error: 'textRequired' */ return; }
  var anchor = core.resolveAnchor(anchorId);   // error: 'notFound' | 'noPosition'
  // ... report anchor.error
  var position = {
    latitude: anchor.position.latitude + 0.00004,   // ~4 m offset, so the badge doesn't
    longitude: anchor.position.longitude + 0.00004, // cover the POI's own label
  };
  if (anchor.position.altitude !== undefined) position.altitude = anchor.position.altitude;

  // 2. Build the element. Style its look only — the SDK owns its position/transform.
  var element = document.createElement('div');
  element.setAttribute('style',
    'background:#0B6BCB;color:#FFFFFF;font:600 14px sans-serif;padding:6px 12px;' +
    'border-radius:14px;white-space:nowrap;box-shadow:0 2px 6px rgba(0,0,0,.3);cursor:pointer');
  element.textContent = text;

  // 3. Only now replace: one badge at a time.
  if (htmlBadge) {
    venue.removeMarker(htmlBadge);
    htmlBadge = null;
  }
  var marker = venue.createMarker({ poi: anchor.poi, position: position, element: element });
  element.style.pointerEvents = 'auto';            // the SDK sets 'none' at creation
  element.addEventListener('click', function (event) {
    event.stopPropagation();                       // don't let the tap reach the map
    htmlBadgeTapCount += 1;
    core.sendToNative('htmlBadgeTapped', { count: htmlBadgeTapCount });
  });
  htmlBadge = marker;
  htmlBadgeTapCount = 0;
},

updateHtmlBadgeText: function (requestId, text) {
  // ... 'noBadge' / 'textRequired', then a plain DOM edit — no SDK call:
  htmlBadge.element.textContent = text;
},

setHtmlBadgeVisible: function (requestId, visible) {
  venue.updateMarker(htmlBadge, { isVisible: visible });
},

removeHtmlBadge: function (requestId) {
  // ... 'noBadge' if nothing is placed (the SDK would throw "Provided marker is not registered"), else:
  venue.removeMarker(htmlBadge);   // also detaches the element from the DOM
  htmlBadge = null;
},
```

(The real code also wraps the SDK calls in try/catch and reports failures as `error: 'sdk'`.) After a successful placement, the demo calls the existing `goToPOI(anchorId)` bridge method (see `goto-poi`) so that the anchor's floor — and therefore the badge — is actually displayed.

The real SDK surface, on `Venue`:

```ts
createMarker(options: MarkerCreateOptions): Marker;
updateMarker(marker: Marker, options: MarkerUpdateOptions): void;
removeMarker(marker: Marker): void;

// HTML marker flavor of MarkerCreateOptions
{
  poi: POI;              // owner, must belong to this venue
  position: Position;    // WGS84: { latitude, longitude, altitude? }
  element: HTMLElement;  // required for an HTML marker
}

interface MarkerUpdateOptions {
  position?: Position;
  isVisible?: boolean;
}
```

## Things to know

- **`element` is required.** `createMarker` without it throws `Cannot createMarker, invalid element provided, options.element is missing`.
- **The SDK owns the element's layout.** It moves the element into its own overlay container and sets `position: absolute; top: 0; left: 0; translate: -50% -50%` (the element is **centered** on the position), a per-frame `transform: translate(x, y)` and a `z-index`. Don't set `position`, `top`/`left`, `translate` or `transform` on the element yourself — wrap your content in a child element if you need your own transforms.
- **It isn't tappable by default.** The SDK sets `pointer-events: none` on the element at creation, so taps go through it to the map (and open the POI card underneath). Set `element.style.pointerEvents = 'auto'` right after `createMarker`; the SDK doesn't rewrite it afterwards (including after camera moves).
- **Stop the event in your handler.** Call `event.stopPropagation()` in the `click` listener, otherwise the tap also reaches the map and fires `poiclick` on the POI below the badge.
- **Drawn above the 3D scene.** It is never occluded by walls or other geometry and stays readable at any camera pitch — the difference with `createLabel` / `createImage`.
- **Only displayed on its POI's floor.** While another floor is displayed, the SDK sets `display: none` on the element. Move the camera to the anchor (`view.goToFloor(poi.floor)` then `view.goToPOI(poi)`) after placing it.
- **`updateMarker` only accepts `position` and `isVisible`.** `isVisible: false` sets `display: none`; the element stays in the DOM. Content changes are plain DOM edits on `marker.element` — it is a live node, no SDK call needed.
- **A removed marker is no longer registered.** `removeMarker` detaches the element from the DOM; a second `removeMarker()`, or an `updateMarker()` after removal, throws `Provided marker is not registered` — forget your reference once removed.
- **The marker belongs to the anchor POI.** `createMarker` appends it to `poi.markers`. If you later copy a position from that POI's markers (as `resolveAnchor` does when the POI has no label or image), skip your own marker, or you would get your badge's offset position instead of the map's data.
- **Validate before replacing.** Check the text and resolve the anchor before `removeMarker()`-ing the badge you already placed, so that a rejected placement (blank text, unknown POI, no position) leaves the current badge on the map.

## Learn more

- `isForeignMarker` and the `foreignmarkerupdated` view event: the SDK variant for positioning a *native* (non-DOM) view yourself from screen coordinates the SDK computes — not demonstrated here.
- [`custom-text-label.md`](custom-text-label.md): free text drawn *inside* the 3D scene (`createLabel`), with the same anchor-position helper.
- [`3d-icon-marker.md`](3d-icon-marker.md): an image drawn inside the 3D scene (`createImage`).
- [`goto-poi.md`](goto-poi.md): `view.goToPOI()`, used here to bring the anchor's floor into view.
