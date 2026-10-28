import '../../visio_one/visio_one_controller.dart';

/// Commandes Native -> JS de `auth-token`, implémentées côté JS par
/// `assets/www/features/auth-token.js`. Le jeton initial, lui, est passé à
/// `VisioOneController.setup(..., authorizationToken: ...)`. Voir
/// `docs/features/auth-token.md`.
extension AuthTokenBridge on VisioOneController {
  /// Remplace le jeton de la venue déjà chargée
  /// (`venue.setAuthorizationToken`) pour les requêtes suivantes, sans
  /// recharger la carte. À appeler avant l'expiration du jeton courant.
  Future<void> setAuthorizationToken(String freshToken) => send('setAuthorizationToken', [freshToken]);
}
