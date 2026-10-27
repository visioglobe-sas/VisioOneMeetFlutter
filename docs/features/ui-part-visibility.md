# UI Part Visibility

## Description

Shows or hides individual parts of the built-in overlay UI that the VisioOne SDK draws on top of the map, via `view.setUIPartVisible(uiPart, isVisible)`.

## SDK usage

```js
// assets/www/features/ui-part-visibility.js, inside core.register({ ... })
// (`core` = window.MapCore; `venue` / `view` = core.venue / core.view)
setUIPartVisible: function (part, visible) {
  if (!view) return;
  view.setUIPartVisible(part, visible);
},
```

```dart
// lib/features/ui-part-visibility/ui_part_visibility_bridge.dart
extension UiPartVisibilityBridge on VisioOneController {
  Future<void> setUIPartVisible(String part, bool visible) => send('setUIPartVisible', [part, visible]);
}
```

There are exactly 5 valid `uiPart` values, case-sensitive (type `UIPart` in the SDK's typings): `floorSelector`, `navigation`, `poiDetails`, `search`, `userTracking`.

## Things to know

- **Only call this once the view is ready.** Like the rest of this bridge's Native -> JS surface, `setUIPartVisible` silently no-ops (`if (!view) return;`) if called before `view` exists.
- **The 5 `uiPart` values are exact and case-sensitive** — no `snake_case` or `PascalCase` variants, no 6th value. A typo fails silently on the JS side (the SDK ignores an unrecognized value) without surfacing any error to native code, so the toggle simply has no visible effect.
- **Hiding `search` or `navigation` removes the only way to trigger those SDK flows from the default map UI** (no keyboard POI search, no route drawn from the SDK's own navigation UI). If you hide either permanently in a real integration, provide a replacement UI first (your own search field, your own itinerary button — see `goto-poi`/`compute-navigation`/`floor-selector` for examples of driving the same SDK flows from custom native UI).

## Learn more

Related: `floor-selector` demonstrates the overlap between a native SDK UI part (`floorSelector`) and a custom host-app panel — useful if you want to hide the SDK's built-in floor selector once your own panel is in place.
