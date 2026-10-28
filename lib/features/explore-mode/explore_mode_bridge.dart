import '../../visio_one/visio_one_controller.dart';

/// Commandes Native -> JS de `explore-mode`, implémentées côté JS par
/// `assets/www/features/explore-mode.js` (qui relaie aussi l'événement SDK
/// `exploremodechanged` en message `exploreModeChanged`). Voir
/// `docs/features/explore-mode.md`.
extension ExploreModeBridge on VisioOneController {
  /// Change le mode d'exploration courant (`view.currentExploreMode = mode`),
  /// l'un de `'global'`, `'building'`, `'floor'`.
  Future<void> setExploreMode(String mode) => send('setExploreMode', [mode]);

  /// Demande le mode d'exploration courant. Réponse en message `exploreMode`
  /// (`{currentExploreMode}`), sans `requestId` : il n'y a jamais qu'un seul
  /// mode courant.
  Future<void> getExploreMode() => send('getExploreMode');
}
