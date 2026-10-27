import 'package:flutter/material.dart';

import '../demo_map.dart';
import '../l10n/app_localizations.dart';
import '../visio_one/simulated_position_session.dart';
import '../visio_one/visio_one_controller.dart';
import 'shared/color_chip.dart';
import 'simulated_position_overlay.dart';

/// Presets de couleur proposés par `accuracy-circle-style`. `defaultColor`
/// reprend la couleur par défaut du SDK ([_defaultColorHex]), celle que le
/// SDK restaure lui-même à chaque arrêt du tracking.
enum _TrackerColorPreset {
  defaultColor(_defaultColorHex),
  red('#e53935'),
  green('#43a047'),
  purple('#8e24aa');

  const _TrackerColorPreset(this.hex);

  final String hex;

  String label(AppLocalizations l10n) => switch (this) {
    _TrackerColorPreset.defaultColor => l10n.accuracyCircleStyleColorDefault,
    _TrackerColorPreset.red => l10n.accuracyCircleStyleColorRed,
    _TrackerColorPreset.green => l10n.accuracyCircleStyleColorGreen,
    _TrackerColorPreset.purple => l10n.accuracyCircleStyleColorPurple,
  };
}

/// Valeurs par défaut du SDK (`PositionTrackerGraphicOptions`).
const String _defaultColorHex = '#0094f0';
const double _defaultOpacity = 0.3;

// Minimum 0.1 et non 0 : le validateur du SDK teste `opacity` en falsy, une
// opacité 0 contournerait donc la validation — on ne la propose pas.
const double _minOpacity = 0.1;
const double _maxOpacity = 1.0;

/// Overlay de la feature `accuracy-circle-style` : la même UI de tracking
/// que `simulated-position` ([SimulatedPositionOverlay], réutilisée telle
/// quelle, pas dupliquée — comme `camera-lock-on-position` et `geofencing`),
/// préremplie avec deux POI de la carte de démo et un rayon de 6 m, suivie en
/// dessous de presets de couleur et d'un slider d'opacité qui appellent
/// `view.updatePositionTrackerGraphicOptions({color, opacity})` via
/// [SimulatedPositionSession.setTrackerGraphicOptions]. Voir
/// `docs/features/accuracy-circle-style.md`.
///
/// Le style choisi vit sur la session (pas dans ce `State`) : il doit
/// survivre à la fermeture du bottom sheet et être réappliqué à chaque Start
/// (le SDK le réinitialise à chaque arrêt du tracking).
class AccuracyCircleStyleOverlay extends StatefulWidget {
  const AccuracyCircleStyleOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  State<AccuracyCircleStyleOverlay> createState() => _AccuracyCircleStyleOverlayState();
}

class _AccuracyCircleStyleOverlayState extends State<AccuracyCircleStyleOverlay> {
  late String _colorHex;
  late double _opacity;

  SimulatedPositionSession get _session => widget.controller.simulatedPosition;

  @override
  void initState() {
    super.initState();
    _colorHex = _session.trackerColor ?? _defaultColorHex;
    _opacity = _session.trackerOpacity ?? _defaultOpacity;
  }

  void _apply({String? colorHex, double? opacity}) {
    setState(() {
      _colorHex = colorHex ?? _colorHex;
      _opacity = opacity ?? _opacity;
    });
    _session.setTrackerGraphicOptions(color: _colorHex, opacity: _opacity);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SimulatedPositionOverlay(
          controller: widget.controller,
          initialOriginId: DemoMap.trackingFrom,
          initialDestinationId: DemoMap.trackingTo,
          initialRadiusMeters: 6,
        ),
        const Divider(height: 24),
        Text(l10n.accuracyCircleStyleColorLabel, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in _TrackerColorPreset.values)
              ColorChoiceChip(
                hex: preset.hex,
                label: preset.label(l10n),
                selected: preset.hex == _colorHex,
                onSelected: () => _apply(colorHex: preset.hex),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(l10n.accuracyCircleStyleOpacityLabel),
            Expanded(
              child: Slider(
                value: _opacity,
                min: _minOpacity,
                max: _maxOpacity,
                divisions: 9,
                label: _opacity.toStringAsFixed(1),
                onChanged: (value) =>
                    // Arrondi au dixième : évite les 0.30000000000000004
                    // envoyés tels quels au SDK.
                    _apply(opacity: (value * 10).roundToDouble() / 10),
              ),
            ),
            SizedBox(width: 36, child: Text(_opacity.toStringAsFixed(1))),
          ],
        ),
      ],
    );
  }
}
