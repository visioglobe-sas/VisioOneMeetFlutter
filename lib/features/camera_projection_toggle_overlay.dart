import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../visio_one/visio_one_controller.dart';

/// Les 2 valeurs acceptées par l'option `cameraProjection` de `createView`
/// (et rapportées par `view.cameraProjection`, en lecture seule).
enum _CameraProjection {
  perspective('perspective'),
  orthographic('orthographic');

  const _CameraProjection(this.value);

  /// Valeur exacte attendue/rapportée par le SDK.
  final String value;

  static _CameraProjection? fromValue(String? value) {
    for (final projection in _CameraProjection.values) {
      if (projection.value == value) return projection;
    }
    return null;
  }

  String label(AppLocalizations l10n) => switch (this) {
    _CameraProjection.perspective => l10n.cameraProjectionPerspectiveLabel,
    _CameraProjection.orthographic => l10n.cameraProjectionOrthographicLabel,
  };

  IconData get icon => switch (this) {
    _CameraProjection.perspective => Icons.view_in_ar,
    _CameraProjection.orthographic => Icons.crop_square,
  };
}

/// Overlay de la feature `camera-projection-toggle` : un contrôle segmenté
/// Perspective / Orthographique. `cameraProjection` ne se choisit qu'à la
/// création de la vue (pas de setter), donc chaque changement recrée toute
/// la carte ([VisioOneController.setCameraProjection]) ; le contrôle reflète
/// la valeur réellement rapportée par le SDK
/// ([VisioOneController.cameraProjection], `view.cameraProjection`) et reste
/// désactivé tant que la nouvelle vue n'est pas prête. Voir
/// `docs/features/camera-projection-toggle.md`.
class CameraProjectionToggleOverlay extends StatelessWidget {
  const CameraProjectionToggleOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<String?>(
      valueListenable: controller.cameraProjection,
      builder: (context, value, _) {
        final current = _CameraProjection.fromValue(value);
        final reloading = value == null;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.cameraProjectionHint, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            SegmentedButton<_CameraProjection>(
              segments: [
                for (final projection in _CameraProjection.values)
                  ButtonSegment(
                    value: projection,
                    icon: Icon(projection.icon),
                    label: Text(projection.label(l10n)),
                  ),
              ],
              selected: current == null ? const <_CameraProjection>{} : {current},
              emptySelectionAllowed: true,
              onSelectionChanged: reloading
                  ? null
                  : (selection) {
                      if (selection.isEmpty || selection.first == current) return;
                      controller.setCameraProjection(selection.first.value);
                    },
            ),
            if (reloading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
          ],
        );
      },
    );
  }
}
