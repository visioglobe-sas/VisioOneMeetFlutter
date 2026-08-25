import 'package:flutter/material.dart';

import '../visio_one/simulated_position_session.dart';
import '../visio_one/visio_one_controller.dart';
import 'simulated_position_overlay.dart';

/// Overlay de la feature `camera-lock-on-position` : la même UI que
/// `simulated-position` (champs Place ID Origin/Destination, slider de
/// rayon, bouton Start/Stop — réutilisée telle quelle via
/// [SimulatedPositionOverlay], pas dupliquée) surmontée d'un interrupteur
/// "Camera lock" qui bascule `view.lockCameraPositionOnTracking` via
/// [VisioOneController.setCameraLockOnPosition]. Voir
/// `docs/features/camera-lock-on-position.md`.
///
/// Une position trackée en mouvement est nécessaire pour voir l'effet du
/// verrou (sans quoi la caméra n'a rien à suivre) — d'où la dépendance
/// directe sur `simulated-position` plutôt qu'une UI de tracking dédiée.
///
/// Comme [SimulatedPositionOverlay], cet overlay ne porte aucun état lui-même
/// : il ne fait que refléter et piloter [SimulatedPositionSession]
/// (`controller.simulatedPosition`), qui porte à la fois `isRunning` et
/// désormais `isCameraLocked` — voir le commentaire de tête de cette classe
/// pour pourquoi ce verrou vit sur la session plutôt que dans le `State` de
/// ce widget.
class CameraLockOnPositionOverlay extends StatelessWidget {
  const CameraLockOnPositionOverlay({super.key, required this.controller});

  final VisioOneController controller;

  SimulatedPositionSession get _session => controller.simulatedPosition;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SimulatedPositionOverlay(controller: controller),
        const Divider(height: 24),
        ValueListenableBuilder<bool>(
          valueListenable: _session.isRunning,
          builder: (context, isRunning, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: _session.isCameraLocked,
              builder: (context, isLocked, _) {
                return SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  // Désactivé tant qu'aucune position n'est trackée :
                  // verrouiller la caméra sur rien n'a pas de sens, et le
                  // SDK lui-même n'a aucun effet visible tant que
                  // `view.allowTracking` est à `false` (voir
                  // `view.lockCameraPositionOnTracking`, commentaire de
                  // View.ts). Repasse aussi à `false` automatiquement dès
                  // que la simulation s'arrête (Stop, "POI not found", ou
                  // sortie de l'écran) — voir `SimulatedPositionSession.stop`.
                  title: const Text('Camera lock'),
                  subtitle: const Text('Recenter camera on tracked position'),
                  value: isLocked,
                  onChanged: isRunning ? _session.setCameraLocked : null,
                );
              },
            );
          },
        ),
      ],
    );
  }
}
