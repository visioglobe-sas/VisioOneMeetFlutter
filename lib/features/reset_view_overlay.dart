import 'package:flutter/material.dart';

import '../visio_one/visio_one_controller.dart';

/// Overlay de la feature `reset-view` : un bouton qui recentre la caméra sur
/// la vue globale du site (`goToGlobal`), affiché dans le bottom sheet de
/// l'écran de feature.
class ResetViewOverlay extends StatelessWidget {
  const ResetViewOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: controller.goToGlobal,
      child: const Text('Reset view'),
    );
  }
}
