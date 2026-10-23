import 'package:flutter/material.dart';

import '../demo_map.dart';
import '../visio_one/visio_one_controller.dart';
import 'shared/navigation_form.dart';

/// Overlay de la feature `compute-navigation` : formulaire origine/destination
/// ([NavigationForm]) dont le bouton "Itinerary" appelle
/// [VisioOneController.startItinerary] (`venue.computeNavigation` +
/// `view.setCurrentNavigationTrace` côté JS, voir `assets/www/map.html`).
/// Voir `docs/features/compute-navigation.md`.
class ComputeNavigationOverlay extends StatelessWidget {
  const ComputeNavigationOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  Widget build(BuildContext context) {
    return NavigationForm(
      controller: controller,
      stateKey: 'compute-navigation',
      initialOriginId: DemoMap.itineraryFrom,
      initialDestinationId: DemoMap.itineraryTo,
      onSubmit: (origin, destination) => controller.startItinerary(origin: origin, destination: destination),
    );
  }
}
