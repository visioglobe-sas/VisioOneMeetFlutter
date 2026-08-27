# Explore Mode

## Description

Drives the SDK's 3 building-exploration modes via `view.currentExploreMode` — a settable property, not a method — and keeps a native panel's active option in sync with the SDK's own state via the `exploremodechanged` event. `'building'` mode is the flagship visual effect of this demo: it presents every opened building's floors as an exploded "carousel" view, a high-impact effect for a sales demo or kiosk.

## SDK usage

```js
// window.MapBridge, JS side (assets/www/map.html)
setExploreMode: function (mode) {
  if (!view) return;
  view.currentExploreMode = mode;
},

// Request/response, no requestId (there's only ever one current explore
// mode to answer for) — same pattern as getVenueLayout / venueLayout.
getExploreMode: function () {
  if (!view) return;
  sendToNative('exploreMode', { currentExploreMode: view.currentExploreMode });
},
```

```js
// window.MapBridge, JS side — registered once per view, alongside the
// existing 'currentfloorchanged' listener
v.addEventListener('exploremodechanged', function (event) {
  sendToNative('exploreModeChanged', { currentExploreMode: event.currentExploreMode });
});
```

```dart
// lib/visio_one/visio_one_controller.dart
Future<void> setExploreMode(String mode) => _call('setExploreMode', [mode]);

Future<void> getExploreMode() => _run('window.MapBridge.getExploreMode()');
```

`mode` is one of the 3 exact, case-sensitive `ExploreMode` string values the SDK accepts: `'global'`, `'building'`, `'floor'` (`ExploreMode.ts` in the `@visioglobe/visioone` package). `getExploreMode()` is fire-and-forget on the Dart side; its result arrives asynchronously as an `exploreMode` message (`{currentExploreMode}`) on `VisioOneController.messages`. Live changes — from this call or from any other source — arrive the same way as an `exploreModeChanged` message with the same shape.

## Things to know

- **The 3 modes' actual semantics** (from `ExploreMode.ts`):
  - `'global'` — the normal outside view. While the camera is outside, moving it in/out of a building opens/closes that building. While navigating a specific floor, moving the camera outside that floor closes the building.
  - `'building'` — the outside is hidden and every currently opened building is presented as a "carousel": the active floor within a building can be picked with the mouse wheel or by sliding the pointer up/down. A click on the screen switches to `'floor'` mode, making the floor under the pointer the new "current" floor.
  - `'floor'` — only the current floor is displayed; the SDK's own UI is expected to offer a way back to `'building'` mode.
- **`'building'` mode auto-transitions to `'floor'` mode on click.** This is a real state change the SDK makes on its own, not something the app requests — a native panel showing the active mode must listen for `exploremodechanged` rather than assume it only changes on its own button taps, exactly like `floor-selector`'s `currentfloorchanged` situation.
- **Camera movement alone can change the mode in `'global'`.** Opening/closing a building by moving the camera in/out of it is a mode-relevant interaction too, even though it doesn't look like an explicit mode switch from the visitor's point of view.
- **`currentExploreMode` is a plain settable property, not an async method** — unlike `goToFloor`/`goToBuilding` (which return an `AnimationPromise`), assigning it triggers the SDK's own transition animation and eventually fires `exploremodechanged`; there's no promise to await and no separate native-side confirmation message for the assignment itself.
- **No documented precondition on `'building'` mode.** The SDK does not appear to require an already-opened building before switching to `'building'` mode — but the effect is most visible (and the actual demo purpose of this mode) when at least one building is open, so a scripted demo flow should open a building (e.g. via `goToFloor`/`goToBuilding`, or simply by moving the camera over one in `'global'` mode) before switching to `'building'` mode for the full "wahou" effect.

## Learn more

- `floor-selector` — the sibling feature that established the "listen to the SDK event to keep a native control in sync with state the SDK itself can change" idiom this feature reuses (`currentfloorchanged` there, `exploremodechanged` here).
