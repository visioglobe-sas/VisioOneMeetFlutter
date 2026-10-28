# Reset View

## Description

Recenters the camera on the venue's global overview via `view.goToGlobal()` — a `View` method that takes no arguments.

## SDK usage

```dart
// lib/features/reset-view/reset_view_bridge.dart
extension ResetViewBridge on VisioOneController {
  Future<void> goToGlobal() => send('goToGlobal');
}
```

```js
// assets/www/features/reset-view.js, inside core.register({ ... })
// (`core` = window.MapCore; `venue` / `view` = core.venue / core.view)
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
