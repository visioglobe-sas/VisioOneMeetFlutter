import '../../visio_one/visio_one_controller.dart';

/// Commandes Native -> JS de `custom-data`, implémentées côté JS par
/// `assets/www/features/custom-data.js`. Voir `docs/features/custom-data.md`.
extension CustomDataBridge on VisioOneController {
  /// Recharge le cache de CustomData métier depuis le serveur
  /// (`venue.refreshCustomData()`) puis lit celles d'un POI
  /// (`venue.getPOICustomData(poi)`), en un seul aller-retour de pont.
  /// Renvoie les données du message `customDataLoaded` (`{poiId, found,
  /// customData}`, `customData` toujours un objet, `{}` si le POI n'en a
  /// pas), ou `null` sans réponse à temps.
  Future<Map<String, Object?>?> loadCustomData(String poiId) => request('loadCustomData', [poiId]);
}
