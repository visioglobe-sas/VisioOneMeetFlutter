import '../../visio_one/visio_one_controller.dart';

/// Commandes Native -> JS de `3d-icon-marker`, implémentées côté JS par
/// `assets/www/features/3d-icon-marker.js`. L'objet `Image` du SDK reste
/// côté JS, indexé par `imageId`. Chaque commande renvoie les données de sa
/// réponse (`{success, error?, message?, previousRemoved?}`), ou `null` sans
/// réponse à temps. Voir `docs/features/3d-icon-marker.md`.
extension IconMarkerBridge on VisioOneController {
  /// Place une image sur le POI existant [anchorId] (propriétaire et source
  /// de position) via `venue.createImage`, en retirant d'abord l'image déjà
  /// placée sous [imageId]. [url] peut être une data URL ; [orientationType]
  /// : `'fixed'`, `'flat'` ou `'facing'`. Réponse `iconImagePlaced`.
  Future<Map<String, Object?>?> placeIconImage({
    required String imageId,
    required String anchorId,
    required String url,
    required String orientationType,
  }) => request('placeIconImage', [imageId, anchorId, url, orientationType]);

  /// Change l'orientation d'une image placée
  /// (`venue.updateImage(image, { orientationType })`). Réponse
  /// `iconImageUpdated`.
  Future<Map<String, Object?>?> updateIconImageOrientation(String imageId, String orientationType) =>
      request('updateIconImageOrientation', [imageId, orientationType]);

  /// Retire une image placée (`venue.removeImage`). Réponse
  /// `iconImageRemoved`.
  Future<Map<String, Object?>?> removeIconImage(String imageId) => request('removeIconImage', [imageId]);
}
