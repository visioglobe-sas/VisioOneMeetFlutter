# Compute Navigation

## Description

Computes and displays a route between two POIs (origin, destination), via `venue.computeNavigation({ origin, destination, isAccessible, ... })` + `view.setCurrentNavigationTrace(trace)`.

## SDK usage

```js
// window.MapBridge, JS side (assets/www/map.html)
startItinerary: function (args) {
  if (!venue || !view) return;
  var navigation = venue.computeNavigation({
    origin: args.origin,
    destination: args.destination,
    isAccessible: !!args.isAccessible,
    type: 'fastest',
    firstNodeAsIntersection: false,
    mergeFloorChangeInstructions: false,
  });
  var trace = venue.createNavigationTrace(navigation);
  view.setCurrentNavigationTrace(trace);
  sendToNative('itineraryComputed', { instructions: navigation.instructions });
},
```

```dart
// lib/visio_one/visio_one_controller.dart
Future<void> startItinerary({
  required String origin,
  required String destination,
  bool isAccessible = false,
}) {
  return _call('startItinerary', [
    {'origin': origin, 'destination': destination, 'isAccessible': isAccessible},
  ]);
}
```

`origin`/`destination` are Place IDs, not coordinates or display names — the same identifiers used by `goto-poi`. `venue.computeNavigation` returns a navigation result with `instructions`; `venue.createNavigationTrace(navigation)` turns it into a trace object that `view.setCurrentNavigationTrace(trace)` draws on the map.

## Things to know

- **The route is drawn on the map as soon as `setCurrentNavigationTrace` runs** — that's what makes the trace visible; the `itineraryComputed` message sent afterward carries `{ instructions }` (turn-by-turn text) as a separate, optional payload. A caller only interested in the drawn trace can ignore that message entirely; a caller who wants turn-by-turn text should listen for `itineraryComputed` on the message stream.
- **An invalid or unknown Place ID makes `venue.computeNavigation` fail on the JS side** without surfacing an error back to native code — the map simply shows no trace, with no explicit error signal.
- **`isAccessible`** (optional, default `false`) requests an accessible route (e.g. avoiding stairs) when set.
- **`type: 'fastest'`, `firstNodeAsIntersection: false`, `mergeFloorChangeInstructions: false`** are fixed options passed to `computeNavigation` in this example — `computeNavigation` accepts other route-shaping options worth checking in the SDK's type definitions if you need different behavior (e.g. excluding specific modalities).

## Learn more

- Related: `goto-poi` uses the same kind of Place ID as input.
- Related: `floor-selector` shows the request/response pattern to follow if you want to consume `itineraryComputed` (listen on `controller.messages` while the relevant UI is mounted).
