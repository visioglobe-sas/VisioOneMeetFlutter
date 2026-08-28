import 'dart:async';

import 'package:flutter/material.dart';

import '../visio_one/visio_one_controller.dart';
import '../visio_one/visio_one_message.dart';

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
/// le FAB de [VisioOneMapShell]. Chaque clé de [kSpanishResources] est
/// affichée avec sa traduction espagnole une fois ajoutée — relue via
/// `venue.translator.translate(key, 'es')` dans le même aller-retour de pont
/// ([VisioOneController.addSpanishLocale]) — la preuve, toujours visible
/// indépendamment de l'UI native du SDK, que l'aller-retour a fonctionné.
/// Un second bouton, optionnel, réutilise
/// [VisioOneController.setCurrentLocale] (même appel que `runtime-locale`)
/// pour rendre la sélection "live" si une partie de l'UI native du SDK est
/// visible à l'écran. Voir `docs/features/add-locale.md`.
class AddLocaleOverlay extends StatefulWidget {
  const AddLocaleOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  State<AddLocaleOverlay> createState() => _AddLocaleOverlayState();
}

class _AddLocaleOverlayState extends State<AddLocaleOverlay> {
  StreamSubscription<VisioOneMessage>? _subscription;
  late final String _requestId = 'add-locale-${DateTime.now().microsecondsSinceEpoch}';
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _subscription = widget.controller.messages.listen(_onMessage);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _onMessage(VisioOneMessage message) {
    if (message.type != 'spanishLocaleAdded') return;
    final data = message.data;
    if (data is! Map || data['requestId'] != _requestId) return;
    final rawValues = data['values'];
    if (rawValues is Map) {
      widget.controller.spanishLocaleTranslations.value = rawValues.map(
        (key, value) => MapEntry(key as String, value as String),
      );
    }
    setState(() => _adding = false);
  }

  void _addSpanishLocale() {
    setState(() => _adding = true);
    widget.controller.addSpanishLocale(_requestId, kSpanishResources);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, String>?>(
      valueListenable: widget.controller.spanishLocaleTranslations,
      builder: (context, translations, _) {
        final added = translations != null;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Add a new locale at runtime (\'es\')'),
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
                        translations?[key] ?? '(not added yet)',
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
              child: Text(added ? 'Spanish locale added' : 'Add Spanish locale'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: added ? () => widget.controller.setCurrentLocale('es') : null,
              child: const Text('Switch to Spanish'),
            ),
          ],
        );
      },
    );
  }
}
