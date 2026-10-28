import '../../visio_one/visio_one_controller.dart';
import '../simulated-position/simulated_position_bridge.dart';

/// Commandes Native -> JS de `geofencing`, implémentées côté JS par
/// `assets/www/features/geofencing.js`. Le test point-dans-polygone est fait
/// côté Dart (`geofence_utils.dart`) : le SDK n'expose aucune primitive de
/// geofencing. Voir `docs/features/geofencing.md`.
extension GeofencingBridge on VisioOneController {
  /// Polygone WGS84 de la première surface d'un POI ("zone" de la démo),
  /// lu dans `poi.surfaces[0].positions`. `null` si [poiId] ne correspond à
  /// aucun POI (ou sans réponse à temps), liste vide si le POI n'a aucune
  /// surface — deux états distincts, affichés différemment.
  Future<List<SimulatedPosition>?> resolvePoiZone(String poiId) async {
    final raw = (await request('resolvePoiZone', [poiId]))?['positions'];
    if (raw is! List) return null;
    final positions = <SimulatedPosition>[];
    for (final entry in raw) {
      final position = SimulatedPosition.fromJson(entry);
      if (position == null) return null;
      positions.add(position);
    }
    return positions;
  }

  /// Colore (ou réinitialise, `active: false`) la/les surface(s) d'un POI
  /// zone comme alerte visuelle (`venue.updateSurface`, `'initial'` pour
  /// restaurer la couleur du bundle de carte).
  Future<void> setZoneAlert(String placeId, bool active) => send('setZoneAlert', [placeId, active]);
}
