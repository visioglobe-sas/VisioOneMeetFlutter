# Camera projection

## Description

Switches the map between a 3D **perspective** camera (the default) and a flat **orthographic** camera (parallel projection, no foreshortening — buildings keep the same size whatever their distance to the camera). It is built on the `cameraProjection` option of `visioOne.createView()` (`'perspective' | 'orthographic'`) and on the read-only `view.cameraProjection` property, which reports the projection the view was actually created with.

Because the projection can only be chosen when the view is created, switching it means recreating the map: the demo tears down the current view and venue, reloads the venue and creates a new view with the requested projection.

## SDK usage

Native side — a single bridge call; the answer comes back as the usual `loading` then `ready` / `error` bridge messages, with `ready` now carrying the projection reported by the SDK:

```dart
// lib/visio_one/visio_one_controller.dart
Future<void> setCameraProjection(String projection) =>
    _call('setCameraProjection', [projection]); // 'perspective' | 'orthographic'

// 'ready' message data: { cameraProjection: 'perspective' | 'orthographic' }
```

JS side (`assets/www/map.html`) — the bridge replays the map setup with the same map hash / `baseURL` / view options, plus `cameraProjection`, using this exact sequence:

```js
setCameraProjection: function (projection) {
  var options = Object.assign({}, lastSetup.viewOptions || {}, { cameraProjection: projection });
  window.MapBridge.setup(lastSetup.hash, lastSetup.baseURL, options);
},

// inside setup(hash, baseURL, viewOptions):
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
    forwardViewEvents(view); // re-register every view listener (poiclick, currentfloorchanged, ...)
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
- **Background.** Observed on the iOS simulator (WKWebView): the orthographic view renders the area around the map in black, where the perspective view shows a light sky. This demo's `map.html` also has a black `body`, so it was not established whether the SDK paints that black or leaves the canvas transparent over the page background — check against your own page.
- Calls made on the view while it is being recreated have nothing to act on — wait for the new view before sending commands.

## Learn more

- [Custom map server](custom-base-url.md) — another load-time option (`loadVenue`'s `baseURL`) that also requires a full reload to change.
- [Custom theme](custom-theme.md) — another `createView` option (`enableShadows`).
