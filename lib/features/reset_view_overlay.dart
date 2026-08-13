import 'package:flutter/material.dart';

import '../visio_one/visio_one_controller.dart';

/// Overlay de la feature `reset-view` : un bouton en haut à droite qui
/// recentre la caméra sur la vue globale du site (`goToGlobal`).
class ResetViewOverlay extends StatelessWidget {
  const ResetViewOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed: controller.goToGlobal,
            child: const Text('Reset view'),
          ),
        ),
      ),
    );
  }
}
