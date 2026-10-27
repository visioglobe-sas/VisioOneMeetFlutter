import '../../visio_one/visio_one_controller.dart';

/// Commandes Native -> JS de `occupancy-simulated`, implémentées côté JS par
/// `assets/www/features/occupancy-simulated.js`. Voir
/// `docs/features/occupancy-simulated.md`.
extension OccupancySimulatedBridge on VisioOneController {
  /// Colore la/les surface(s) de chaque POI pour refléter un statut
  /// d'occupation (`venue.updateSurface(surface, { color })`), ex.
  /// `{'planId': 'B3-UL00-ID0065', 'color': '#E74C3C'}`. `color: null`
  /// réinitialise la surface.
  Future<void> updateOccupancy(List<Map<String, Object?>> occupancy) => send('updateOccupancy', [occupancy]);
}
