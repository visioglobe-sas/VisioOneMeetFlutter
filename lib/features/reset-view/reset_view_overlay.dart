import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../visio_one/visio_one_controller.dart';
import 'reset_view_bridge.dart';

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
      child: Text(AppLocalizations.of(context)!.resetViewButton),
    );
  }
}
