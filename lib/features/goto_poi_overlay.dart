import 'package:flutter/material.dart';

import '../visio_one/visio_one_controller.dart';

/// Overlay de la feature `goto-poi` : un champ Place ID + deux boutons
/// ("Go" / "Clear"), affiché dans le bottom sheet ouvert par le FAB de
/// [VisioOneMapShell]. `goToPOI` existait déjà sur [VisioOneController]
/// (statut 🟡 dans `VisioOneHub/CHECKLIST.md` : câblé jusqu'au pont JS, pas
/// relié à un bouton) — cette classe est la dernière étape manquante. Voir
/// `docs/features/goto-poi.md`.
class GotoPoiOverlay extends StatefulWidget {
  const GotoPoiOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  State<GotoPoiOverlay> createState() => _GotoPoiOverlayState();
}

class _GotoPoiOverlayState extends State<GotoPoiOverlay> {
  final TextEditingController _placeIdController = TextEditingController();

  @override
  void dispose() {
    _placeIdController.dispose();
    super.dispose();
  }

  void _goToPoi() {
    final placeId = _placeIdController.text.trim();
    if (placeId.isEmpty) return;
    widget.controller.goToPOI(placeId);
  }

  void _clearPoi() {
    // Pas de "placeId courant" à mémoriser côté Dart (contrairement à
    // occupancy-simulated) : contrairement à une couleur appliquée, la
    // sélection visuelle d'un POI est un état global côté SDK, effaçable
    // sans connaître l'ID actuellement sélectionné. Ne vide pas non plus le
    // champ texte, pour permettre de retaper "Go" sur le même Place ID.
    widget.controller.clearSelection();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _placeIdController,
            decoration: const InputDecoration(hintText: 'Place ID', isDense: true),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(onPressed: _goToPoi, child: const Text('Go')),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: _clearPoi, child: const Text('Clear')),
      ],
    );
  }
}
