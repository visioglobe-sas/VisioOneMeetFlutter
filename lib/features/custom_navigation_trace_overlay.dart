import 'dart:async';

import 'package:flutter/material.dart';

import '../visio_one/visio_one_controller.dart';
import '../visio_one/visio_one_message.dart';
import 'compute_navigation_overlay.dart';

/// Catalogue de presets de couleurs pour `custom-navigation-trace`, chacun un
/// `NavigationTraceUpdateOptions` complet passé tel quel à
/// [VisioOneController.updateNavigationTrace]. `visioglobeBlue` ré-énonce
/// explicitement les couleurs par défaut du SDK (`Line.color` = `#0094F0`,
/// segment inactif/preview = `#C5C5C5`, voir `Venue/Line.d.ts`) comme un
/// preset comme un autre, plutôt qu'un faux no-op — le SDK n'offre aucun
/// appel "reset to default" (voir `docs/features/custom-navigation-trace.md`).
/// Mêmes valeurs que le catalogue Vue, pour rester cohérent d'une plateforme
/// à l'autre.
const Map<String, Map<String, String>> kNavigationTracePresets = {
  'visioglobeBlue': {
    'progressColor': '#0094F0',
    'progressOutlineColor': '#FFFFFF',
    'progressFutureColor': '#C5C5C5',
    'previewColor': '#C5C5C5',
    'previewOutlineColor': '#FFFFFF',
  },
  'brandRed': {
    'progressColor': '#E53935',
    'progressOutlineColor': '#FFFFFF',
    'progressFutureColor': '#F8C9C7',
    'previewColor': '#F8C9C7',
    'previewOutlineColor': '#FFFFFF',
  },
  'brandGreen': {
    'progressColor': '#2E7D32',
    'progressOutlineColor': '#FFFFFF',
    'progressFutureColor': '#C8E6C9',
    'previewColor': '#C8E6C9',
    'previewOutlineColor': '#FFFFFF',
  },
  'brandPurple': {
    'progressColor': '#6A1B9A',
    'progressOutlineColor': '#FFFFFF',
    'progressFutureColor': '#E1BEE7',
    'previewColor': '#E1BEE7',
    'previewOutlineColor': '#FFFFFF',
  },
};

Color _swatchColor(String presetKey) {
  final hex = kNavigationTracePresets[presetKey]!['progressColor']!;
  return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
}

/// Overlay de la feature `custom-navigation-trace` : réutilise verbatim les
/// champs Place ID "From"/"To" et le bouton "Itinerary" de
/// [ComputeNavigationOverlay] (même logique de calcul d'itinéraire, pas
/// dupliquée — même idiome que [CameraLockOnPositionOverlay] réutilisant
/// [SimulatedPositionOverlay]) plutôt qu'une nouvelle paire de champs, et y
/// ajoute une rangée de pastilles de couleur en dessous.
///
/// Taper une pastille applique immédiatement le preset correspondant à la
/// trace actuellement affichée ([VisioOneController.updateNavigationTrace])
/// et mémorise la sélection
/// ([VisioOneController.selectedNavigationTracePresetKey]) ; cet overlay
/// écoute aussi `controller.messages` pour réagir à `itineraryComputed` (même
/// message que celui émis par `startItinerary`, voir
/// `docs/features/compute-navigation.md`) et réappliquer automatiquement le
/// preset actuellement sélectionné à chaque nouvel itinéraire calculé —
/// sans ça, un nouvel itinéraire retomberait sur l'apparence par défaut du
/// SDK malgré une couleur déjà choisie. Voir
/// `docs/features/custom-navigation-trace.md`.
class CustomNavigationTraceOverlay extends StatefulWidget {
  const CustomNavigationTraceOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  State<CustomNavigationTraceOverlay> createState() => _CustomNavigationTraceOverlayState();
}

class _CustomNavigationTraceOverlayState extends State<CustomNavigationTraceOverlay> {
  StreamSubscription<VisioOneMessage>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.controller.messages.listen(_onMessage);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _onMessage(VisioOneMessage message) {
    if (message.type != 'itineraryComputed') return;
    _applyCurrentPreset();
  }

  void _applyCurrentPreset() {
    final preset = kNavigationTracePresets[widget.controller.selectedNavigationTracePresetKey.value];
    if (preset == null) return;
    widget.controller.updateNavigationTrace(preset);
  }

  void _selectPreset(String presetKey) {
    widget.controller.selectedNavigationTracePresetKey.value = presetKey;
    _applyCurrentPreset();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ComputeNavigationOverlay(controller: widget.controller),
        const SizedBox(height: 16),
        const Text('Trace color'),
        const SizedBox(height: 8),
        ValueListenableBuilder<String>(
          valueListenable: widget.controller.selectedNavigationTracePresetKey,
          builder: (context, selected, _) {
            return Row(
              children: [
                for (final presetKey in kNavigationTracePresets.keys) ...[
                  _ColorSwatch(
                    color: _swatchColor(presetKey),
                    selected: presetKey == selected,
                    onTap: () => _selectPreset(presetKey),
                  ),
                  const SizedBox(width: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.color, required this.selected, required this.onTap});

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
            width: 2,
          ),
        ),
      ),
    );
  }
}
