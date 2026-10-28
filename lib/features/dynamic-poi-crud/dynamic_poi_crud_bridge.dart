import '../../visio_one/visio_one_controller.dart';

/// Commandes Native -> JS de `dynamic-poi-crud`, implémentées côté JS par
/// `assets/www/features/dynamic-poi-crud.js`. Chacune renvoie les données de
/// sa réponse (`{success, error?, message?, ...}`), ou `null` sans réponse
/// à temps. Codes `error` (états normaux de la démo, traduits côté Dart) :
/// `'notReady'`, `'notFound'` / `'noPosition'` (POI ancre), `'alreadyExists'`
/// (`POIAlreadyExistsError`), `'noPoi'`, `'sdk'` (avec le `message` du SDK).
/// Voir `docs/features/dynamic-poi-crud.md`.
extension DynamicPoiCrudBridge on VisioOneController {
  /// Crée un POI à la volée (`venue.createPOI({id: newId})`) puis lui
  /// attache un label (`venue.createLabel`) à la position du POI existant
  /// [anchorId] — un POI fraîchement créé n'a par lui-même aucune
  /// représentation visuelle. Réponse `dynamicPoiCreated`.
  Future<Map<String, Object?>?> createDynamicPOI({
    required String newId,
    required String anchorId,
    required String labelText,
  }) => request('createDynamicPOI', [newId, anchorId, labelText]);

  /// Modifie le texte du label du POI dynamique (`venue.updateLabel`) — la
  /// seule modification visuelle possible : `venue.updatePOI` ne touche
  /// qu'aux catégories. Réponse `dynamicPoiLabelUpdated`.
  Future<Map<String, Object?>?> updateDynamicPoiLabelText(String text) =>
      request('updateDynamicPoiLabelText', [text]);

  /// Supprime le POI dynamique (`venue.removePOI`), ce qui retire aussi son
  /// label. Réponse `dynamicPoiRemoved`.
  Future<Map<String, Object?>?> removeDynamicPOI() => request('removeDynamicPOI');
}
