import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../visio_one/visio_one_controller.dart';
import '../visio_one/visio_one_map_shell.dart';

// -----------------------------------------------------------------------------
// Code sample `auth-token` — load a map protected by an authorization token.
//
// Everything below uses FICTITIOUS placeholder values: this demo has no
// protected map to ship, so the "Protected map (token)" screen of the app does
// NOT run this code (see `auth_token_screen.dart`). Replace the three
// placeholders with your own values, then use [ProtectedMapSample] (or call
// `VisioOneController.setup(..., authorizationToken: ...)` yourself).
// See docs/features/auth-token.md.
// -----------------------------------------------------------------------------

/// Hash of YOUR protected map (a protected map has its own hash, distinct from
/// any public one). Placeholder — replace it.
const String kProtectedMapHash = 'YOUR_PROTECTED_MAP_HASH';

/// Map server that enforces authorization tokens. The standard
/// `https://mapserver.visioglobe.com/` does not check tokens.
const String kProtectedMapServerBaseUrl = 'https://mapserver-auth.visioglobe.com/';

/// Short-lived JWT (1 hour max) authorizing access to [kProtectedMapHash].
/// Placeholder — replace it.
///
/// The JWT must be issued by YOUR OWN backend (Visioglobe provides the signing
/// secret and the claims to use). Never embed the signing secret in the app:
/// fetch a token from your backend at runtime instead of hard-coding one.
const String kProtectedMapToken = 'YOUR_JWT_FROM_YOUR_BACKEND';

/// Sample entry point: loads the protected map.
///
/// Under the hood (`assets/www/map.html`, `window.MapBridge.setup`):
/// ```js
/// const venue = await visioOne.loadVenue({
///   vg_maphash: hash,
///   baseURL: 'https://mapserver-auth.visioglobe.com/',
///   authorizationToken: token,
/// }, container)
/// const view = await visioOne.createView(container, venue)
/// ```
/// An invalid, expired or missing token makes `loadVenue` reject with the
/// SDK's `UnauthorizedError`, surfaced as an `error` message with
/// `unauthorized: true` ([VisioOneController.isUnauthorizedError]); the map
/// shell then shows "Authorization token invalid, expired or missing",
/// distinctly from other load errors.
class ProtectedMapSample extends StatelessWidget {
  const ProtectedMapSample({
    super.key,
    this.hash = kProtectedMapHash,
    this.baseURL = kProtectedMapServerBaseUrl,
    this.authorizationToken = kProtectedMapToken,
  });

  final String hash;
  final String baseURL;
  final String authorizationToken;

  @override
  Widget build(BuildContext context) {
    return VisioOneMapShell(
      hash: hash,
      baseURL: baseURL,
      authorizationToken: authorizationToken,
      overlayBuilder: (context, controller) => FilledButton.icon(
        icon: const Icon(Icons.key),
        label: Text(AppLocalizations.of(context)!.authTokenRefreshButton),
        // In a real app: fetch a fresh token from your backend, on a timer,
        // BEFORE the current one expires.
        onPressed: () => refreshAuthorizationToken(controller, kProtectedMapToken),
      ),
    );
  }
}

/// Sample token-refresh entry point: `venue.setAuthorizationToken(freshToken)`
/// on the already-loaded venue. Applies to subsequent map requests, no reload
/// needed. Call it before the current token expires.
Future<void> refreshAuthorizationToken(VisioOneController controller, String freshToken) =>
    controller.setAuthorizationToken(freshToken);
