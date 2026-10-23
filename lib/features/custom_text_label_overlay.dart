import 'dart:async';

import 'package:flutter/material.dart';

import '../demo_map.dart';
import '../l10n/app_localizations.dart';
import '../visio_one/visio_one_controller.dart';
import '../visio_one/visio_one_message.dart';
import 'shared/bridge_error_text.dart';
import 'shared/color_chip.dart';

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
/// label côté JS. L'état vit sur le contrôleur (`textLabel*`) et les champs
/// dans `controller.panel`, pour survivre à la fermeture du bottom sheet ;
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

  final Map<String, Completer<Map<String, Object?>>> _pendingRequests = {};
  StreamSubscription<VisioOneMessage>? _subscription;
  int _requestCounter = 0;

  bool _busy = false;
  String? _errorMessage;

  VisioOneController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _subscription = _c.messages.listen(_onMessage);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Texte par défaut localisé (l10n indisponible dans initState).
    _textController ??= _c.panel.text('custom-text-label.text', AppLocalizations.of(context)!.textLabelDefaultText);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _onMessage(VisioOneMessage message) {
    const handledTypes = {'textLabelPlaced', 'textLabelUpdated', 'textLabelRemoved'};
    if (!handledTypes.contains(message.type)) return;
    final data = message.data;
    if (data is! Map) return;
    final requestId = data['requestId'] as String?;
    final completer = requestId != null ? _pendingRequests.remove(requestId) : null;
    completer?.complete(data.map((key, value) => MapEntry(key.toString(), value)));
  }

  /// Envoie une commande, attend sa réponse (5 s max), applique [onResult]
  /// à l'état du contrôleur même si le panneau a été fermé entre-temps, puis
  /// affiche l'éventuelle erreur si le panneau est toujours ouvert.
  Future<void> _perform(
    String tag,
    void Function(String requestId) send,
    void Function(Map<String, Object?> result) onResult,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final anchorId = _anchorIdController.text.trim();
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    final requestId = 'custom-text-label-$tag-${_requestCounter++}';
    final completer = Completer<Map<String, Object?>>();
    _pendingRequests[requestId] = completer;
    send(requestId);
    final result = await completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _pendingRequests.remove(requestId);
        return kBridgeTimeoutResult;
      },
    );
    onResult(result);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result['success'] != true && result['error'] != 'noLabel') {
        _errorMessage = bridgeErrorText(l10n, result, anchorId: anchorId);
      }
    });
  }

  bool get _placed => _c.textLabelAnchorId.value != null;

  Future<void> _place() async {
    final anchorId = _anchorIdController.text.trim();
    final text = _textController!.text;
    final (width, height) = _kSizes[_c.textLabelSize.value]!;
    await _perform(
      'place',
      (requestId) => _c.placeTextLabel(
        requestId,
        anchorId: anchorId,
        text: text,
        color: _c.textLabelColor.value,
        width: width,
        height: height,
        rotation: _c.textLabelRotation.value,
      ),
      (result) {
        if (result['success'] == true) {
          _c.textLabelAnchorId.value = anchorId;
          // Un label n'est rendu que si l'étage de son POI est affiché :
          // même appel que la démo `goto-poi` (et `3d-icon-marker`).
          unawaited(_c.goToPOI(anchorId));
        } else if (result['previousRemoved'] == true) {
          _c.textLabelAnchorId.value = null;
        }
      },
    );
  }

  Future<void> _updateText() async {
    if (!_placed) return;
    final text = _textController!.text;
    await _perform('text', (requestId) => _c.updateTextLabel(requestId, {'text': text}), (result) {
      if (result['error'] == 'noLabel') _c.textLabelAnchorId.value = null;
    });
  }

  Future<void> _setColor(String hex) async {
    final previous = _c.textLabelColor.value;
    _c.textLabelColor.value = hex;
    if (!_placed) return; // appliqué au prochain "Place label".
    await _perform('color', (requestId) => _c.updateTextLabel(requestId, {'color': hex}), (result) {
      if (result['success'] != true) _c.textLabelColor.value = previous;
      if (result['error'] == 'noLabel') _c.textLabelAnchorId.value = null;
    });
  }

  Future<void> _setSize(String size) async {
    final previous = _c.textLabelSize.value;
    _c.textLabelSize.value = size;
    if (!_placed) return;
    final (width, height) = _kSizes[size]!;
    await _perform(
      'size',
      (requestId) => _c.updateTextLabel(requestId, {'width': width, 'height': height}),
      (result) {
        if (result['success'] != true) _c.textLabelSize.value = previous;
        if (result['error'] == 'noLabel') _c.textLabelAnchorId.value = null;
      },
    );
  }

  Future<void> _setRotation(int rotation) async {
    final previous = _c.textLabelRotation.value;
    _c.textLabelRotation.value = rotation;
    if (!_placed) return;
    await _perform('rotation', (requestId) => _c.rotateTextLabel(requestId, rotation), (result) {
      if (result['success'] == true) return;
      _c.textLabelRotation.value = previous;
      if (result['error'] == 'noLabel' || result['previousRemoved'] == true) _c.textLabelAnchorId.value = null;
    });
  }

  Future<void> _remove() async {
    if (!_placed) return;
    // Succès, label déjà inconnu ou rejeté par le SDK : dans tous les cas,
    // le JS a oublié sa référence.
    await _perform('remove', (requestId) => _c.removeTextLabel(requestId), (_) => _c.textLabelAnchorId.value = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: Listenable.merge([
        _c.textLabelAnchorId,
        _c.textLabelColor,
        _c.textLabelSize,
        _c.textLabelRotation,
      ]),
      builder: (context, _) {
        final placedOn = _c.textLabelAnchorId.value;
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
                    selected: _c.textLabelColor.value == hex,
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
              selected: {_c.textLabelSize.value},
              showSelectedIcon: false,
              onSelectionChanged: _busy ? null : (selection) => _setSize(selection.first),
            ),
            const SizedBox(height: 8),
            Text(l10n.textLabelRotationLabel, style: labelStyle),
            const SizedBox(height: 4),
            SegmentedButton<int>(
              segments: [for (final r in _kRotations) ButtonSegment(value: r, label: Text('$r°'))],
              selected: {_c.textLabelRotation.value},
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
