# Accessible Mode

## Description

Computes a route the same way as [`compute-navigation`](./compute-navigation.md), but sets `isAccessible: true` on `venue.computeNavigation()` so the routing algorithm only returns a route usable by a visitor who can't take stairs — e.g. rerouting through a lift/ramp instead of a stairway. This is the opposite direction from [`navigation-exclude-modalities`](./navigation-exclude-modalities.md), which excludes a specific tag (e.g. `'lift'`) to force a detour *away* from it; `isAccessible: true` instead steers *toward* the venue's accessible path.

## SDK usage

```js
// window.MapBridge, JS side (assets/www/map.html) — already existing, unchanged
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
// lib/visio_one/visio_one_controller.dart — already existing, unchanged
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

No new bridge method was needed for this feature: `isAccessible` was already a first-class parameter of `startItinerary`/`window.MapBridge.startItinerary`, forwarded straight into `venue.computeNavigation({ ..., isAccessible })` (added alongside [`compute-navigation`](./compute-navigation.md) and reused as-is by [`navigation-exclude-modalities`](./navigation-exclude-modalities.md)) — this demo's `AccessibleModeOverlay` just reads a switch and passes its value through to the existing call.

`isAccessible?: boolean` (`NavigationRequest`, default `false`) is documented by the SDK's own JSDoc as: "If set to true, computed route will only use accessible route." Internally, this excludes the venue's own published accessible-route attributes/modalities list from the routing graph — the mirror image of what [`navigation-exclude-modalities`](./navigation-exclude-modalities.md) does with an explicit `excludedAttributes` list, except here the excluded set is picked automatically by the SDK from data authored in VisioMapEditor, not passed by the caller.

## Things to know

- **The excluded attribute/modality list behind `isAccessible` is venue-defined, not a fixed SDK constant, and there's no public getter to read it.** It corresponds to whatever a venue's `accessibleRouteAttributes`/`accessibleRouteModalities` were set to when the map was authored/published in VisioMapEditor — discoverable only empirically (compare a route with and without `isAccessible: true`), not by inspecting SDK types or calling a `venue.*` accessor.
- **Confirmed live on the shared demo venue** (`B4-UL00-ID0010` → `B4-UL01-ID0014`, building B4, floor UL0 → UL1): `venue.computeNavigation({ origin, destination })` (no `isAccessible`) returns a route with a segment tagged `attributes: ['stairway', 'B4-stairs2']`; the same call with `isAccessible: true` returns a genuinely different route entirely through a segment tagged `attributes: ['lift', 'B4-lift1']` — no stairway segment anywhere. This venue was sampled across roughly 15 floor-crossing origin/destination pairs and only ever showed `'stairway'` tags on its non-accessible routes, never `'escalator'`.
- **When no accessible route exists between the two POIs, this fails exactly like an ordinary unreachable pair.** Same as [`compute-navigation`](./compute-navigation.md) and [`navigation-exclude-modalities`](./navigation-exclude-modalities.md): `venue.computeNavigation` throws on the JS side and that throw isn't caught or surfaced back to native code — the map simply keeps showing no new trace, with no explicit signal distinguishing "unreachable because of `isAccessible`" from "these two places were never connected at all."
- `isAccessible` is read once per call, like every other option in this request — toggling the "Accessible route" switch after a route is already displayed has no effect on that already-computed trace; a new `startItinerary` call is required to pick up the change.

## Learn more

- See [`compute-navigation`](./compute-navigation.md) for the base `Navigation`/`NavigationTrace` computation and display flow that this feature builds on.
- See [`navigation-exclude-modalities`](./navigation-exclude-modalities.md) for the opposite-direction feature: explicitly excluding a segment tag (e.g. `'lift'`) instead of requesting the venue's accessible route.
