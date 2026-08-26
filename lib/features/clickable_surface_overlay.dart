import 'package:flutter/material.dart';

import '../visio_one/visio_one_controller.dart';

/// Overlay de la feature `clickable-surface` : un champ Place ID + deux
/// boutons ("Enable" / "Disable"), qui appellent
/// [VisioOneController.setSurfaceInteractive]. Toute la logique de survol/tap
/// (changement de couleur) est gérée par le SDK lui-même une fois la surface
/// rendue interactive — cette classe ne fait qu'activer/désactiver ce mode,
/// aucun listener de clic côté app n'est nécessaire. Voir
/// `docs/features/clickable-surface.md`.
class ClickableSurfaceOverlay extends StatefulWidget {
  const ClickableSurfaceOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  State<ClickableSurfaceOverlay> createState() => _ClickableSurfaceOverlayState();
}

class _ClickableSurfaceOverlayState extends State<ClickableSurfaceOverlay> {
  final TextEditingController _placeIdController = TextEditingController();

  @override
  void dispose() {
    _placeIdController.dispose();
    super.dispose();
  }

  void _setInteractive(bool interactive) {
    final placeId = _placeIdController.text.trim();
    if (placeId.isEmpty) return;
    widget.controller.setSurfaceInteractive(placeId, interactive);
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
        FilledButton(onPressed: () => _setInteractive(true), child: const Text('Enable')),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: () => _setInteractive(false), child: const Text('Disable')),
      ],
    );
  }
}
