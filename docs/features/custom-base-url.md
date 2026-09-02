# Custom map server

## Description

Points the SDK at a different map server than the default Visioglobe SaaS, via `LoadOptions.baseURL`. This demo exposes an editable "Base URL" field pre-filled with the SDK's real public default (`https://mapserver.visioglobe.com/`) and a Reload button. Reloading with the default value proves the parameter is genuinely wired through (it is the exact value the SDK would use anyway); reloading with an unreachable value demonstrates the clean, catchable failure the SDK surfaces instead of hanging.

## SDK usage

`baseURL` is an option of `loadVenue`, not a property you can mutate on an already-loaded venue — changing it requires a full reload, the same as changing the map hash would:

```dart
// lib/visio_one/visio_one_controller.dart
Future<void> setup(String hash, {String? baseURL}) => _call('setup', [hash, baseURL]);
```

```js
// window.MapBridge.setup, JS side (assets/www/map.html)
setup: function (hash, baseURL) {
  // ...
  visioOne
    .loadVenue(baseURL ? { hash: hash, baseURL: baseURL } : { hash: hash }, container)
    .then(function (v) { /* ... */ })
    .catch(function (error) {
      sendToNative('error', { message: error && error.message ? error.message : String(error) });
    });
}
```

`baseURL` is omitted entirely (not passed as `undefined`) when the app doesn't set it, so every other feature in this repo keeps relying on the SDK's own default rather than a value hard-coded here.

## Things to know

- `loadVenue` throws a typed `VenueNotFoundError` when the hash or `baseURL` is invalid — a bad URL is a clean, catchable rejection, not a hang or a generic crash. This demo surfaces it through the same `error` bridge message every other feature's failed load already uses.
- There is no live property to swap the map server on an already-loaded venue: this demo forces a full remount of the map view (a fresh `VisioOneController`, a fresh `setup` call) whenever the field's value changes, exactly as if the map hash itself had changed.
- No second real map server exists to demonstrate a genuinely different working deployment — hosting one is a separate infrastructure decision, out of scope for this demo repo. The default value already proves the parameter is real; an unreachable value proves the failure path is clean.

