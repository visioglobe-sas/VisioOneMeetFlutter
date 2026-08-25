# Reset View

## Description

Recenters the camera on the venue's global overview via `view.goToGlobal()` — a `View` method that takes no arguments.

## SDK usage

```dart
// lib/visio_one/visio_one_controller.dart
Future<void> goToGlobal() => _run('window.MapBridge.goToGlobal()');
```

```js
// window.MapBridge, JS side (assets/www/map.html)
goToGlobal: function () {
  if (view) view.goToGlobal();
},
```

`view` is the object resolved from `visioOne.createView(container, venue)` once the map has loaded — keep a reference to it, since most `View` methods (including this one) are called directly on it.

## Things to know

- `view.goToGlobal()` does nothing (and throws nothing) if `view` isn't initialized yet — guard any call site with a `view` truthiness check, or ensure it only runs once the map is confirmed ready.
- Takes no arguments — no JSON-encoding needed for this call, unlike SDK calls that take structured data.
- The camera animates back to the overview immediately when called; there's no callback or event to await for completion.

## Learn more

See `docs/COMMUNICATION_GUIDE.md` in this repo for the full bridge contract (`window.MapBridge` / `VisioOneController`).
