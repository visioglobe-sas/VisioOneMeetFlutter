import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../visio_one/visio_one_controller.dart';
import 'occupancy_simulation_overlay.dart';
import 'reset_view_overlay.dart';

/// Catalogue des features démontrées par l'app — source unique de vérité
/// pour la liste du menu et la résolution de l'overlay associé.
///
/// `slug` correspond au nom de branche/doc partagé entre le hub
/// (`VisioOneHub/CHECKLIST.md`) et les 5 dépôts plateforme, ex. `reset-view`.
enum Feature {
  resetView('reset-view'),
  occupancySimulated('occupancy-simulated');

  const Feature(this.slug);

  final String slug;

  String title(AppLocalizations l10n) => switch (this) {
    Feature.resetView => l10n.resetViewTitle,
    Feature.occupancySimulated => l10n.occupancySimulatedTitle,
  };

  String description(AppLocalizations l10n) => switch (this) {
    Feature.resetView => l10n.resetViewDescription,
    Feature.occupancySimulated => l10n.occupancySimulatedDescription,
  };

  Widget buildOverlay(BuildContext context, VisioOneController controller) => switch (this) {
    Feature.resetView => ResetViewOverlay(controller: controller),
    Feature.occupancySimulated => OccupancySimulationOverlay(controller: controller),
  };
}
