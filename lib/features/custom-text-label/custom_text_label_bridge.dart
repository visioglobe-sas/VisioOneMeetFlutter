import '../../visio_one/visio_one_controller.dart';

/// Commandes Native -> JS de `custom-text-label`, implémentées côté JS par
/// `assets/www/features/custom-text-label.js`. Chaque commande renvoie les
/// données de sa réponse (`{success, error?, message?, previousRemoved?}`),
/// ou `null` sans réponse à temps. Voir `docs/features/custom-text-label.md`.
extension CustomTextLabelBridge on VisioOneController {
  /// Place un label texte (`venue.createLabel`) sur le POI existant
  /// [anchorId] (propriétaire et source de position, décalée de ~4 m), en
  /// retirant d'abord le label déjà placé. [width]/[height] en mètres,
  /// toujours passés tous les deux ; [color] en hex ; [rotation] en degrés.
  /// Réponse `textLabelPlaced`.
  Future<Map<String, Object?>?> placeTextLabel({
    required String anchorId,
    required String text,
    required String color,
    required double width,
    required double height,
    required int rotation,
  }) => request('placeTextLabel', [anchorId, text, color, width, height, rotation]);

  /// `venue.updateLabel(label, changes)` sur le label placé : [changes] =
  /// `{text}`, `{color}` ou `{width, height}` (jamais `width` seul, jamais
  /// `rotation`). Réponse `textLabelUpdated`.
  Future<Map<String, Object?>?> updateTextLabel(Map<String, Object> changes) => request('updateTextLabel', [changes]);

  /// Change la rotation du label placé : absente de `LabelUpdateOptions`,
  /// le JS retire puis recrée le label. Réponse `textLabelUpdated`.
  Future<Map<String, Object?>?> rotateTextLabel(int rotation) => request('rotateTextLabel', [rotation]);

  /// Retire le label placé (`venue.removeLabel`). Réponse `textLabelRemoved`.
  Future<Map<String, Object?>?> removeTextLabel() => request('removeTextLabel');
}
