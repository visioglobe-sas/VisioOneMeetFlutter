import '../../visio_one/visio_one_controller.dart';

/// Commandes Native -> JS de `runtime-locale`, implémentées côté JS par
/// `assets/www/features/runtime-locale.js`. `setCurrentLocale` est aussi
/// utilisée par `add-locale`. Voir `docs/features/runtime-locale.md`.
extension RuntimeLocaleBridge on VisioOneController {
  /// Locale courante (`venue.currentLocale`) et locales disponibles
  /// (`venue.translator.allLocales`) : données du message `localesLoaded`
  /// (`{currentLocale, allLocales}`), ou `null` sans réponse à temps.
  Future<Map<String, Object?>?> getLocales() => request('getLocales');

  /// Change la locale de la venue (`venue.setCurrentLocale`) : le SDK
  /// re-rend lui-même labels de POI et UI. Pas de message de confirmation.
  Future<void> setCurrentLocale(String locale) => send('setCurrentLocale', [locale]);
}
