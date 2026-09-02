import 'simulated_position_session.dart';

/// Test d'appartenance point-polygone par ray casting (algorithme PNPOLY,
/// parité des intersections d'un rayon horizontal), latitude/longitude
/// traitées comme des coordonnées planes x/y — approximation suffisante à
/// l'échelle d'un bâtiment, pas une vraie projection géodésique.
///
/// Le SDK VisioOne n'expose aucune primitive de geofencing/point-in-polygon
/// (confirmé en lisant sa surface publique) : la démo `geofencing`
/// l'implémente elle-même contre `Surface.positions`, résolu côté JS par
/// `VisioOneController.resolvePoiZone`. Voir `docs/features/geofencing.md`.
bool isPointInPolygon({
  required double latitude,
  required double longitude,
  required List<SimulatedPosition> polygon,
}) {
  if (polygon.length < 3) return false;
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final pi = polygon[i];
    final pj = polygon[j];
    final crossesLatitude = (pi.latitude > latitude) != (pj.latitude > latitude);
    if (!crossesLatitude) continue;
    final longitudeAtCrossing =
        (pj.longitude - pi.longitude) * (latitude - pi.latitude) / (pj.latitude - pi.latitude) +
        pi.longitude;
    if (longitude < longitudeAtCrossing) inside = !inside;
  }
  return inside;
}
