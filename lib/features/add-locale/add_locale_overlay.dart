import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../visio_one/visio_one_controller.dart';
import '../runtime-locale/runtime_locale_bridge.dart';
import 'add_locale_bridge.dart';

/// Dictionnaire fixe de démonstration pour `add-locale` : une clé prédéfinie
/// du SDK (`'search-for-anything'`, l'un des libellés d'UI listés dans la
/// TSDoc de `Translator.addLocale`) pour montrer qu'on peut *remplacer* un
/// texte d'UI intégré au SDK, et une clé purement applicative
/// (`'welcome-message'`, sans aucune signification pour le SDK lui-même)
/// pour montrer que `addLocale` est un magasin clé/valeur générique,
/// réutilisable pour les propres chaînes de l'app. Voir
/// `docs/features/add-locale.md`.
const Map<String, String> kSpanishResources = {
  'search-for-anything': 'Busca lo que quieras',
  'welcome-message': '¡Bienvenido al mapa VisioOne!',
};

/// Overlay de la feature `add-locale` : ajoute une locale `'es'` (espagnol)
/// jamais authorée dans VisioMapEditor pour cette carte, à l'exécution
/// (`venue.translator.addLocale`), affichée dans le bottom sheet ouvert par
/// le FAB de `VisioOneMapShell`. Chaque clé de [kSpanishResources] est
/// affichée avec sa traduction espagnole une fois ajoutée — relue via
/// `venue.translator.translate(key, 'es')` dans le même aller-retour de pont
/// ([AddLocaleBridge.addSpanishLocale]) — la preuve, toujours visible
/// indépendamment de l'UI native du SDK, que l'aller-retour a fonctionné.
/// Un second bouton, optionnel, réutilise
/// [RuntimeLocaleBridge.setCurrentLocale] (même appel que `runtime-locale`)
/// pour rendre la sélection "live" si une partie de l'UI native du SDK est
/// visible à l'écran. Voir `docs/features/add-locale.md`.
class AddLocaleOverlay extends StatefulWidget {
  const AddLocaleOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  State<AddLocaleOverlay> createState() => _AddLocaleOverlayState();
}

class _AddLocaleOverlayState extends State<AddLocaleOverlay> {
  bool _adding = false;

  VisioOneController get _c => widget.controller;

  /// Valeurs traduites en espagnol (une par clé de [kSpanishResources]), ou
  /// `null` tant que [AddLocaleBridge.addSpanishLocale] n'a pas réussi.
  /// Gardées dans `controller.panel` : `venue.translator.addLocale` a pris
  /// effet côté SDK dès le premier appel, donc rouvrir le panneau doit
  /// continuer à afficher l'état "ajoutée".
  ValueNotifier<Map<String, String>?> get _translations =>
      _c.panel.value<Map<String, String>?>('add-locale.translations', null);

  Future<void> _addSpanishLocale() async {
    setState(() => _adding = true);
    final values = await _c.addSpanishLocale(kSpanishResources);
    if (values != null) _translations.value = values;
    if (mounted) setState(() => _adding = false);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, String>?>(
      valueListenable: _translations,
      builder: (context, translations, _) {
        final l10n = AppLocalizations.of(context)!;
        final added = translations != null;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.addLocaleIntro),
            const SizedBox(height: 8),
            for (final key in kSpanishResources.keys)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        key,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        translations?[key] ?? l10n.addLocaleNotAdded,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontStyle: added ? FontStyle.normal : FontStyle.italic,
                          color: added ? null : Theme.of(context).disabledColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _adding || added ? null : _addSpanishLocale,
              child: Text(added ? l10n.addLocaleAddedButton : l10n.addLocaleAddButton),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: added ? () => _c.setCurrentLocale('es') : null,
              child: Text(l10n.addLocaleSwitchButton),
            ),
          ],
        );
      },
    );
  }
}
