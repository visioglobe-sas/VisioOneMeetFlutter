import '../../visio_one/visio_one_controller.dart';

/// Commandes Native -> JS de `compute-navigation`, implémentées côté JS par
/// `assets/www/features/compute-navigation.js`. Aussi utilisées par
/// `accessible-mode` et `custom-navigation-trace`. Voir
/// `docs/features/compute-navigation.md`.
extension ComputeNavigationBridge on VisioOneController {
  /// Calcule (`venue.computeNavigation`) et affiche
  /// (`view.setCurrentNavigationTrace`) un itinéraire entre deux POI.
  /// [isAccessible] demande un itinéraire sans escaliers (`accessible-mode`).
  /// Réponse en message `itineraryComputed` (`{instructions}`) ; aucun
  /// message si aucune route ne relie les deux POI.
  Future<void> startItinerary({required String origin, required String destination, bool isAccessible = false}) {
    return send('startItinerary', [
      {'origin': origin, 'destination': destination, 'isAccessible': isAccessible},
    ]);
  }
}
