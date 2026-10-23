import 'package:flutter/material.dart';

import '../demo_map.dart';
import '../l10n/app_localizations.dart';
import '../visio_one/visio_one_controller.dart';

/// Overlay de la feature `clickable-surface` : un champ Place ID + deux
/// boutons ("Enable" / "Disable"), qui appellent
/// [VisioOneController.setSurfaceInteractive]. Toute la logique de survol/tap
/// (changement de couleur) est gérée par le SDK lui-même une fois la surface
/// rendue interactive — aucun listener de clic côté app n'est nécessaire.
/// Voir `docs/features/clickable-surface.md`.
class ClickableSurfaceOverlay extends StatelessWidget {
  const ClickableSurfaceOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final placeId = controller.panel.text('clickable-surface.placeId', DemoMap.clickableSurfacePlaceId);
    void setInteractive(bool interactive) {
      final id = placeId.text.trim();
      if (id.isNotEmpty) controller.setSurfaceInteractive(id, interactive);
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: placeId,
            decoration: InputDecoration(labelText: l10n.placeIdLabel, isDense: true),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(onPressed: () => setInteractive(true), child: Text(l10n.clickableSurfaceEnableButton)),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: () => setInteractive(false), child: Text(l10n.clickableSurfaceDisableButton)),
      ],
    );
  }
}
