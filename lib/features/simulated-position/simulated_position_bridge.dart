import '../../visio_one/visio_one_controller.dart';

/// Coordonnées WGS84 minimales nécessaires à l'interpolation — pas besoin
/// d'altitude pour cette démo, voir `docs/features/simulated-position.md`.
class SimulatedPosition {
  const SimulatedPosition({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  /// Lit `{latitude, longitude}` reçu du pont, ou `null` si absent/illisible.
  static SimulatedPosition? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final latitude = raw['latitude'];
    final longitude = raw['longitude'];
    if (latitude is! num || longitude is! num) return null;
    return SimulatedPosition(latitude: latitude.toDouble(), longitude: longitude.toDouble());
  }
}

/// Commandes Native -> JS de `simulated-position`, implémentées côté JS par
/// `assets/www/features/simulated-position.js`. Aussi utilisées par
/// `camera-lock-on-position`, `geofencing` et `accuracy-circle-style` (via
/// `SimulatedPositionSession`). Voir `docs/features/simulated-position.md`.
extension SimulatedPositionBridge on VisioOneController {
  /// Position WGS84 d'affichage d'un POI — un POI n'expose pas de lat/lng
  /// directement : son premier label, sinon sa première image ou son premier
  /// marker, sinon le centre de sa première surface (helper JS
  /// `poiDisplayPosition` de `assets/www/bridge/core.js`). `null` si [poiId]
  /// ne correspond à aucun POI (ou à un POI sans élément visuel), ou si la
  /// réponse `poiPositionResolved` n'arrive pas à temps.
  Future<SimulatedPosition?> resolvePoiPosition(String poiId) async {
    final result = await request('resolvePoiPosition', [poiId]);
    return SimulatedPosition.fromJson(result?['position']);
  }

  /// Injecte/actualise une position simulée trackée + son cercle de
  /// précision ([precisionCircleRadius], en mètres)
  /// (`view.injectTrackedPosition`). Active `view.allowTracking` côté JS au
  /// passage — requis par le SDK avant le premier `injectTrackedPosition`.
  Future<void> injectTrackedPosition({
    required double latitude,
    required double longitude,
    required double precisionCircleRadius,
  }) => send('injectTrackedPosition', [latitude, longitude, precisionCircleRadius]);

  /// Arrête le suivi : pas de méthode dédiée côté SDK pour "effacer" le
  /// marqueur/cercle, c'est `view.allowTracking = false` qui les retire.
  Future<void> stopTrackedPosition() => send('stopTrackedPosition');
}
