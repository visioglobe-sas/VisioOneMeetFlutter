import '../../visio_one/visio_one_controller.dart';

/// Commandes Native -> JS de `reset-view`, implémentées côté JS par
/// `assets/www/features/reset-view.js`. Voir `docs/features/reset-view.md`.
extension ResetViewBridge on VisioOneController {
  /// Recentre la caméra sur la vue globale du site (`view.goToGlobal()`).
  Future<void> goToGlobal() => send('goToGlobal');
}
