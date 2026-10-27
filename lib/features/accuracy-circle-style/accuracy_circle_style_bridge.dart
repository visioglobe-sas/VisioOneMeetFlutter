import '../../visio_one/visio_one_controller.dart';

/// Commandes Native -> JS de `accuracy-circle-style`, implémentées côté JS
/// par `assets/www/features/accuracy-circle-style.js`. Voir
/// `docs/features/accuracy-circle-style.md`.
extension AccuracyCircleStyleBridge on VisioOneController {
  /// Couleur/opacité du cercle de précision de la position trackée (pas de
  /// la flèche centrale) (`view.updatePositionTrackerGraphicOptions`). Le SDK
  /// ne fait que mémoriser ces options, appliquées au prochain
  /// `injectTrackedPosition`, et les remet à ses valeurs par défaut
  /// (`#0094f0`, 0.3) à chaque `allowTracking = false` — d'où leur
  /// réapplication par `SimulatedPositionSession.start`.
  Future<void> updatePositionTrackerGraphicOptions({required String color, required double opacity}) =>
      send('updatePositionTrackerGraphicOptions', [color, opacity]);
}
