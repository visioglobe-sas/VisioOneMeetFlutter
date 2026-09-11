# Custom Navigation Trace

## Description

Restyles the route line drawn by [`compute-navigation`](./compute-navigation.md) with custom colors, via `venue.updateNavigationTrace(navigationTrace, options)` — the same `NavigationTrace` object created by `venue.createNavigationTrace()`, just given a `NavigationTraceUpdateOptions` object afterward.

## SDK usage

```js
const navigation = venue.computeNavigation({ origin: originPoi, destination: destinationPoi });
const trace = venue.createNavigationTrace(navigation);
view.setCurrentNavigationTrace(trace);

venue.updateNavigationTrace(trace, {
  progressColor: '#E53935',
  progressOutlineColor: '#FFFFFF',
  progressFutureColor: '#F8C9C7',
  previewColor: '#F8C9C7',
  previewOutlineColor: '#FFFFFF',
});
```

```dart
// lib/visio_one/visio_one_controller.dart
Future<void> updateNavigationTrace(Map<String, String> options) =>
    _call('updateNavigationTrace', [options]);
```

```js
// window.MapBridge, JS side (assets/www/map.html)
updateNavigationTrace: function (options) {
  if (!venue || !currentNavigationTrace) return;
  try {
    venue.updateNavigationTrace(currentNavigationTrace, options);
  } catch (error) {
    // Colors are already applied by this point — see "Things to know" below.
    console.warn('updateNavigationTrace: SDK threw (colors still applied): ' + (error && error.message ? error.message : String(error)));
  }
},
```

`currentNavigationTrace` is the `NavigationTrace` object stashed by `startItinerary` (the `compute-navigation` bridge method) right after `venue.createNavigationTrace()` — `updateNavigationTrace` needs that object itself, not an ID, and there is no SDK getter to fetch "the currently displayed trace" back. `NavigationTraceUpdateOptions` (`Navigation/NavigationTraceUpdateOptions.d.ts` in the SDK's typings) only exposes colors (plus `textureRepeat`/`animationSpeed`, relevant only to the `'textured'` `displayMode`) — there is no way to change `displayMode` or thickness after creation, and `createNavigationTrace()` itself takes no options, so a trace always starts out in the SDK's own default look.

## Things to know

- **There is no "reset to default" call.** Colors are one-way: once changed, the only way back to the SDK's own look is to re-apply its documented defaults yourself (`Line.color` defaults to `'#0094F0'`, the inactive/preview segment to `'#C5C5C5'` — see the SDK's `Venue/Line.d.ts`). This demo's `visioglobeBlue` preset exists specifically to be that "reset", stated explicitly rather than left implicit.
- **`updateNavigationTrace` can throw internally even on a fully valid trace.** Confirmed live against the real SDK on this app's shared demo venue (not just a code-review assumption): the very first `updateNavigationTrace` call made after a venue loads throws an internal error deep in the SDK's line-rendering pipeline — JavaScriptCore (WKWebView, iOS) reports it as `undefined is not an object (evaluating 'o.children[0].material')`, the same underlying bug V8 reports on the sibling Vue integration as `TypeError: Cannot read properties of undefined (reading 'material')` (different engines, same root cause: something reads `.material` off an object that isn't ready yet). Every color in the `options` object is still applied correctly before it throws. Unlike what the Vue integration's own doc suggests, this did **not** reproduce on *every* call here: only the very first `updateNavigationTrace` call observed after loading the venue threw — three subsequent calls restyling the same trace, and a first call restyling a second, later-created trace in the same session, all completed without throwing. Treat this as data/timing-dependent (something not yet initialized the very first time this code path runs) rather than assuming a fixed rule for when it fires, and keep the `try`/`catch` regardless — the color change is applied before the throw either way, so any throw here is a non-fatal, already-applied change, not a failure signal.
- Colors only affect a trace that already exists — calling `updateNavigationTrace` before `startItinerary`/`createNavigationTrace` has nothing to act on (the bridge above no-ops in that case, see the `!currentNavigationTrace` guard).
- If you want a consistent look across itineraries, re-apply the same options object right after each new trace is created (this demo does so automatically, listening for the `itineraryComputed` message and reapplying the currently selected preset) — a freshly computed itinerary always starts back at the SDK's own default colors, `updateNavigationTrace` never "sticks" across `startItinerary` calls.
- **Field naming is easy to mix up.** Per the typings' own doc comments, `progressColor` is "the color of the active part of the Line" while `progressFutureColor` is "the color for the progress line that has not yet been walked" — two different-sounding descriptions that both plausibly mean "the part still ahead." Read `NavigationTraceUpdateOptions.d.ts`'s comments directly rather than assuming which one controls which segment from the name alone, and verify visually against a real venue.

## Learn more

- See [`compute-navigation`](./compute-navigation.md) for how the `Navigation`/`NavigationTrace` pair is computed and displayed in the first place — this feature only adds a styling call on top of it.
