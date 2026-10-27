import '../../visio_one/visio_one_controller.dart';

/// Commandes Native -> JS de `custom-navigation-trace`, implémentées côté JS
/// par `assets/www/features/custom-navigation-trace.js`. Voir
/// `docs/features/custom-navigation-trace.md`.
extension CustomNavigationTraceBridge on VisioOneController {
  /// Restyle la trace actuellement affichée (créée par `startItinerary`) via
  /// `venue.updateNavigationTrace(trace, options)`. [options] ne porte que
  /// des couleurs (`progressColor`, `progressOutlineColor`,
  /// `progressFutureColor`, `previewColor`, `previewOutlineColor`). Sans
  /// effet tant qu'aucune trace n'a été créée ; le SDK n'a pas d'appel pour
  /// revenir à l'apparence par défaut.
  Future<void> updateNavigationTrace(Map<String, String> options) => send('updateNavigationTrace', [options]);
}
