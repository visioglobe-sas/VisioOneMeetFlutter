import '../../visio_one/visio_one_controller.dart';

/// Commandes Native -> JS de `camera-showcase-carousel`, implémentées côté JS
/// par `assets/www/features/camera-showcase-carousel.js` (la boucle, la pause
/// au toucher et la reprise y tournent). Voir
/// `docs/features/camera-showcase-carousel.md`.
extension CameraShowcaseCarouselBridge on VisioOneController {
  /// Démarre la visite caméra sur [poiIds], dans l'ordre, en boucle
  /// (`view.goToFloor` puis `view.goToPOI` pour chaque arrêt). L'état revient
  /// en messages `carouselState` (`{state, index, total, poiId}`).
  Future<void> startCarousel(List<String> poiIds) => send('startCarousel', [poiIds]);

  /// Arrête la visite : plus aucun arrêt programmé ; l'animation en cours
  /// (s'il y en a une) va à son terme.
  Future<void> stopCarousel() => send('stopCarousel');
}
