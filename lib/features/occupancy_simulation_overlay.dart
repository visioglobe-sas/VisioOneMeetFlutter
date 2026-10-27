import 'package:flutter/material.dart';

import '../demo_map.dart';
import '../l10n/app_localizations.dart';
import '../visio_one/visio_one_controller.dart';

/// Overlay de la feature `occupancy-simulated` : un champ Place ID + un
/// bouton Start/Stop. La simulation elle-même (minuteur qui fait tourner la
/// couleur de la surface) vit sur [VisioOneController.occupancy], pas dans
/// ce panneau : elle continue panneau fermé, et le panneau rouvert affiche
/// "Stop" tant qu'elle tourne. Voir `docs/features/occupancy-simulated.md`.
class OccupancySimulationOverlay extends StatelessWidget {
  const OccupancySimulationOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = controller.occupancy;
    final placeId = controller.panel.text('occupancy-simulated.placeId', DemoMap.occupancyPlaceId);
    return ValueListenableBuilder<String?>(
      valueListenable: session.runningPlaceId,
      builder: (context, running, _) => Row(
        children: [
          Expanded(
            child: TextField(
              controller: placeId,
              enabled: running == null,
              decoration: InputDecoration(labelText: l10n.placeIdLabel, isDense: true),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () {
              if (running != null) {
                session.stop();
                return;
              }
              final id = placeId.text.trim();
              if (id.isNotEmpty) session.start(id);
            },
            child: Text(running != null ? l10n.occupancyStopButton : l10n.occupancyStartButton),
          ),
        ],
      ),
    );
  }
}
