import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../visio_one/visio_one_controller.dart';
import '../visio_one/visio_one_message.dart';

/// Les 3 valeurs acceptées par `view.currentExploreMode` (voir
/// `visioone/src/VisioOne/View/ExploreMode.ts`) — exactement ces 3 chaînes,
/// sensibles à la casse, aucune autre n'existe.
enum _ExploreMode {
  global('global'),
  building('building'),
  floor('floor');

  const _ExploreMode(this.value);

  /// Valeur exacte attendue par le SDK, à transmettre telle quelle au pont.
  final String value;

  static _ExploreMode? fromValue(String? value) {
    for (final mode in _ExploreMode.values) {
      if (mode.value == value) return mode;
    }
    return null;
  }

  String label(AppLocalizations l10n) => switch (this) {
    _ExploreMode.global => l10n.exploreModeGlobalLabel,
    _ExploreMode.building => l10n.exploreModeBuildingLabel,
    _ExploreMode.floor => l10n.exploreModeFloorLabel,
  };

  IconData get icon => switch (this) {
    _ExploreMode.global => Icons.public,
    _ExploreMode.building => Icons.view_carousel,
    _ExploreMode.floor => Icons.layers,
  };
}

/// Overlay de la feature `explore-mode` : un contrôle segmenté à 3 options
/// (Global / Building / Floor) pilotant `view.currentExploreMode`, affiché
/// dans le bottom sheet ouvert par le FAB de [VisioOneMapShell]. `'building'`
/// est le mode à fort effet visuel de cette démo (vue éclatée façon
/// carrousel des étages des bâtiments ouverts) — un seul tap suffit à le
/// déclencher.
///
/// Même situation que `floor-selector` (voir `docs/features/floor-selector.md`
/// et `FloorSelectorOverlay`) : le SDK peut changer `currentExploreMode` en
/// dehors des appels de cette app — déplacement de caméra en/hors d'un
/// bâtiment en mode `'global'`, ou clic sur la carte en mode `'building'` qui
/// bascule automatiquement en mode `'floor'`. Ce panneau reste donc
/// synchronisé en écoutant l'événement `exploremodechanged` du SDK (relayé
/// ici comme message `exploreModeChanged`, voir `assets/www/map.html`)
/// plutôt qu'en ne suivant l'état que depuis ses propres taps — même idiome
/// que l'écoute de `floorChanged` dans `FloorSelectorOverlay`. Voir
/// `docs/features/explore-mode.md`.
class ExploreModeOverlay extends StatefulWidget {
  const ExploreModeOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  State<ExploreModeOverlay> createState() => _ExploreModeOverlayState();
}

class _ExploreModeOverlayState extends State<ExploreModeOverlay> {
  StreamSubscription<VisioOneMessage>? _subscription;
  _ExploreMode? _current;

  @override
  void initState() {
    super.initState();
    _subscription = widget.controller.messages.listen(_onMessage);
    widget.controller.getExploreMode();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _onMessage(VisioOneMessage message) {
    switch (message.type) {
      case 'exploreMode':
      case 'exploreModeChanged':
        final data = message.data;
        if (data is! Map) return;
        final mode = _ExploreMode.fromValue(data['currentExploreMode'] as String?);
        if (mode == null) return;
        setState(() => _current = mode);
    }
  }

  void _select(_ExploreMode mode) {
    if (mode == _current) return;
    setState(() => _current = mode);
    widget.controller.setExploreMode(mode.value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final current = _current;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.exploreModeHint, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        SegmentedButton<_ExploreMode>(
          segments: [
            for (final mode in _ExploreMode.values)
              ButtonSegment(value: mode, icon: Icon(mode.icon), label: Text(mode.label(l10n))),
          ],
          selected: current == null ? const <_ExploreMode>{} : {current},
          emptySelectionAllowed: true,
          onSelectionChanged: (selection) {
            if (selection.isEmpty) return;
            _select(selection.first);
          },
        ),
      ],
    );
  }
}
