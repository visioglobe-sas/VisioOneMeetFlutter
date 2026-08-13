import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../visio_one/visio_one_controller.dart';
import '../visio_one/visio_one_message.dart';
import 'occupancy_simulation_overlay.dart';
import 'poi_click_overlay.dart';
import 'reset_view_overlay.dart';

/// Catalogue des features démontrées par l'app — source unique de vérité
/// pour la liste du menu et la résolution de l'overlay associé.
///
/// `slug` correspond au nom de branche/doc partagé entre le hub
/// (`VisioOneHub/CHECKLIST.md`) et les 5 dépôts plateforme, ex. `reset-view`.
enum Feature {
  resetView('reset-view'),
  occupancySimulated('occupancy-simulated'),
  poiClick('poi-click');

  const Feature(this.slug);

  final String slug;

  String title(AppLocalizations l10n) => switch (this) {
    Feature.resetView => l10n.resetViewTitle,
    Feature.occupancySimulated => l10n.occupancySimulatedTitle,
    Feature.poiClick => l10n.poiClickTitle,
  };

  String description(AppLocalizations l10n) => switch (this) {
    Feature.resetView => l10n.resetViewDescription,
    Feature.occupancySimulated => l10n.occupancySimulatedDescription,
    Feature.poiClick => l10n.poiClickDescription,
  };

  Widget buildOverlay(BuildContext context, VisioOneController controller) => switch (this) {
    Feature.resetView => ResetViewOverlay(controller: controller),
    Feature.occupancySimulated => OccupancySimulationOverlay(controller: controller),
    Feature.poiClick => const PoiClickOverlay(),
  };

  /// Réagit à un message JS -> Native que [VisioOneMapShell] ne gère pas
  /// lui-même (voir son `onMessage`). Seule `poi-click` s'en sert pour
  /// l'instant (`poiSelected` -> panneau d'info du POI tapé) ; les autres
  /// features n'ont rien à faire ici, tant que `map.html` ne diffuse ces
  /// événements que sur `view` (donc identiquement sur tous les écrans).
  void onMapMessage(BuildContext context, VisioOneMessage message) {
    switch (this) {
      case Feature.poiClick:
        handlePoiSelectedMessage(context, message);
      case Feature.resetView:
      case Feature.occupancySimulated:
        break;
    }
  }
}
