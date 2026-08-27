import 'dart:async';

import 'package:flutter/material.dart';

import '../visio_one/visio_one_controller.dart';
import '../visio_one/visio_one_message.dart';

/// Les deux langues proposées par cette démo. La venue de démo partagée
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
/// sheet ouvert par le FAB de [VisioOneMapShell]. Récupère la locale
/// courante de la venue au montage ([VisioOneController.getLocales]) pour
/// présélectionner la bonne puce, puis chaque tap appelle
/// [VisioOneController.setCurrentLocale]. Voir
/// `docs/features/runtime-locale.md`.
class RuntimeLocaleOverlay extends StatefulWidget {
  const RuntimeLocaleOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  State<RuntimeLocaleOverlay> createState() => _RuntimeLocaleOverlayState();
}

class _RuntimeLocaleOverlayState extends State<RuntimeLocaleOverlay> {
  StreamSubscription<VisioOneMessage>? _subscription;
  late final String _requestId = 'runtime-locale-${DateTime.now().microsecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    _subscription = widget.controller.messages.listen(_onMessage);
    widget.controller.getLocales(_requestId);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _onMessage(VisioOneMessage message) {
    if (message.type != 'localesLoaded') return;
    final data = message.data;
    if (data is! Map || data['requestId'] != _requestId) return;
    final locale = data['currentLocale'];
    if (locale is String) {
      widget.controller.currentLocale.value = locale;
    }
  }

  /// `'default'` est traitée comme `'fr'` pour savoir quelle puce
  /// présélectionner — voir le commentaire de tête de ce fichier.
  static String? _normalize(String? locale) => locale == 'default' ? 'fr' : locale;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: widget.controller.currentLocale,
      builder: (context, rawLocale, _) {
        final current = _normalize(rawLocale);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Map language'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in _kLocaleOptions)
                  ChoiceChip(
                    label: Text(option.label),
                    selected: current == option.code,
                    onSelected: (_) => widget.controller.setCurrentLocale(option.code),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
