import '../../visio_one/visio_one_controller.dart';

/// Commandes Native -> JS de `html-overlay-marker`, implémentées côté JS par
/// `assets/www/features/html-overlay-marker.js` (qui envoie aussi
/// `htmlBadgeTapped` `{count}` à chaque tap sur le badge). Chaque commande
/// renvoie les données de sa réponse (`{success, error?, message?,
/// previousRemoved?}`), ou `null` sans réponse à temps. Voir
/// `docs/features/html-overlay-marker.md`.
extension HtmlOverlayMarkerBridge on VisioOneController {
  /// Épingle un badge HTML (`venue.createMarker({ poi, position, element })`,
  /// élément DOM créé côté JS) sur le POI existant [anchorId], en retirant
  /// d'abord le badge déjà placé. Réponse `htmlBadgePlaced`.
  Future<Map<String, Object?>?> placeHtmlBadge({required String anchorId, required String text}) =>
      request('placeHtmlBadge', [anchorId, text]);

  /// Change le texte du badge (édition DOM de `marker.element`, aucun appel
  /// SDK). Réponse `htmlBadgeUpdated`.
  Future<Map<String, Object?>?> updateHtmlBadgeText(String text) => request('updateHtmlBadgeText', [text]);

  /// Affiche/masque le badge (`venue.updateMarker(marker, { isVisible })`).
  /// Réponse `htmlBadgeUpdated`.
  Future<Map<String, Object?>?> setHtmlBadgeVisible(bool visible) => request('setHtmlBadgeVisible', [visible]);

  /// Retire le badge (`venue.removeMarker`). Réponse `htmlBadgeRemoved`.
  Future<Map<String, Object?>?> removeHtmlBadge() => request('removeHtmlBadge');
}
