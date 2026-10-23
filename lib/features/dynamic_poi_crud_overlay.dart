import 'dart:async';

import 'package:flutter/material.dart';

import '../demo_map.dart';
import '../l10n/app_localizations.dart';
import '../visio_one/visio_one_controller.dart';
import '../visio_one/visio_one_message.dart';
import 'shared/bridge_error_text.dart';

/// Overlay de la feature `dynamic-poi-crud` : trois champs ("New POI ID",
/// "Anchor POI ID", "Label text") + trois actions (Create / Update text /
/// Remove), affichés dans le bottom sheet ouvert par le FAB de
/// `VisioOneMapShell`. Chaque action est une commande Native -> JS
/// corrélée par `requestId` sur `controller.messages` — voir
/// [VisioOneController.createDynamicPOI]/[VisioOneController.updateDynamicPoiLabelText]/
/// [VisioOneController.removeDynamicPOI].
///
/// L'état "un POI dynamique suivi ou pas" vit sur
/// [VisioOneController.dynamicPoi] et les champs dans `controller.panel`,
/// pour survivre à la fermeture du bottom sheet (cet overlay est recréé à
/// chaque ouverture). Une réponse arrivée panneau fermé met quand même cet
/// état à jour. Voir `docs/features/dynamic-poi-crud.md`.
class DynamicPoiCrudOverlay extends StatefulWidget {
  const DynamicPoiCrudOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  State<DynamicPoiCrudOverlay> createState() => _DynamicPoiCrudOverlayState();
}

class _DynamicPoiCrudOverlayState extends State<DynamicPoiCrudOverlay> {
  late final TextEditingController _newIdController =
      widget.controller.panel.text('dynamic-poi-crud.newId', DemoMap.dynamicPoiNewId);
  late final TextEditingController _anchorIdController =
      widget.controller.panel.text('dynamic-poi-crud.anchorId', DemoMap.anchorPoiId);
  TextEditingController? _labelTextController;

  final Map<String, Completer<Map<String, Object?>>> _pendingRequests = {};
  StreamSubscription<VisioOneMessage>? _subscription;
  int _requestCounter = 0;

  bool _busy = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _subscription = widget.controller.messages.listen(_onMessage);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Texte par défaut localisé (l10n indisponible dans initState).
    _labelTextController ??= widget.controller.panel.text(
      'dynamic-poi-crud.labelText',
      AppLocalizations.of(context)!.dynamicPoiDefaultLabelText,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
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
    final requestId = 'dynamic-poi-crud-$tag-${_requestCounter++}';
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
      if (result['success'] != true) _errorMessage = bridgeErrorText(l10n, result, anchorId: anchorId);
    });
  }

  Future<void> _create() async {
    if (widget.controller.dynamicPoi.value != null) return; // un seul POI dynamique à la fois.
    final newId = _newIdController.text.trim();
    final anchorId = _anchorIdController.text.trim();
    final labelText = _labelTextController!.text.trim();
    if (newId.isEmpty || anchorId.isEmpty || labelText.isEmpty) return;
    await _perform(
      'create',
      (requestId) => widget.controller.createDynamicPOI(
        requestId,
        newId: newId,
        anchorId: anchorId,
        labelText: labelText,
      ),
      (result) {
        if (result['success'] == true) {
          widget.controller.dynamicPoi.value = DynamicPoiInfo(id: newId, labelText: labelText);
        }
      },
    );
  }

  Future<void> _updateText() async {
    final tracked = widget.controller.dynamicPoi.value;
    if (tracked == null) return;
    final text = _labelTextController!.text.trim();
    if (text.isEmpty) return;
    await _perform(
      'update',
      (requestId) => widget.controller.updateDynamicPoiLabelText(requestId, text),
      (result) {
        if (result['success'] == true) widget.controller.dynamicPoi.value = tracked.withLabelText(text);
        if (result['error'] == 'noPoi') widget.controller.dynamicPoi.value = null;
      },
    );
  }

  Future<void> _remove() async {
    if (widget.controller.dynamicPoi.value == null) return;
    await _perform('remove', (requestId) => widget.controller.removeDynamicPOI(requestId), (result) {
      if (result['success'] == true || result['error'] == 'noPoi') widget.controller.dynamicPoi.value = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<DynamicPoiInfo?>(
      valueListenable: widget.controller.dynamicPoi,
      builder: (context, tracked, _) {
        final hasTracked = tracked != null;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              hasTracked ? l10n.dynamicPoiStatusCreated(tracked.id, tracked.labelText) : l10n.dynamicPoiStatusNone,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newIdController,
              enabled: !hasTracked,
              decoration: InputDecoration(labelText: l10n.dynamicPoiNewIdLabel, isDense: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _anchorIdController,
              enabled: !hasTracked,
              decoration: InputDecoration(
                labelText: l10n.anchorPoiIdLabel,
                helperText: l10n.dynamicPoiAnchorHelper,
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _labelTextController,
              decoration: InputDecoration(labelText: l10n.dynamicPoiLabelTextLabel, isDense: true),
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
                    child: Text(l10n.createButton),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy || !hasTracked ? null : _updateText,
                    child: Text(l10n.updateTextButton),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy || !hasTracked ? null : _remove,
                    child: Text(l10n.removeButton),
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
