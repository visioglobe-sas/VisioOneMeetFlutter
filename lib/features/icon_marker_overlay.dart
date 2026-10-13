import 'dart:async';

import 'package:flutter/material.dart';

import '../visio_one/visio_one_controller.dart';
import '../visio_one/visio_one_message.dart';

/// Icône 96x96 (PNG, disque bleu + étoile blanche) placée par la démo, en
/// data URL — identique sur les 5 plateformes VisioOneMeet.
const String kIconMarkerDataUrl =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAGAAAABgCAYAAADimHc4AAACBklEQVR42u3dWW4CMRBFUVbLarOn5JsIqRlsv6FuSfmE0O+IwS7bfbtR1GXdf34/+qMOhg2KcehgGIU+HsMt+DEQ7sHXQqQFXwWRHn4sQkvwkRCt4dsjtAdvDTEtfCuEqeFbIAgv/H/NQzAKfx6CYfhzEIzD70cQf+FFAGxFAEAIEBJ+J4LB7+04gKUIAAgBTEackQBfI4SG34MAgBDAaMIrHuAjBACEAGZTvhUAbyEAIAQwbHrUALyEAAAAcwGMe68V4V8iHAjJHeAI7mqAb0oNcOK1vwYgCP+di1E/334EMcDVRSmewx5gd60COPk6K94Bzy7u1OP4CAqrNQCCQdJ4gAcE0Uh1dPgrASYirB0Ri+dsRoa/A6AdYt+ckNksZn3wpwDSIc7NiprP69cFrwJwBdH3BUo6YLlN+qI2ZGZ7EgAA+AgqD99/ueKA8K0Q0veAxSMk7v+tQnABULQrvQZhQgBVv9gCQb00cXVoUQgOa0MBEALsCitvFlSEMBpAvT9gd0g5TRgATAGMe8Ru/ydul+TJULIBNiGMBlDvlFcE4rkGSISgCsICwOG0FGUIuQDCdaM121ydTs1S/wrJDP8gQN3pu44nJzo1RXLC56h6Ts4FAAROUCd8ELiLBuGDwJ2UCB8E7qhH8BMR4orgQZgdfjJEbRE8ELODd8KgBBjUQRSKuqo/fm7G7BpJ/VcAAAAASUVORK5CYII=';

/// Id sous lequel l'objet `Image` du SDK est indexé côté JS (`map.html`).
/// Une seule icône à la fois pour cette démo.
const String _kImageId = '3d-icon-marker';

/// POI de la carte de démo partagée qui a une position utilisable (un
/// label) — "Restaurant", rez-de-chaussée du bâtiment B4.
const String _kDefaultAnchorId = 'B4-UL00-ID0009';

/// Overlay de la feature `3d-icon-marker` : champ "Anchor POI ID",
/// sélecteur d'orientation (Fixed / Flat / Facing camera) et actions
/// Place icon / Remove icon, affichés dans le bottom sheet ouvert par le FAB
/// de [VisioOneMapShell]. Chaque action est une commande Native -> JS
/// corrélée par `requestId` sur `controller.messages` (même idiom que
/// `DynamicPoiCrudOverlay`), et la position de l'icône est copiée depuis le
/// POI ancre par le même helper JS (`resolveAnchor`) que `dynamic-poi-crud`.
///
/// L'état (ancre courante, orientation) vit sur le contrôleur
/// ([VisioOneController.iconMarkerAnchorId] /
/// [VisioOneController.iconMarkerOrientation]) pour survivre à la fermeture
/// du bottom sheet. Voir `docs/features/3d-icon-marker.md`.
class IconMarkerOverlay extends StatefulWidget {
  const IconMarkerOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  State<IconMarkerOverlay> createState() => _IconMarkerOverlayState();
}

class _IconMarkerOverlayState extends State<IconMarkerOverlay> {
  late final TextEditingController _anchorIdController;

  final Map<String, Completer<Map<String, Object?>>> _pendingRequests = {};
  StreamSubscription<VisioOneMessage>? _subscription;
  int _requestCounter = 0;

  bool _busy = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _anchorIdController = TextEditingController(
      text: widget.controller.iconMarkerAnchorId.value ?? _kDefaultAnchorId,
    );
    _subscription = widget.controller.messages.listen(_onMessage);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _anchorIdController.dispose();
    super.dispose();
  }

  void _onMessage(VisioOneMessage message) {
    const handledTypes = {'iconImagePlaced', 'iconImageUpdated', 'iconImageRemoved'};
    if (!handledTypes.contains(message.type)) return;
    final data = message.data;
    if (data is! Map) return;
    final requestId = data['requestId'] as String?;
    final completer = requestId != null ? _pendingRequests.remove(requestId) : null;
    completer?.complete(data.map((key, value) => MapEntry(key.toString(), value)));
  }

  Future<Map<String, Object?>> _sendAndAwait(String requestId, void Function() send) {
    final completer = Completer<Map<String, Object?>>();
    _pendingRequests[requestId] = completer;
    send();
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _pendingRequests.remove(requestId);
        return <String, Object?>{'success': false, 'error': 'sdk', 'message': 'Timed out waiting for the map.'};
      },
    );
  }

  String _newRequestId(String tag) => '3d-icon-marker-$tag-${_requestCounter++}';

  static String _errorText(Map<String, Object?> result) => switch (result['error']) {
        'notFound' => 'POI not found',
        'noPosition' => 'This POI has no position',
        _ => result['message'] as String? ?? 'Could not complete the action.',
      };

  Future<void> _place() async {
    final anchorId = _anchorIdController.text.trim();
    if (anchorId.isEmpty) return;

    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    final requestId = _newRequestId('place');
    final result = await _sendAndAwait(
      requestId,
      () => widget.controller.placeIconImage(
        requestId,
        imageId: _kImageId,
        anchorId: anchorId,
        url: kIconMarkerDataUrl,
        orientationType: widget.controller.iconMarkerOrientation.value,
      ),
    );

    if (!mounted) return;
    final success = result['success'] == true;
    if (success) {
      widget.controller.iconMarkerAnchorId.value = anchorId;
      // Sans ça, l'icône reste invisible depuis la vue globale par défaut
      // (l'étage intérieur de l'ancre n'y est pas affiché) — même appel que
      // la démo `goto-poi`.
      unawaited(widget.controller.goToPOI(anchorId));
    } else if (result['previousRemoved'] == true) {
      widget.controller.iconMarkerAnchorId.value = null;
    }
    setState(() {
      _busy = false;
      if (!success) _errorMessage = _errorText(result);
    });
  }

  Future<void> _setOrientation(String orientation) async {
    final previous = widget.controller.iconMarkerOrientation.value;
    widget.controller.iconMarkerOrientation.value = orientation;
    if (widget.controller.iconMarkerAnchorId.value == null) return; // appliqué au prochain "Place icon".

    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    final requestId = _newRequestId('update');
    final result = await _sendAndAwait(
      requestId,
      () => widget.controller.updateIconImageOrientation(requestId, _kImageId, orientation),
    );

    if (!mounted) return;
    final success = result['success'] == true;
    if (!success) widget.controller.iconMarkerOrientation.value = previous;
    setState(() {
      _busy = false;
      if (!success) _errorMessage = _errorText(result);
    });
  }

  Future<void> _remove() async {
    if (widget.controller.iconMarkerAnchorId.value == null) return;

    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    final requestId = _newRequestId('remove');
    final result = await _sendAndAwait(requestId, () => widget.controller.removeIconImage(requestId, _kImageId));

    if (!mounted) return;
    final success = result['success'] == true;
    if (success || result['error'] == 'noImage') {
      widget.controller.iconMarkerAnchorId.value = null;
    }
    setState(() {
      _busy = false;
      if (!success && result['error'] != 'noImage') _errorMessage = _errorText(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.controller.iconMarkerAnchorId,
        widget.controller.iconMarkerOrientation,
      ]),
      builder: (context, _) {
        final placedOn = widget.controller.iconMarkerAnchorId.value;
        final orientation = widget.controller.iconMarkerOrientation.value;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _anchorIdController,
              decoration: const InputDecoration(
                labelText: 'Anchor POI ID',
                helperText: 'Existing POI that owns the icon and gives its position',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Text('Orientation', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'fixed', label: Text('Fixed')),
                ButtonSegment(value: 'flat', label: Text('Flat')),
                ButtonSegment(value: 'facing', label: Text('Facing camera')),
              ],
              selected: {orientation},
              showSelectedIcon: false,
              onSelectionChanged: _busy ? null : (selection) => _setOrientation(selection.first),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _place,
                    child: const Text('Place icon'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy || placedOn == null ? null : _remove,
                    child: const Text('Remove icon'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? (placedOn != null ? 'Icon placed on $placedOn' : 'No icon placed'),
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
