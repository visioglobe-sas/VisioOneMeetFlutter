import 'package:flutter/material.dart';

import '../visio_one/visio_one_controller.dart';

/// Overlay de la feature `compute-navigation` : deux champs Place ID
/// ("From" / "To") + un bouton "Itinerary", affiché dans le bottom sheet
/// ouvert par le FAB de [VisioOneMapShell]. `startItinerary` existait déjà
/// sur [VisioOneController] (statut 🟡 dans `VisioOneHub/CHECKLIST.md` :
/// câblé jusqu'au pont JS — `venue.computeNavigation` +
/// `view.setCurrentNavigationTrace` dans `assets/www/map.html` — mais pas
/// relié à un bouton) — cette classe est la dernière étape manquante, comme
/// pour `goto-poi`. Voir `docs/features/compute-navigation.md`.
class ComputeNavigationOverlay extends StatefulWidget {
  const ComputeNavigationOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  State<ComputeNavigationOverlay> createState() => _ComputeNavigationOverlayState();
}

class _ComputeNavigationOverlayState extends State<ComputeNavigationOverlay> {
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

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
    widget.controller.startItinerary(origin: origin, destination: destination);
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
        const SizedBox(height: 12),
        FilledButton(onPressed: _startItinerary, child: const Text('Itinerary')),
      ],
    );
  }
}
