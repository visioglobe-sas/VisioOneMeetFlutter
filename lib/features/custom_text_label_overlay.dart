import 'dart:async';

import 'package:flutter/material.dart';

import '../demo_map.dart';
import '../l10n/app_localizations.dart';
import '../visio_one/visio_one_controller.dart';
import '../visio_one/visio_one_message.dart';

/// POI de la carte de démo partagée qui a une position utilisable (un
/// label) — "Restaurant", rez-de-chaussée du bâtiment B4.
const String _kDefaultAnchorId = DemoMap.anchorPoiId;

/// Couleurs proposées (hex, format accepté par le SDK), dans l'ordre des chips.
const List<(String label, String hex)> _kColors = [
  ('Red', '#E53935'),
  ('Green', '#43A047'),
  ('Blue', '#1E88E5'),
  ('Dark', '#212121'),
];

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
/// bottom sheet ouvert par le FAB de [VisioOneMapShell]. Chaque action est
/// une commande Native -> JS corrélée par `requestId` sur
/// `controller.messages` (même idiom que `IconMarkerOverlay`), la position
/// du label étant copiée depuis le POI ancre par le même helper JS
/// (`resolveAnchor`) que `dynamic-poi-crud` / `3d-icon-marker`.
///
/// Couleur et taille s'appliquent en direct (`venue.updateLabel`) sur un
/// label placé ; la rotation, absente de `LabelUpdateOptions`, recrée le
/// label côté JS. L'état vit sur le contrôleur (`textLabel*`) pour survivre
/// à la fermeture du bottom sheet. Voir `docs/features/custom-text-label.md`.
class CustomTextLabelOverlay extends StatefulWidget {
  const CustomTextLabelOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  State<CustomTextLabelOverlay> createState() => _CustomTextLabelOverlayState();
}

class _CustomTextLabelOverlayState extends State<CustomTextLabelOverlay> {
  late final TextEditingController _anchorIdController;
  late final TextEditingController _textController;

  final Map<String, Completer<Map<String, Object?>>> _pendingRequests = {};
  StreamSubscription<VisioOneMessage>? _subscription;
  int _requestCounter = 0;

  bool _busy = false;
  String? _errorMessage;

  VisioOneController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _anchorIdController = TextEditingController(text: _c.textLabelAnchorId.value ?? _kDefaultAnchorId);
    _textController = TextEditingController(text: _c.textLabelText.value ?? '');
    _subscription = _c.messages.listen(_onMessage);
  }

  // Texte par défaut localisé (l10n indisponible dans initState).
  bool _defaultTextApplied = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_defaultTextApplied) return;
    _defaultTextApplied = true;
    if (_c.textLabelText.value == null) {
      _textController.text = AppLocalizations.of(context)!.textLabelDefaultText;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _anchorIdController.dispose();
    _textController.dispose();
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

  Future<Map<String, Object?>> _sendAndAwait(String tag, void Function(String requestId) send) {
    final requestId = 'custom-text-label-$tag-${_requestCounter++}';
    final completer = Completer<Map<String, Object?>>();
    _pendingRequests[requestId] = completer;
    send(requestId);
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _pendingRequests.remove(requestId);
        return <String, Object?>{'success': false, 'error': 'sdk', 'message': 'Timed out waiting for the map.'};
      },
    );
  }

  static String _errorText(Map<String, Object?> result) => switch (result['error']) {
        'textRequired' => 'Text is required',
        'notFound' => 'POI not found',
        'noPosition' => 'This POI has no position',
        'noLabel' => 'No label placed',
        _ => result['message'] as String? ?? 'Could not complete the action.',
      };

  /// Exécute une action de pont en gérant l'état busy/erreur ; [onResult]
  /// met à jour l'état du contrôleur selon la réponse.
  Future<void> _perform(
    String tag,
    void Function(String requestId) send,
    void Function(Map<String, Object?> result) onResult,
  ) async {
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    final result = await _sendAndAwait(tag, send);
    if (!mounted) return;
    onResult(result);
    setState(() {
      _busy = false;
      if (result['success'] != true && result['error'] != 'noLabel') _errorMessage = _errorText(result);
    });
  }

  bool get _placed => _c.textLabelAnchorId.value != null;

  Future<void> _place() async {
    final anchorId = _anchorIdController.text.trim();
    final text = _textController.text;
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
          _c.textLabelText.value = text;
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
    final text = _textController.text;
    await _perform(
      'text',
      (requestId) => _c.updateTextLabel(requestId, {'text': text}),
      (result) {
        if (result['success'] == true) _c.textLabelText.value = text;
        if (result['error'] == 'noLabel') _c.textLabelAnchorId.value = null;
      },
    );
  }

  Future<void> _setColor(String hex) async {
    final previous = _c.textLabelColor.value;
    _c.textLabelColor.value = hex;
    if (!_placed) return; // appliqué au prochain "Place label".
    await _perform(
      'color',
      (requestId) => _c.updateTextLabel(requestId, {'color': hex}),
      (result) {
        if (result['success'] != true) _c.textLabelColor.value = previous;
        if (result['error'] == 'noLabel') _c.textLabelAnchorId.value = null;
      },
    );
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
    await _perform(
      'rotation',
      (requestId) => _c.rotateTextLabel(requestId, rotation),
      (result) {
        if (result['success'] == true) return;
        _c.textLabelRotation.value = previous;
        if (result['error'] == 'noLabel' || result['previousRemoved'] == true) _c.textLabelAnchorId.value = null;
      },
    );
  }

  Future<void> _remove() async {
    if (!_placed) return;
    await _perform(
      'remove',
      (requestId) => _c.removeTextLabel(requestId),
      (result) {
        // Succès, label déjà inconnu ou rejeté par le SDK : dans tous les
        // cas, le JS a oublié sa référence.
        _c.textLabelAnchorId.value = null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
        // Le bottom sheet est limité en hauteur : le panneau défile si besoin.
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _anchorIdController,
                decoration: const InputDecoration(
                  labelText: 'Anchor POI ID',
                  helperText: 'Existing POI that owns the label and gives its position',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _textController,
                decoration: const InputDecoration(labelText: 'Text', isDense: true),
              ),
              const SizedBox(height: 12),
              Text('Color', style: labelStyle),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  for (final (name, hex) in _kColors)
                    ChoiceChip(
                      avatar: CircleAvatar(backgroundColor: _parseHex(hex)),
                      label: Text(name),
                      selected: _c.textLabelColor.value == hex,
                      showCheckmark: false,
                      onSelected: _busy ? null : (_) => _setColor(hex),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Size', style: labelStyle),
              const SizedBox(height: 4),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'small', label: Text('Small')),
                  ButtonSegment(value: 'medium', label: Text('Medium')),
                  ButtonSegment(value: 'large', label: Text('Large')),
                ],
                selected: {_c.textLabelSize.value},
                showSelectedIcon: false,
                onSelectionChanged: _busy ? null : (selection) => _setSize(selection.first),
              ),
              const SizedBox(height: 8),
              Text('Rotation', style: labelStyle),
              const SizedBox(height: 4),
              SegmentedButton<int>(
                segments: [
                  for (final r in _kRotations) ButtonSegment(value: r, label: Text('$r°')),
                ],
                selected: {_c.textLabelRotation.value},
                showSelectedIcon: false,
                onSelectionChanged: _busy ? null : (selection) => _setRotation(selection.first),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _place,
                      child: const Text('Place label'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy || placedOn == null ? null : _updateText,
                      child: const Text('Update text'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy || placedOn == null ? null : _remove,
                      child: const Text('Remove label'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? (placedOn != null ? 'Label placed on $placedOn' : 'No label placed'),
                style: _errorMessage != null
                    ? TextStyle(color: Theme.of(context).colorScheme.error)
                    : Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        );
      },
    );
  }

  static Color _parseHex(String hex) => Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
}
