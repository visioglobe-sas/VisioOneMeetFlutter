import 'package:flutter/material.dart';

import '../visio_one/visio_one_controller.dart';

/// Overlay de la feature `accessible-mode` : mêmes champs Place ID
/// "From"/"To" et bouton "Itinerary" que `ComputeNavigationOverlay` (même
/// idiome de calcul d'itinéraire), dupliqués ici plutôt que réutilisés tels
/// quels — même choix que `NavigationExcludeModalitiesOverlay` pour la même
/// raison de fond (ce panneau ajoute son propre switch en dessous), même si
/// contrairement à cette dernière, [VisioOneController.startItinerary] lui-
/// même n'a pas besoin d'un second bridge method dédié : `isAccessible` y est
/// déjà un paramètre à part entière, forwardé tel quel jusqu'à
/// `venue.computeNavigation` côté JS (voir `assets/www/map.html`).
///
/// Le switch "Accessible route" n'est lu qu'à l'appui du bouton "Itinerary" :
/// le faire basculer seul ne recalcule jamais automatiquement un itinéraire
/// déjà affiché — même contrat que les autres toggles de cette démo (ex.
/// `navigation-exclude-modalities`, `camera-lock-on-position`). Voir
/// `docs/features/accessible-mode.md`.
class AccessibleModeOverlay extends StatefulWidget {
  const AccessibleModeOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  State<AccessibleModeOverlay> createState() => _AccessibleModeOverlayState();
}

class _AccessibleModeOverlayState extends State<AccessibleModeOverlay> {
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  bool _accessibleRoute = false;

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  void _startItinerary() {
    final origin = _originController.text.trim();
    final destination = _destinationController.text.trim();
    if (origin.isEmpty || destination.isEmpty) return;
    widget.controller.startItinerary(
      origin: origin,
      destination: destination,
      isAccessible: _accessibleRoute,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _originController,
          decoration: const InputDecoration(hintText: 'From (place ID)', isDense: true),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _destinationController,
          decoration: const InputDecoration(hintText: 'To (place ID)', isDense: true),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Accessible route'),
          value: _accessibleRoute,
          onChanged: (value) => setState(() => _accessibleRoute = value),
        ),
        const SizedBox(height: 4),
        FilledButton(onPressed: _startItinerary, child: const Text('Itinerary')),
      ],
    );
  }
}
