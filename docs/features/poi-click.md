# POI Click

## Description

Reacts to the user tapping a POI on the map, surfacing its name and ID, via the SDK's `poiclick` event on `view`.

## SDK usage

```js
// window.MapBridge, JS side (assets/www/map.html), registered once the view is ready
view.addEventListener('poiclick', function (event) {
  var poi = event.pois && event.pois[0];
  if (!poi) return;
  sendToNative('poiSelected', {
    id: poi.id,
    name: poi.labels && poi.labels[0] ? poi.labels[0].text : null,
  });
});
```

The event is forwarded to native code as a `poiSelected` message (`{id, name}`) over the JS -> Native bridge channel:

```dart
// lib/visio_one/visio_one_controller.dart — listening for it
controller.messages.listen((message) {
  if (message.type != 'poiSelected') return;
  final data = message.data;
  final id = data is Map ? data['id'] as String? : null;
  final name = data is Map ? data['name'] as String? : null;
  // ... use id/name
});
```

## Things to know

- **`event.pois[0]`, not `event.pois`**: `poiclick` can in theory report more than one POI if surfaces overlap; this bridge only keeps the first one. Worth revisiting if your target map has overlapping geometry.
- **`name` can be `null`** if the POI has no label (`poi.labels` empty) — don't assume `name` is non-null just because `id` is; fall back to `id` for display if needed.
- **`poiclick` fires on `view`**, so the listener must be registered after `view` exists (i.e. after `createView()` resolves), not before.

## Learn more

- See `docs/COMMUNICATION_GUIDE.md` in this repo (sections 3 and 7) for the full bridge message contract and the procedure for adding a new JS -> Native event.
- Related: `goto-poi` does the reverse — centering the camera on a chosen POI from native code, rather than reacting to a tap coming from the map.
