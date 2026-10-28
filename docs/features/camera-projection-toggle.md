# Camera projection

## Description

Switches the map between a 3D **perspective** camera (the default) and a flat **orthographic** camera (parallel projection, no foreshortening — buildings keep the same size whatever their distance to the camera). It is built on the `cameraProjection` option of `visioOne.createView()` (`'perspective' | 'orthographic'`) and on the read-only `view.cameraProjection` property, which reports the projection the view was actually created with.

Because the projection can only be chosen when the view is created, switching it means recreating the map: the demo tears down the current view and venue, reloads the venue and creates a new view with the requested projection.

## SDK usage

Native side — a single bridge call; the answer comes back as the usual `loading` then `ready` / `error` bridge messages, with `ready` now carrying the projection reported by the SDK:

```dart
// lib/features/camera-projection-toggle/camera_projection_toggle_bridge.dart
extension CameraProjectionToggleBridge on VisioOneController {
  Future<void> setCameraProjection(String projection) => send('setCameraProjection', [projection]);
}
```

JS side — `assets/www/features/camera-projection-toggle.js` replays the map setup (`MapBridge.setup`, in `assets/www/bridge/core.js`) with the same map hash / `baseURL` / view options, plus `cameraProjection`; `setup` uses this exact sequence:

```js
// assets/www/features/camera-projection-toggle.js
setCameraProjection: function (projection) {
  var last = core.lastSetup;
  if (!last) return;
  var options = Object.assign({}, last.viewOptions || {}, { cameraProjection: projection });
  window.MapBridge.setup(last.hash, last.baseURL, options, last.authorizationToken);
},

// assets/www/bridge/core.js, inside setup(hash, baseURL, viewOptions, authorizationToken):
runHooks(resetHooks); // every feature forgets the SDK objects it created (core.onReset)
Promise.resolve()
  .then(function () { if (oldView) return visioOne.destroyView(oldView); })   // 1. destroy the view
  .then(function () { if (oldVenue) return visioOne.unloadVenue(oldVenue); }) // 2. unload the venue
  .then(function () { return visioOne.loadVenue({ vg_maphash: hash }, container); }) // 3. reload it
  .then(function (v) {
    venue = v;
    return visioOne.createView(container, venue, viewOptions); // 4. { cameraProjection: ... }
  })
  .then(function (createdView) {
    view = createdView;
    runHooks(viewCreatedHooks, view); // features re-register their view listeners (core.onViewCreated)
    sendToNative('ready', { cameraProjection: view.cameraProjection });
  });
```

Creating a view directly in orthographic mode needs nothing more than the option:

```js
const view = await visioOne.createView(container, venue, { cameraProjection: 'orthographic' });
console.log(view.cameraProjection); // 'orthographic'
```

## Things to know

- **Creation-time only.** `cameraProjection` is an option of `createView` (default `'perspective'`). `view.cameraProjection` is read-only: there is no setter and no way to switch the projection of a live view.
- **URL parameter override.** A page-URL parameter `?orthographic` (presence only, no value) forces an orthographic view and takes precedence over the `cameraProjection` option (the SDK resolves options as "URL parameter > options passed to `createView` > default"). It is an alternative for a page that is always orthographic, but it is not a good fit for a toggle — read `view.cameraProjection` rather than assuming the option you passed was applied.
- **Don't recreate the view on the same venue.** `await visioOne.destroyView(view)` followed by `visioOne.createView(container, sameVenue, { cameraProjection: 'orthographic' })` fails in SDK 1.1.0: an unhandled `Error: Cannot fetch model` is thrown and the returned promise never resolves (black map). The working sequence is `await destroyView(view)` → `await unloadVenue(venue)` → `venue = await loadVenue({ vg_maphash, ... })` → `view = await createView(container, venue, { cameraProjection })`, as above.
- **Switching is a full map reload.** Expect a visible reload (several seconds on the iOS simulator in this demo). Everything attached to the old view and venue is lost: event listeners (`poiclick`, `currentfloorchanged`, tracking events...), runtime POIs, labels, images, markers and navigation traces, the camera position and the selected floor. Re-register listeners on the new view and restore whatever state your app needs once `createView` resolves.
- **No sky in orthographic: the canvas is transparent.** In SDK 1.1.0 the perspective view draws a light sky behind the venue, but the orthographic view draws none and leaves the WebGL canvas transparent, so your page/container background shows through around the map (verified by giving the page a red background: the area around the map turned red in orthographic only). Give the map container the background color you want. The orthographic view also opens much more zoomed out, with the whole venue in frame.
- Calls made on the view while it is being recreated have nothing to act on — wait for the new view before sending commands.

## Learn more

- [Custom map server](custom-base-url.md) — another load-time option (`loadVenue`'s `baseURL`) that also requires a full reload to change.
- [Custom theme](custom-theme.md) — another `createView` option (`enableShadows`).
