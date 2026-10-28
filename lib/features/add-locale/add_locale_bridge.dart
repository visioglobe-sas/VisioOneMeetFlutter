import '../../visio_one/visio_one_controller.dart';

/// Commandes Native -> JS de `add-locale`, implémentées côté JS par
/// `assets/www/features/add-locale.js`. Voir `docs/features/add-locale.md`.
extension AddLocaleBridge on VisioOneController {
  /// Ajoute la locale `'es'` avec le dictionnaire [resources]
  /// (`venue.translator.addLocale('es', resources)`) puis relit chaque clé
  /// (`venue.translator.translate(key, 'es')`) dans le même aller-retour.
  /// Renvoie les valeurs traduites (une par clé de [resources]), ou `null`
  /// sans réponse `spanishLocaleAdded` à temps.
  Future<Map<String, String>?> addSpanishLocale(Map<String, String> resources) async {
    final values = (await request('addSpanishLocale', [resources]))?['values'];
    if (values is! Map) return null;
    return values.map((key, value) => MapEntry(key.toString(), value.toString()));
  }
}
