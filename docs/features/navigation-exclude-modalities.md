# Exclude Modalities

## Description

Computes a route the same way as [`compute-navigation`](./compute-navigation.md), but passes `excludedAttributes` to `venue.computeNavigation()` so the routing algorithm ignores any segment carrying one of the given tags — e.g. excluding `'lift'` to force a route that avoids elevators.

## SDK usage

```js
// window.MapBridge, JS side (assets/www/map.html)
startItineraryExcludingModalities: function (args) {
  if (!venue || !view) return;
  var navigation = venue.computeNavigation({
    origin: args.origin,
    destination: args.destination,
    isAccessible: !!args.isAccessible,
    type: 'fastest',
    firstNodeAsIntersection: false,
    mergeFloorChangeInstructions: false,
    excludedAttributes: args.excludedAttributes || [],
  });
  var trace = venue.createNavigationTrace(navigation);
  view.setCurrentNavigationTrace(trace);
  sendToNative('itineraryComputed', { instructions: navigation.instructions });
},
```

```dart
// lib/visio_one/visio_one_controller.dart
Future<void> startItineraryExcludingModalities({
  required String origin,
  required String destination,
  bool isAccessible = false,
  List<String> excludedAttributes = const [],
}) {
  return _call('startItineraryExcludingModalities', [
    {
      'origin': origin,
      'destination': destination,
      'isAccessible': isAccessible,
      'excludedAttributes': excludedAttributes,
    },
  ]);
}
```

`excludedAttributes?: string[]` (`NavigationRequest`, part of the same options object `compute-navigation` already passes to `venue.computeNavigation`) is a plain list of segment-particularity tags — elevator, stairway, intersection, etc. — defined per-segment when the map was authored in VisioMapEditor. Passing a tag that's unused on the venue is a silent no-op (it just excludes nothing), not an error. It's a separate field from `excludedModalities?: string[]` (mode of travel — pedestrian, car, bus...): an elevator is an *attribute*, not a *modality*, so passing `'lift'` inside `excludedModalities` instead would not exclude it.

## Things to know

- **The SDK's own JSDoc for `excludedAttributes` is misleading.** Its doc comment gives `"elevator"` as an example value, but the string value actually tagged on this shared demo venue's elevator segments — confirmed live: `venue.computeNavigation({ origin: 'B1-LL01-ID0013', destination: 'B1-UL02-ID0012' })` returns a route whose single floor-change instruction carries `attributes: ['lift', 'B1-lift-1']`, and re-running the same call with `excludedAttributes: ['lift']` produces a genuinely different, longer route via three separate stairway segments instead — is `'lift'`, not `'elevator'`. Pass `excludedAttributes: ['lift']`.
- **When the exclusion removes every viable path, this bridge method fails exactly like an ordinary unreachable origin/destination pair.** `venue.computeNavigation` throws on the JS side (`RouteNotFoundError`/`SourceOutOfLimitError`/`DestinationOutOfLimitError`, see `Navigation/Errors` in the SDK's typings) and, just like `startItinerary`'s own documented behavior (see [`compute-navigation`](./compute-navigation.md)'s "Things to know"), that throw is not caught here and never surfaces back to native code as an explicit error — the map simply keeps showing no new trace. There is no separate signal distinguishing "excluded modality made this unreachable" from "these two places were never connected in the first place."
- `excludedAttributes` is read once per call — toggling a UI switch after a route is already displayed has no effect on that already-computed trace; a new `startItineraryExcludingModalities` call is required to pick up the change.

## Learn more

- See [`compute-navigation`](./compute-navigation.md) for the base `Navigation`/`NavigationTrace` computation and display flow that this feature builds on.
