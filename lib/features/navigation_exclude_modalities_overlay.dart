import 'package:flutter/material.dart';

import '../demo_map.dart';
import '../l10n/app_localizations.dart';
import '../visio_one/visio_one_controller.dart';
import 'shared/navigation_form.dart';

/// Valeur de segment `excludedAttributes` correspondant à un ascenseur sur
/// la carte de démo : le JSDoc du SDK donne `"elevator"` en exemple, mais la
/// valeur réellement présente sur les segments d'ascenseur de cette carte
/// est `'lift'` (voir `docs/features/navigation-exclude-modalities.md`).
const String kExcludedElevatorAttribute = 'lift';

/// Overlay de la feature `navigation-exclude-modalities` : formulaire
/// origine/destination ([NavigationForm]) avec un interrupteur "Avoid
/// elevator" ; "Itinerary" appelle
/// [VisioOneController.startItineraryExcludingModalities] avec
/// `excludedAttributes: ['lift']` quand l'interrupteur est actif.
///
/// L'interrupteur n'est lu qu'à l'appui sur "Itinerary" : le basculer seul ne
/// recalcule pas l'itinéraire affiché. Sa valeur vit dans `controller.panel`
/// pour survivre à la fermeture du panneau.
class NavigationExcludeModalitiesOverlay extends StatelessWidget {
  const NavigationExcludeModalitiesOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final avoidElevator = controller.panel.value<bool>('navigation-exclude-modalities.avoidElevator', false);
    return NavigationForm(
      controller: controller,
      stateKey: 'navigation-exclude-modalities',
      initialOriginId: DemoMap.excludeModalitiesFrom,
      initialDestinationId: DemoMap.excludeModalitiesTo,
      options: [
        ValueListenableBuilder<bool>(
          valueListenable: avoidElevator,
          builder: (context, value, _) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.excludeModalitiesAvoidElevatorLabel),
            value: value,
            onChanged: (v) => avoidElevator.value = v,
          ),
        ),
      ],
      onSubmit: (origin, destination) => controller.startItineraryExcludingModalities(
        origin: origin,
        destination: destination,
        excludedAttributes: avoidElevator.value ? const [kExcludedElevatorAttribute] : const [],
      ),
    );
  }
}
