import 'dart:async';

import 'package:flutter/material.dart';

import '../../demo_map.dart';
import '../../l10n/app_localizations.dart';
import '../../visio_one/visio_one_controller.dart';
import '../goto-poi/goto_poi_bridge.dart';
import '../shared/bridge_error_text.dart';
import '../shared/color_chip.dart';
import 'custom_text_label_bridge.dart';

/// Couleurs proposées (hex, format accepté par le SDK), dans l'ordre des chips.
const List<String> _kColors = ['#E53935', '#43A047', '#1E88E5', '#212121'];

String _colorName(AppLocalizations l10n, String hex) => switch (hex) {
  '#E53935' => l10n.colorRed,
  '#43A047' => l10n.colorGreen,
  '#1E88E5' => l10n.colorBlue,
  _ => l10n.colorDark,
};

/// Tailles proposées, en mètres : (width, height). Toujours envoyées ensemble
/// au SDK — `width` seul y remettrait `height = width`.
const Map<String, (double width, double height)> _kSizes = {
  'small': (10, 2),
  'medium': (16, 3),
  'large': (22, 4),
};

const List<int> _kRotations = [0, 45, 90];

/// Overlay de la feature `custom-text-label` : champs "Anchor POI ID" et
/// "Text", chips de couleur, sélecteurs de taille et de rotation, et
/// actions Place label / Update text / Remove label, affichés dans le
/// bottom sheet ouvert par le FAB de `VisioOneMapShell`. Chaque action est
/// une commande Native -> JS corrélée par `requestId` sur
/// `controller.messages`, la position du label étant copiée depuis le POI
/// ancre par le helper JS partagé `poiDisplayPosition` (via `resolveAnchor`).
///
/// Couleur et taille s'appliquent en direct (`venue.updateLabel`) sur un
/// label placé ; la rotation, absente de `LabelUpdateOptions`, recrée le
/// label côté JS. L'état et les champs vivent dans
/// `controller.panel`, pour survivre à la fermeture du bottom sheet ;
/// une réponse arrivée panneau fermé met quand même cet état à jour. Voir
/// `docs/features/custom-text-label.md`.
class CustomTextLabelOverlay extends StatefulWidget {
  const CustomTextLabelOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  State<CustomTextLabelOverlay> createState() => _CustomTextLabelOverlayState();
}

class _CustomTextLabelOverlayState extends State<CustomTextLabelOverlay> {
  late final TextEditingController _anchorIdController =
      _c.panel.text('custom-text-label.anchorId', DemoMap.anchorPoiId);
  TextEditingController? _textController;

  bool _busy = false;
  String? _errorMessage;

  VisioOneController get _c => widget.controller;

  /// Id du POI ancre du label placé, ou `null` si aucun label n'est placé.
  ValueNotifier<String?> get _placedOn => _c.panel.value<String?>('custom-text-label.placedOn', null);

  /// Couleur (hex `#RRGGBB`), taille (`'small'` / `'medium'` / `'large'`,
  /// voir [_kSizes]) et rotation (degrés) choisies pour le label.
  ValueNotifier<String> get _color => _c.panel.value<String>('custom-text-label.color', _kColors.first);
  ValueNotifier<String> get _size => _c.panel.value<String>('custom-text-label.size', 'medium');
  ValueNotifier<int> get _rotation => _c.panel.value<int>('custom-text-label.rotation', 0);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Texte par défaut localisé (l10n indisponible dans initState).
    _textController ??= _c.panel.text('custom-text-label.text', AppLocalizations.of(context)!.textLabelDefaultText);
  }

  /// Envoie une commande, attend sa réponse ([VisioOneController.request],
  /// 5 s max), applique [onResult] à l'état de l'écran même si le panneau a
  /// été fermé entre-temps, puis affiche l'éventuelle erreur si le panneau
  /// est toujours ouvert.
  Future<void> _perform(
    Future<Map<String, Object?>?> Function() send,
    void Function(Map<String, Object?> result) onResult,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final anchorId = _anchorIdController.text.trim();
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    final result = await send() ?? kBridgeTimeoutResult;
    onResult(result);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result['success'] != true && result['error'] != 'noLabel') {
        _errorMessage = bridgeErrorText(l10n, result, anchorId: anchorId);
      }
    });
  }

  bool get _placed => _placedOn.value != null;

  Future<void> _place() async {
    final anchorId = _anchorIdController.text.trim();
    final text = _textController!.text;
    final (width, height) = _kSizes[_size.value]!;
    await _perform(() => _c.placeTextLabel(anchorId: anchorId,
        text: text,
        color: _color.value,
        width: width,
        height: height,
        rotation: _rotation.value,
      ),
      (result) {
        if (result['success'] == true) {
          _placedOn.value = anchorId;
          // Un label n'est rendu que si l'étage de son POI est affiché :
          // même appel que la démo `goto-poi` (et `3d-icon-marker`).
          unawaited(_c.goToPOI(anchorId));
        } else if (result['previousRemoved'] == true) {
          _placedOn.value = null;
        }
      },
    );
  }

  Future<void> _updateText() async {
    if (!_placed) return;
    final text = _textController!.text;
    await _perform(() => _c.updateTextLabel({'text': text}), (result) {
      if (result['error'] == 'noLabel') _placedOn.value = null;
    });
  }

  Future<void> _setColor(String hex) async {
    final previous = _color.value;
    _color.value = hex;
    if (!_placed) return; // appliqué au prochain "Place label".
    await _perform(() => _c.updateTextLabel({'color': hex}), (result) {
      if (result['success'] != true) _color.value = previous;
      if (result['error'] == 'noLabel') _placedOn.value = null;
    });
  }

  Future<void> _setSize(String size) async {
    final previous = _size.value;
    _size.value = size;
    if (!_placed) return;
    final (width, height) = _kSizes[size]!;
    await _perform(() => _c.updateTextLabel({'width': width, 'height': height}),
      (result) {
        if (result['success'] != true) _size.value = previous;
        if (result['error'] == 'noLabel') _placedOn.value = null;
      },
    );
  }

  Future<void> _setRotation(int rotation) async {
    final previous = _rotation.value;
    _rotation.value = rotation;
    if (!_placed) return;
    await _perform(() => _c.rotateTextLabel(rotation), (result) {
      if (result['success'] == true) return;
      _rotation.value = previous;
      if (result['error'] == 'noLabel' || result['previousRemoved'] == true) _placedOn.value = null;
    });
  }

  Future<void> _remove() async {
    if (!_placed) return;
    // Succès, label déjà inconnu ou rejeté par le SDK : dans tous les cas,
    // le JS a oublié sa référence.
    await _perform(() => _c.removeTextLabel(), (_) => _placedOn.value = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: Listenable.merge([
        _placedOn,
        _color,
        _size,
        _rotation,
      ]),
      builder: (context, _) {
        final placedOn = _placedOn.value;
        final labelStyle = Theme.of(context).textTheme.labelLarge;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _anchorIdController,
              decoration: InputDecoration(
                labelText: l10n.anchorPoiIdLabel,
                helperText: l10n.textLabelAnchorHelper,
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              decoration: InputDecoration(labelText: l10n.textLabelTextLabel, isDense: true),
            ),
            const SizedBox(height: 12),
            Text(l10n.colorLabel, style: labelStyle),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                for (final hex in _kColors)
                  ColorChoiceChip(
                    hex: hex,
                    label: _colorName(l10n, hex),
                    selected: _color.value == hex,
                    onSelected: _busy ? null : () => _setColor(hex),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(l10n.textLabelSizeLabel, style: labelStyle),
            const SizedBox(height: 4),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'small', label: Text(l10n.textLabelSizeSmall)),
                ButtonSegment(value: 'medium', label: Text(l10n.textLabelSizeMedium)),
                ButtonSegment(value: 'large', label: Text(l10n.textLabelSizeLarge)),
              ],
              selected: {_size.value},
              showSelectedIcon: false,
              onSelectionChanged: _busy ? null : (selection) => _setSize(selection.first),
            ),
            const SizedBox(height: 8),
            Text(l10n.textLabelRotationLabel, style: labelStyle),
            const SizedBox(height: 4),
            SegmentedButton<int>(
              segments: [for (final r in _kRotations) ButtonSegment(value: r, label: Text('$r°'))],
              selected: {_rotation.value},
              showSelectedIcon: false,
              onSelectionChanged: _busy ? null : (selection) => _setRotation(selection.first),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(onPressed: _busy ? null : _place, child: Text(l10n.textLabelPlaceButton)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy || placedOn == null ? null : _updateText,
                    child: Text(l10n.updateTextButton),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy || placedOn == null ? null : _remove,
                    child: Text(l10n.textLabelRemoveButton),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? (placedOn != null ? l10n.textLabelStatusPlaced(placedOn) : l10n.textLabelStatusNone),
              style: _errorMessage != null
                  ? TextStyle(color: Theme.of(context).colorScheme.error)
                  : Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        );
      },
    );
  }
}
