# Clickable surface

## Description

Makes a POI's surface(s) interactive via `venue.updateSurface(surface, { isInteractive: true, ... })`. Once interactive, the SDK itself handles hover/tap visual feedback on the rendered surface — swapping between a base color, a hover color, and a selection color — with no click listener needed on the app side. This is the base building block for any "availability" use case (a free/occupied room, a parking spot): the app only needs to flip `isInteractive` on/off; the SDK manages the color swap when the surface itself is tapped on the map.

## SDK usage

```dart
// lib/visio_one/visio_one_controller.dart
Future<void> setSurfaceInteractive(String placeId, bool interactive) =>
    _call('setSurfaceInteractive', [placeId, interactive]);
```

```js
// window.MapBridge, JS side (assets/www/map.html)
setSurfaceInteractive: function (placeId, interactive) {
  if (!venue) return;
  var poi = venue.pois.find(function (p) { return p.id === placeId; });
  if (!poi) return;
  poi.surfaces.forEach(function (surface) {
    venue.updateSurface(
      surface,
      interactive
        ? { isInteractive: true, color: '#2ECC71', hoverColor: '#F1C40F', selectionColor: '#E74C3C' }
        : { isInteractive: false, color: 'initial' },
    );
  });
},
```

`placeId` is resolved via `venue.pois.find(p => p.id === placeId)`, same as `goto-poi`/`occupancy-simulated`. `venue.updateSurface` is called once per surface of the matched POI (`poi.surfaces.forEach`) — a POI can have more than one surface, and each needs its own call.

The relevant `SurfaceUpdateOptions` fields:

- `isInteractive: boolean` — `true` makes the surface clickable/hoverable; the SDK owns the resulting color swap entirely, no `poiclick`/pointer event handling required on the app side for this visual behavior.
- `color: Color | 'initial'` — the surface's base/idle color. `'initial'` resets it to whatever color the map bundle originally defined for it — used here when disabling interactivity, so the surface doesn't stay stuck on the custom color set while it was interactive.
- `hoverColor: Color | 'default'` — color shown while the pointer hovers the surface. Mostly a desktop/mouse concept; harmless to set on a touch-only target, just generally not observable there.
- `selectionColor: Color | 'default'` — color shown while the surface is in the SDK's clicked/selected state. This is the part that's actually visible on a touch device: tapping the surface on the map flips it to this color automatically.

## Things to know

- **`placeId` must be a real POI ID from the loaded map.** `venue.pois.find(...)` fails silently (no error surfaced) if the ID doesn't match anything, same as `goto-poi`/`occupancy-simulated`.
- **The SDK, not the app, owns the hover/tap coloring.** Once `isInteractive: true` is set, no `poiclick`/pointer listener is needed to get the color swap — it's a purely SDK-managed rendering behavior tied to the surface's interactive state. Listening for taps (e.g. via the `poiclick` view event, see `poi-click`) is only needed if the app wants to *react* to the tap (open a panel, trigger a booking flow, etc.) — the visual feedback itself doesn't depend on that.
- **Disabling interactivity should reset `color` to `'initial'`, not omit it.** Passing `{ isInteractive: false }` alone turns off interactivity but leaves whatever custom `color` was last applied in place; `'initial'` is the special value that restores the color the map bundle originally authored for that surface, not a hardcoded fallback.
- **This is a base primitive, not a full availability feature.** It only toggles interactivity + the three colors; a real "room/parking availability" feature would combine this with a real data source driving `color` per status (free/occupied/reserved), similar in spirit to `occupancy-simulated`'s `venue.updateSurface(surface, { color })` calls but with `isInteractive: true` added so the surface also responds to taps.

## Learn more

See `docs/features/occupancy-simulated.md` for the sibling `venue.updateSurface` call that only changes `color` (no interactivity), and `docs/features/goto-poi.md` / `docs/features/poi-click.md` for the other POI-lookup and tap-handling patterns this feature builds on.
