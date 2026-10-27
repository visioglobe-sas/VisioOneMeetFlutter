import '../../visio_one/visio_one_controller.dart';

/// Commandes Native -> JS de `clickable-surface`, implémentées côté JS par
/// `assets/www/features/clickable-surface.js`. Voir
/// `docs/features/clickable-surface.md`.
extension ClickableSurfaceBridge on VisioOneController {
  /// Rend (ou non) les surfaces d'un POI interactives
  /// (`venue.updateSurface(surface, { isInteractive, color, hoverColor,
  /// selectionColor })`) : le SDK gère alors lui-même survol et tap, sans
  /// listener côté app.
  Future<void> setSurfaceInteractive(String placeId, bool interactive) =>
      send('setSurfaceInteractive', [placeId, interactive]);
}
