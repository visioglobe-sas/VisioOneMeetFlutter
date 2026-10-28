import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../visio_one/visio_one_controller.dart';
import 'camera_carousel_session.dart';

/// Overlay de la feature `camera-showcase-carousel` : bouton Start/Stop,
/// ligne de statut (En cours / En pause / Arrêtée) et rappel du
/// comportement au toucher.
///
/// Ne porte aucun état : la boucle tourne dans
/// `assets/www/features/camera-showcase-carousel.js` et son état est
/// reflété par la session de l'écran ([CameraCarouselSession]) — fermer le panneau (nécessaire pour voir la
/// carte) n'arrête donc pas la visite, et le rouvrir montre l'état courant,
/// y compris une pause déclenchée par un toucher sur la carte.
class CameraShowcaseCarouselOverlay extends StatelessWidget {
  const CameraShowcaseCarouselOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = controller.session<CameraCarouselSession>();
    return ValueListenableBuilder<CameraCarouselStatus>(
      valueListenable: session.status,
      builder: (context, status, _) {
        final active = status.state != CameraCarouselState.stopped;
        final statusText = switch (status.state) {
          CameraCarouselState.running => l10n.cameraShowcaseCarouselStatusRunning(
            status.index ?? 0,
            status.total ?? CameraCarouselSession.kStops.length,
            status.poiId ?? '',
          ),
          CameraCarouselState.paused => l10n.cameraShowcaseCarouselStatusPaused,
          CameraCarouselState.stopped => l10n.cameraShowcaseCarouselStatusStopped,
        };
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: active ? session.stop : session.start,
              icon: Icon(active ? Icons.stop : Icons.play_arrow),
              label: Text(active ? l10n.cameraShowcaseCarouselStop : l10n.cameraShowcaseCarouselStart),
            ),
            const SizedBox(height: 12),
            Text(statusText, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(l10n.cameraShowcaseCarouselHint, style: Theme.of(context).textTheme.bodySmall),
          ],
        );
      },
    );
  }
}
