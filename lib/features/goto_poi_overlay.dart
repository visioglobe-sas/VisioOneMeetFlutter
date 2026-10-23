import 'package:flutter/material.dart';

import '../demo_map.dart';
import '../l10n/app_localizations.dart';
import '../visio_one/visio_one_controller.dart';

/// Overlay de la feature `goto-poi` : un champ Place ID + deux boutons
/// ("Go" / "Clear"), affiché dans le bottom sheet ouvert par le FAB de
/// `VisioOneMapShell`. "Go" appelle [VisioOneController.goToPOI], "Clear"
/// [VisioOneController.clearSelection]. Voir `docs/features/goto-poi.md`.
class GotoPoiOverlay extends StatelessWidget {
  const GotoPoiOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final placeId = controller.panel.text('goto-poi.placeId', DemoMap.gotoPoiId);
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: placeId,
            decoration: InputDecoration(labelText: l10n.placeIdLabel, isDense: true),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () {
            final id = placeId.text.trim();
            if (id.isNotEmpty) controller.goToPOI(id);
          },
          child: Text(l10n.gotoPoiGoButton),
        ),
        const SizedBox(width: 8),
        // La sélection visuelle est un état global côté SDK : effaçable sans
        // connaître l'id sélectionné.
        OutlinedButton(onPressed: controller.clearSelection, child: Text(l10n.clearButton)),
      ],
    );
  }
}
