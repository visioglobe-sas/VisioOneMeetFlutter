import '../../visio_one/visio_one_controller.dart';

/// Commandes Native -> JS de `category-highlight`, implémentées côté JS par
/// `assets/www/features/category-highlight.js`. Voir
/// `docs/features/category-highlight.md`.
extension CategoryHighlightBridge on VisioOneController {
  /// Catégories de la venue courante (`venue.categories`) : `id`
  /// (identifiant interne brut, pour le filtrage) et `label` (nom résolu par
  /// `venue.translator.translateCategory()`, pour l'affichage). `null` sans
  /// réponse `categoriesLoaded` à temps.
  Future<List<({String id, String label})>?> getCategories() async {
    final raw = (await request('getCategories'))?['categories'];
    if (raw is! List) return null;
    return [
      for (final category in raw.whereType<Map>())
        (id: category['id'].toString(), label: category['label'].toString()),
    ];
  }

  /// Colore les surfaces de tous les POI de [categoryId]
  /// (`venue.updateSurface(surface, { color })`). Ne réinitialise pas la
  /// catégorie précédente : c'est à l'appelant de le faire.
  Future<void> highlightCategory(String categoryId) => send('highlightCategory', [categoryId]);

  /// Rend leur couleur d'origine (`'initial'`) aux surfaces des POI de
  /// [categoryId].
  Future<void> clearCategoryHighlight(String categoryId) => send('clearCategoryHighlight', [categoryId]);
}
