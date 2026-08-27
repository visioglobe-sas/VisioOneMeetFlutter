import 'dart:async';

import 'package:flutter/material.dart';

import '../visio_one/visio_one_controller.dart';
import '../visio_one/visio_one_message.dart';

/// Overlay de la feature `dynamic-poi-crud` : trois champs ("New POI ID",
/// "Anchor POI ID", "Label text") + trois actions (Create / Update text /
/// Remove), affichés dans le bottom sheet ouvert par le FAB de
/// [VisioOneMapShell]. Chaque action est une commande Native -> JS
/// corrélée par `requestId` sur `controller.messages` (même idiom que
/// `custom-data`/`category-highlight`) — voir
/// [VisioOneController.createDynamicPOI]/[VisioOneController.updateDynamicPoiLabelText]/
/// [VisioOneController.removeDynamicPOI].
///
/// L'état "un POI dynamique suivi ou pas" vit sur
/// [VisioOneController.dynamicPoi] plutôt que dans ce `State`, pour
/// survivre à la fermeture du bottom sheet — même raison que
/// `CategoryHighlightOverlay.highlightedCategoryId` — cet overlay est
/// recréé à chaque ouverture. Voir `docs/features/dynamic-poi-crud.md`.
class DynamicPoiCrudOverlay extends StatefulWidget {
  const DynamicPoiCrudOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  State<DynamicPoiCrudOverlay> createState() => _DynamicPoiCrudOverlayState();
}

class _DynamicPoiCrudOverlayState extends State<DynamicPoiCrudOverlay> {
  final TextEditingController _newIdController = TextEditingController();
  final TextEditingController _anchorIdController = TextEditingController();
  final TextEditingController _labelTextController = TextEditingController();

  // Requête/réponse par `requestId` sur `controller.messages` (même idiom
  // que `CustomDataOverlay`).
  final Map<String, Completer<Map<String, Object?>>> _pendingRequests = {};
  StreamSubscription<VisioOneMessage>? _subscription;
  int _requestCounter = 0;

  bool _busy = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _subscription = widget.controller.messages.listen(_onMessage);
    // Préremplit le champ texte avec le label du POI dynamique déjà suivi,
    // si le panneau est rouvert alors qu'un POI a déjà été créé — sinon
    // "Update text" partirait d'un champ vide sans rapport avec le texte
    // actuellement affiché sur la carte.
    final tracked = widget.controller.dynamicPoi.value;
    if (tracked != null) {
      _labelTextController.text = tracked.labelText;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _newIdController.dispose();
    _anchorIdController.dispose();
    _labelTextController.dispose();
    super.dispose();
  }

  void _onMessage(VisioOneMessage message) {
    const handledTypes = {'dynamicPoiCreated', 'dynamicPoiLabelUpdated', 'dynamicPoiRemoved'};
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
    // Un aller-retour perdu ne doit jamais bloquer indéfiniment ce panneau
    // (même garde-fou que `CustomDataOverlay`).
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _pendingRequests.remove(requestId);
        return <String, Object?>{'success': false, 'message': 'Timed out waiting for the map.'};
      },
    );
  }

  String _newRequestId(String tag) => 'dynamic-poi-crud-$tag-${_requestCounter++}';

  Future<void> _create() async {
    if (widget.controller.dynamicPoi.value != null) return; // un seul POI dynamique à la fois.

    final newId = _newIdController.text.trim();
    final anchorId = _anchorIdController.text.trim();
    final labelText = _labelTextController.text.trim();
    if (newId.isEmpty || anchorId.isEmpty || labelText.isEmpty) return;

    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    final requestId = _newRequestId('create');
    final result = await _sendAndAwait(
      requestId,
      () => widget.controller.createDynamicPOI(
        requestId,
        newId: newId,
        anchorId: anchorId,
        labelText: labelText,
      ),
    );

    if (!mounted) return;
    final success = result['success'] == true;
    setState(() {
      _busy = false;
      if (success) {
        widget.controller.dynamicPoi.value = DynamicPoiInfo(id: newId, labelText: labelText);
      } else {
        _errorMessage = result['message'] as String? ?? 'Could not create the POI.';
      }
    });
  }

  Future<void> _updateText() async {
    final tracked = widget.controller.dynamicPoi.value;
    if (tracked == null) return;
    final text = _labelTextController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    final requestId = _newRequestId('update');
    final result = await _sendAndAwait(
      requestId,
      () => widget.controller.updateDynamicPoiLabelText(requestId, text),
    );

    if (!mounted) return;
    final success = result['success'] == true;
    setState(() {
      _busy = false;
      if (success) {
        widget.controller.dynamicPoi.value = tracked.withLabelText(text);
      } else {
        _errorMessage = result['message'] as String? ?? 'Could not update the label.';
      }
    });
  }

  Future<void> _remove() async {
    if (widget.controller.dynamicPoi.value == null) return;

    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    final requestId = _newRequestId('remove');
    final result = await _sendAndAwait(requestId, () => widget.controller.removeDynamicPOI(requestId));

    if (!mounted) return;
    final success = result['success'] == true;
    setState(() {
      _busy = false;
      if (success) {
        widget.controller.dynamicPoi.value = null;
      } else {
        _errorMessage = result['message'] as String? ?? 'Could not remove the POI.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DynamicPoiInfo?>(
      valueListenable: widget.controller.dynamicPoi,
      builder: (context, tracked, _) {
        final hasTracked = tracked != null;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              hasTracked ? 'Created: ${tracked.id} — "${tracked.labelText}"' : 'No dynamic POI created yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newIdController,
              enabled: !hasTracked,
              decoration: const InputDecoration(labelText: 'New POI ID', isDense: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _anchorIdController,
              enabled: !hasTracked,
              decoration: const InputDecoration(
                labelText: 'Anchor POI ID',
                helperText: 'Existing POI to copy the position from',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _labelTextController,
              decoration: const InputDecoration(labelText: 'Label text', isDense: true),
            ),
            const SizedBox(height: 12),
            if (_errorMessage != null) ...[
              Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _busy || hasTracked ? null : _create,
                    child: const Text('Create'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy || !hasTracked ? null : _updateText,
                    child: const Text('Update text'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy || !hasTracked ? null : _remove,
                    child: const Text('Remove'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
