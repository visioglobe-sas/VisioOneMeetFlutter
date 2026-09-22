import 'package:flutter/material.dart';

import '../visio_one/visio_one_controller.dart';

/// Valeur de segment `excludedAttributes` correspondant à un ascenseur sur ce
/// venue de démo — voir `docs/features/navigation-exclude-modalities.md` :
/// le JSDoc du SDK donne `"elevator"` comme exemple, mais la valeur
/// réellement taguée est `'lift'`, confirmée en direct sur ce venue partagé
/// par les 5 dépôts sœurs.
const String kExcludedElevatorAttribute = 'lift';

/// Overlay de la feature `navigation-exclude-modalities` : mêmes champs Place
/// ID "From"/"To" et bouton "Itinerary" que `ComputeNavigationOverlay` (même
/// idiome de calcul d'itinéraire), dupliqués ici plutôt que réutilisés tels
/// quels — contrairement à `CustomNavigationTraceOverlay`, qui embarque
/// `ComputeNavigationOverlay` verbatim : ici le bouton "Itinerary" doit
/// lui-même appeler un pont différent
/// ([VisioOneController.startItineraryExcludingModalities], pas
/// [VisioOneController.startItinerary]) selon l'état du switch "Avoid
/// elevator" ajouté en dessous, ce qu'embarquer l'overlay existant tel quel
/// ne permettrait pas.
///
/// Le switch n'est lu qu'à l'appui du bouton "Itinerary" : le faire basculer
/// seul ne recalcule jamais automatiquement un itinéraire déjà affiché —
/// même contrat que les autres toggles de cette démo (ex.
/// `camera-lock-on-position`). Voir
/// `docs/features/navigation-exclude-modalities.md`.
class NavigationExcludeModalitiesOverlay extends StatefulWidget {
  const NavigationExcludeModalitiesOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  State<NavigationExcludeModalitiesOverlay> createState() =>
      _NavigationExcludeModalitiesOverlayState();
}

class _NavigationExcludeModalitiesOverlayState extends State<NavigationExcludeModalitiesOverlay> {
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  bool _avoidElevator = false;

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
    widget.controller.startItineraryExcludingModalities(
      origin: origin,
      destination: destination,
      excludedAttributes: _avoidElevator ? const [kExcludedElevatorAttribute] : const [],
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
          title: const Text('Avoid elevator'),
          value: _avoidElevator,
          onChanged: (value) => setState(() => _avoidElevator = value),
        ),
        const SizedBox(height: 4),
        FilledButton(onPressed: _startItinerary, child: const Text('Itinerary')),
      ],
    );
  }
}
