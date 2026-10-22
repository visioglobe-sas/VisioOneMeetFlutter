# Protected map (token)

## Description

Loads a map that is protected by an authorization token, via the `authorizationToken` option of `loadVenue`, refreshes the token on an already-loaded venue with `venue.setAuthorizationToken(freshToken)`, and reports a rejected token (`UnauthorizedError`) separately from other load errors.

**This feature is a code sample only.** This demo has no protected map to ship, so every value in the repo is a **placeholder you must replace** with your own:

| Constant (`lib/features/auth_token_sample.dart`) | Placeholder value | Replace with |
|---|---|---|
| `kProtectedMapHash` | `YOUR_PROTECTED_MAP_HASH` | the hash of your protected map |
| `kProtectedMapServerBaseUrl` | `https://mapserver-auth.visioglobe.com/` | keep as is (protected map server) |
| `kProtectedMapToken` | `YOUR_JWT_FROM_YOUR_BACKEND` | a JWT fetched at runtime from your own backend |

The "Protected map (token)" screen in the app only shows a short explanation. It never calls `loadVenue` with these placeholders. The sample code itself compiles and is wired end to end, so you can call it once you have real values.

## SDK usage

Native side (Dart). The sample widget passes the three values to the map shell, which forwards them to the bridge:

```dart
// lib/features/auth_token_sample.dart
const String kProtectedMapHash = 'YOUR_PROTECTED_MAP_HASH';
const String kProtectedMapServerBaseUrl = 'https://mapserver-auth.visioglobe.com/';
// Must be issued by YOUR OWN backend (Visioglobe provides the signing secret
// and the claims to use). Never embed the signing secret in the app.
const String kProtectedMapToken = 'YOUR_JWT_FROM_YOUR_BACKEND';

const ProtectedMapSample(); // = VisioOneMapShell(hash: ..., baseURL: ..., authorizationToken: ...)

// Token refresh, on the already-loaded venue (no reload):
Future<void> refreshAuthorizationToken(VisioOneController controller, String freshToken) =>
    controller.setAuthorizationToken(freshToken);
```

```dart
// lib/visio_one/visio_one_controller.dart
Future<void> setup(String hash, {String? baseURL, Map<String, Object>? viewOptions, String? authorizationToken}) =>
    _call('setup', [hash, baseURL, viewOptions, authorizationToken]);

Future<void> setAuthorizationToken(String freshToken) => _call('setAuthorizationToken', [freshToken]);

// true when an `error` message comes from the SDK's UnauthorizedError
static bool isUnauthorizedError(VisioOneMessage message) => ...; // data['unauthorized'] == true
```

JS side (`assets/www/map.html`, `window.MapBridge`). This is the code that calls the real SDK methods:

```js
setup: function (hash, baseURL, viewOptions, authorizationToken) {
  var loadOptions = { vg_maphash: hash };
  if (baseURL) loadOptions.baseURL = baseURL;                       // 'https://mapserver-auth.visioglobe.com/'
  if (authorizationToken) loadOptions.authorizationToken = authorizationToken;
  visioOne.loadVenue(loadOptions, container)
    .then(function (v) { venue = v; return visioOne.createView(container, venue); })
    .then(function (createdView) { view = createdView; sendToNative('ready', { /* ... */ }); })
    .catch(function (error) {
      sendToNative('error', { message: error.message, unauthorized: isUnauthorizedError(error) });
    });
},

setAuthorizationToken: function (freshToken) {
  venue.setAuthorizationToken(freshToken);   // used by every later map request
},

// UnauthorizedError is not exported by the UMD bundle: identify it by its
// constructor name, with a fallback on its message.
function isUnauthorizedError(error) {
  if (!error) return false;
  if (error.constructor && error.constructor.name === 'UnauthorizedError') return true;
  return error.message === 'This venue needs an Authorization token to be loaded';
}
```

On the Dart side, an `error` with `unauthorized: true` is shown as "Authorization token invalid, expired or missing (UnauthorizedError)". Any other load failure keeps the generic error message.

## Things to know

- **How the token is sent.** The SDK sends `authorizationToken` as the HTTP header `Authorization: Bearer <token>` on every map request. Use it together with the protected map server as `baseURL` (`https://mapserver-auth.visioglobe.com/`). The standard `https://mapserver.visioglobe.com/` does not enforce tokens.
- **A protected map has its own hash**, distinct from any public map hash.
- **`UnauthorizedError`.** When the map server answers `403` on the map descriptor (invalid, expired or missing token), `loadVenue` rejects with `UnauthorizedError` and the message `"This venue needs an Authorization token to be loaded"`. SDK 1.1.0's UMD bundle exports only `VisioOne`/`createVisioOne`, so you cannot use `instanceof UnauthorizedError`. `error.name` is just `"Error"`. In the vendored bundle, `error.constructor.name === 'UnauthorizedError'` works, and the message is a fallback check.
- **Not every failure is an `UnauthorizedError`.** Any other failure (unknown hash, a server error, a network or CORS failure) makes `loadVenue` reject with a generic `Error("Cannot load the venue")`. The SDK logs the underlying cause as a `VisioOne error:` console warning. For example, with this repo's placeholder hash and token, the protected server answers `500`. The SDK reports that internally as "map hash not found" and rejects with the generic error, not `UnauthorizedError`. Expect the specific error only once your hash is real and only the token is wrong.
- **Tokens are short-lived.** The protected server accepts a lifetime of at most 1 hour, and requests made after expiry are rejected. Call `venue.setAuthorizationToken(freshToken)` **before** the current token expires: it updates the token for subsequent requests without reloading the map. Refreshing in time (e.g. on a timer) is the integrator's job. `setAuthorizationToken` only applies to a loaded venue.
- **Never embed the JWT signing secret in the app or the page.** Get tokens from your own backend. Visioglobe provides the signing secret and the claims to use.
- **Page origin (CORS).** The protected server also checks the request's `Origin` against an allowlist that Visioglobe configures for your account. Tell Visioglobe which origin(s) your app uses. In this Flutter app, `map.html` is loaded with `WebViewController.loadFlutterAsset`:
  - On iOS (WKWebView), the page is served from a `file://` URL. `location.origin` is `file://`, and the serialized origin (`window.origin`, which is what an `Origin` header carries) is `null`. In that context, the request to the protected server was not blocked by CORS: the server's response reached the SDK.
  - On Android, `loadFlutterAsset` loads the page from `file:///android_asset/flutter_assets/...`, which is also a `file` (opaque, `null`) origin.
  - A regular web page has a real origin (e.g. `https://your-app.example.com`). There, a preflight blocked by CORS only shows up as the generic load error.

## Learn more

- [Custom map server](custom-base-url.md): the `baseURL` load option this sample builds on.
