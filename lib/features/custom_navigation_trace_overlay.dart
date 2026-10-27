import 'dart:async';

import 'package:flutter/material.dart';

import '../demo_map.dart';
import '../l10n/app_localizations.dart';
import '../visio_one/visio_one_controller.dart';
import '../visio_one/visio_one_message.dart';
import 'shared/color_chip.dart';
import 'shared/navigation_form.dart';

/// Catalogue de presets de couleurs pour `custom-navigation-trace`, chacun un
/// `NavigationTraceUpdateOptions` complet passé tel quel à
/// [VisioOneController.updateNavigationTrace]. `visioglobeBlue` ré-énonce
/// explicitement les couleurs par défaut du SDK (`Line.color` = `#0094F0`,
/// segment inactif/preview = `#C5C5C5`, voir `Venue/Line.d.ts` dans les
/// typings du SDK) comme un preset comme un autre, plutôt qu'un faux no-op —
/// le SDK n'offre aucun appel "reset to default" (voir
/// `docs/features/custom-navigation-trace.md`).
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

String _presetName(AppLocalizations l10n, String presetKey) => switch (presetKey) {
  'visioglobeBlue' => l10n.colorVisioglobeBlue,
  'brandRed' => l10n.colorRed,
  'brandGreen' => l10n.colorGreen,
  _ => l10n.colorPurple,
};

/// Overlay de la feature `custom-navigation-trace` : le formulaire
/// origine/destination partagé ([NavigationForm], même calcul d'itinéraire
/// que `compute-navigation`), suivi en dessous d'une rangée de puces de
/// couleur.
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
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NavigationForm(
          controller: widget.controller,
          stateKey: 'custom-navigation-trace',
          initialOriginId: DemoMap.itineraryFrom,
          initialDestinationId: DemoMap.itineraryTo,
          onSubmit: (origin, destination) =>
              widget.controller.startItinerary(origin: origin, destination: destination),
        ),
        const SizedBox(height: 16),
        Text(l10n.customNavigationTraceColorLabel),
        const SizedBox(height: 8),
        ValueListenableBuilder<String>(
          valueListenable: widget.controller.selectedNavigationTracePresetKey,
          builder: (context, selected, _) {
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final presetKey in kNavigationTracePresets.keys)
                  ColorChoiceChip(
                    hex: kNavigationTracePresets[presetKey]!['progressColor']!,
                    label: _presetName(l10n, presetKey),
                    selected: presetKey == selected,
                    onSelected: () => _selectPreset(presetKey),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
