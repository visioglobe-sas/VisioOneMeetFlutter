import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../visio_one/visio_one_controller.dart';
import 'runtime_locale_bridge.dart';

/// Les deux langues proposées par cette démo (libellés dans leur propre
/// langue, volontairement non traduits). La venue de démo partagée
/// (`kDefaultMapHash`) expose en réalité trois locales
/// (`venue.translator.allLocales` = `['default', 'en', 'fr']`), mais
/// `'default'` s'est avérée être un doublon octet pour octet de `'fr'`
/// (confirmé en direct) — ce n'est donc pas une troisième option
/// significative, voir `docs/features/runtime-locale.md`. Codes en dur
/// plutôt que dérivés de la réponse `localesLoaded` : cette démo ne vise pas
/// à démontrer un sélecteur générique de N locales, seulement l'appel
/// `setCurrentLocale` lui-même.
const List<({String code, String label})> _kLocaleOptions = [
  (code: 'en', label: 'English'),
  (code: 'fr', label: 'Français'),
];

/// Overlay de la feature `runtime-locale` : bascule la langue des
/// POI/labels affichés sur la carte, à la volée, sans recharger ni
/// republier la carte (`venue.setCurrentLocale`), affichée dans le bottom
/// sheet ouvert par le FAB de `VisioOneMapShell`. Récupère la locale
/// courante de la venue au montage ([RuntimeLocaleBridge.getLocales]) pour
/// présélectionner la bonne puce, puis chaque tap appelle
/// [RuntimeLocaleBridge.setCurrentLocale]. Voir
/// `docs/features/runtime-locale.md`.
class RuntimeLocaleOverlay extends StatefulWidget {
  const RuntimeLocaleOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  State<RuntimeLocaleOverlay> createState() => _RuntimeLocaleOverlayState();
}

class _RuntimeLocaleOverlayState extends State<RuntimeLocaleOverlay> {
  VisioOneController get _c => widget.controller;

  /// Locale affichée par la venue (code brut de `venue.currentLocale`, ex.
  /// `'default'`/`'en'`/`'fr'`), ou `null` tant que [getLocales] n'a pas
  /// répondu. Gardée dans `controller.panel` pour survivre à la fermeture du
  /// bottom sheet.
  ValueNotifier<String?> get _currentLocale => _c.panel.value<String?>('runtime-locale.currentLocale', null);

  @override
  void initState() {
    super.initState();
    _c.getLocales().then((data) {
      final locale = data?['currentLocale'];
      if (locale is String) _currentLocale.value = locale;
    });
  }

  /// Mis à jour immédiatement, sans attendre la `Promise` JS : il n'y a pas
  /// de message de confirmation, le résultat est visible sur la carte.
  void _select(String locale) {
    _currentLocale.value = locale;
    _c.setCurrentLocale(locale);
  }

  /// `'default'` est traitée comme `'fr'` pour savoir quelle puce
  /// présélectionner — voir le commentaire de tête de ce fichier.
  static String? _normalize(String? locale) => locale == 'default' ? 'fr' : locale;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: _currentLocale,
      builder: (context, rawLocale, _) {
        final current = _normalize(rawLocale);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(AppLocalizations.of(context)!.runtimeLocaleMapLanguageLabel),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in _kLocaleOptions)
                  ChoiceChip(
                    label: Text(option.label),
                    selected: current == option.code,
                    onSelected: (_) => _select(option.code),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
