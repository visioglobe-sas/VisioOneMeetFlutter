import 'package:flutter/material.dart';

import '../../demo_map.dart';
import '../../l10n/app_localizations.dart';
import '../../visio_one/visio_one_controller.dart';
import '../compute-navigation/compute_navigation_bridge.dart';
import '../shared/navigation_form.dart';

/// Overlay de la feature `accessible-mode` : formulaire origine/destination
/// ([NavigationForm]) avec un interrupteur "Accessible route" transmis tel
/// quel comme `isAccessible` à [ComputeNavigationBridge.startItinerary] (puis à
/// `venue.computeNavigation` côté JS).
///
/// L'interrupteur n'est lu qu'à l'appui sur "Itinerary" : le basculer seul ne
/// recalcule pas l'itinéraire affiché. Sa valeur vit dans `controller.panel`
/// pour survivre à la fermeture du panneau. Voir
/// `docs/features/accessible-mode.md`.
class AccessibleModeOverlay extends StatelessWidget {
  const AccessibleModeOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final accessible = controller.panel.value<bool>('accessible-mode.accessible', false);
    return NavigationForm(
      controller: controller,
      stateKey: 'accessible-mode',
      initialOriginId: DemoMap.accessibleFrom,
      initialDestinationId: DemoMap.accessibleTo,
      options: [
        ValueListenableBuilder<bool>(
          valueListenable: accessible,
          builder: (context, value, _) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.accessibleModeSwitchLabel),
            value: value,
            onChanged: (v) => accessible.value = v,
          ),
        ),
      ],
      onSubmit: (origin, destination) =>
          controller.startItinerary(origin: origin, destination: destination, isAccessible: accessible.value),
    );
  }
}
