import '../../visio_one/visio_one_controller.dart';

/// Commandes Native -> JS de `custom-theme`, implémentées côté JS par
/// `assets/www/features/custom-theme.js`. La carte de cet écran est créée
/// avec `{'enableShadows': true}` (voir `lib/features/feature.dart`), sans
/// quoi `setTheme` n'a aucun effet visible. Voir `docs/features/custom-theme.md`.
extension CustomThemeBridge on VisioOneController {
  /// Ids des thèmes de scène 3D enregistrés (`view.themes`), ou `null` sans
  /// réponse `themesLoaded` à temps.
  Future<List<String>?> getThemes() async {
    final themes = (await request('getThemes'))?['themes'];
    return themes is List ? themes.whereType<String>().toList() : null;
  }

  /// `view.setTheme(name)` — [name] doit venir de [getThemes] (le SDK lève
  /// sinon). Réponse en message `themeApplied` (`{success, theme, message?}`).
  Future<void> setTheme(String name) => send('setTheme', [name]);

  /// `view.accentColor = accent; view.textAccentColor = textAccent` (hex,
  /// rgba ou hsl). Réponse en message `accentColorsApplied`
  /// (`{success, message?}`).
  Future<void> setAccentColors({required String accent, required String textAccent}) =>
      send('setAccentColors', [accent, textAccent]);
}
