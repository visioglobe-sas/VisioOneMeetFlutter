import '../../visio_one/visio_one_controller.dart';

/// Commandes Native -> JS de `goto-poi`, implémentées côté JS par
/// `assets/www/features/goto-poi.js`. Voir `docs/features/goto-poi.md`.
extension GotoPoiBridge on VisioOneController {
  /// Centre la caméra sur un POI (`view.goToFloor(poi.floor)` puis
  /// `view.goToPOI(poi)`). Sans effet si [poiId] ne correspond à aucun POI.
  /// Aussi appelée par `3d-icon-marker`, `custom-text-label` et
  /// `html-overlay-marker` pour afficher l'étage de l'objet placé.
  Future<void> goToPOI(String poiId) => send('goToPOI', [poiId]);

  /// Efface la sélection visuelle courante (surlignage de POI).
  Future<void> clearSelection() => send('clearSelection');
}
