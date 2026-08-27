# Native UI Replacement

## Description

Hides the SDK's own built-in floor selector (a UI part named `floorSelector`, see `ui-part-visibility`) via `view.setUIPartVisible('floorSelector', false)`, and shows that the app's existing native floor/building picker — the one built for `floor-selector` — is, on its own, a complete and fully-functional replacement.

This feature reuses `floor-selector`'s native picker as-is (same `FloorSelectorOverlay` widget, same `goToFloor`/`getVenueLayout` calls) rather than reimplementing floor switching; see `floor-selector` for that call's SDK usage. The only thing this feature adds is a second toggle that reveals the SDK's own `floorSelector` UI part again, so both controls can be compared side by side while driving the same floor state — kept in sync the same way `floor-selector` already is, by listening for `currentfloorchanged`.

## SDK usage

```js
// window.MapBridge, JS side (assets/www/map.html) — already present for `ui-part-visibility`
setUIPartVisible: function (part, visible) {
  if (!view) return;
  view.setUIPartVisible(part, visible);
},
```

```dart
// lib/visio_one/visio_one_controller.dart — already present for `ui-part-visibility`
Future<void> setUIPartVisible(String part, bool visible) =>
    _call('setUIPartVisible', [part, visible]);
```

`part` is `'floorSelector'` here — one of the 5 exact, case-sensitive `UIPart` values the SDK accepts (see `ui-part-visibility`). This demo calls it with `false` as soon as the map is ready (before the visitor does anything), and with `true`/`false` again whenever the "Show SDK's own floor selector" toggle is flipped.

## Things to know

- `setUIPartVisible` only affects the SDK's own default-rendered UI; it has no effect on any native control an app builds itself. Hiding `floorSelector` does not disable `view.goToFloor`/`view.goToBuilding` — those keep working identically regardless of the SDK widget's visibility, which is what makes a full native replacement possible in the first place.
- Both floor-selector UIs — the SDK's own and the app's native one — react to the same `currentfloorchanged` event, so toggling the SDK widget back on mid-session shows it already in sync with whatever floor the native picker last selected (and vice versa); there's no extra state to reconcile between the two.
- See `floor-selector`'s own "Things to know" for the underlying `goToFloor`/`getVenueLayout` caveats (no floor/building name exposed by the SDK, fails silently on an unknown ID, floors not pre-sorted) — none of that changes here, since this feature doesn't touch that call, only the SDK widget's visibility around it.

## Learn more

- `ui-part-visibility` — the general-purpose `setUIPartVisible` toggle panel this feature's single toggle is a focused instance of.
- `floor-selector` — the native picker and its `goToFloor`/`getVenueLayout` calls, reused here unchanged.
