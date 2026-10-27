import 'dart:async';

import 'package:flutter/material.dart';

import '../../demo_map.dart';
import '../../l10n/app_localizations.dart';
import '../../visio_one/visio_one_controller.dart';
import '../shared/bridge_error_text.dart';
import 'dynamic_poi_crud_bridge.dart';

/// Overlay de la feature `dynamic-poi-crud` : trois champs ("New POI ID",
/// "Anchor POI ID", "Label text") + trois actions (Create / Update text /
/// Remove), affichés dans le bottom sheet ouvert par le FAB de
/// `VisioOneMapShell`. Chaque action est une commande Native -> JS
/// corrélée par `requestId` — voir [DynamicPoiCrudBridge].
///
/// L'état "un POI dynamique suivi ou pas" et les champs vivent dans
/// `controller.panel`,
/// pour survivre à la fermeture du bottom sheet (cet overlay est recréé à
/// chaque ouverture). Une réponse arrivée panneau fermé met quand même cet
/// état à jour. Voir `docs/features/dynamic-poi-crud.md`.
/// POI dynamique actuellement suivi par la démo — un seul à la fois
/// (contrat de cette démo, pas une limite du SDK). Immuable : chaque
/// changement (création, texte de label modifié) remplace l'instance.
class DynamicPoiInfo {
  const DynamicPoiInfo({required this.id, required this.labelText});

  /// Id du POI créé à la volée (`newId` passé à `createDynamicPOI`).
  final String id;

  /// Dernier texte connu du label attaché à ce POI.
  final String labelText;

  DynamicPoiInfo withLabelText(String labelText) => DynamicPoiInfo(id: id, labelText: labelText);
}

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

  /// POI dynamique suivi, ou `null` (aucun créé, ou supprimé). Mis à jour
  /// une fois qu'un aller-retour de pont confirme le succès de l'opération.
  ValueNotifier<DynamicPoiInfo?> get _tracked =>
      widget.controller.panel.value<DynamicPoiInfo?>('dynamic-poi-crud.poi', null);

  bool _busy = false;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Texte par défaut localisé (l10n indisponible dans initState).
    _labelTextController ??= widget.controller.panel.text(
      'dynamic-poi-crud.labelText',
      AppLocalizations.of(context)!.dynamicPoiDefaultLabelText,
    );
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
      if (result['success'] != true) _errorMessage = bridgeErrorText(l10n, result, anchorId: anchorId);
    });
  }

  Future<void> _create() async {
    if (_tracked.value != null) return; // un seul POI dynamique à la fois.
    final newId = _newIdController.text.trim();
    final anchorId = _anchorIdController.text.trim();
    final labelText = _labelTextController!.text.trim();
    if (newId.isEmpty || anchorId.isEmpty || labelText.isEmpty) return;
    await _perform(() => widget.controller.createDynamicPOI(newId: newId,
        anchorId: anchorId,
        labelText: labelText,
      ),
      (result) {
        if (result['success'] == true) {
          _tracked.value = DynamicPoiInfo(id: newId, labelText: labelText);
        }
      },
    );
  }

  Future<void> _updateText() async {
    final tracked = _tracked.value;
    if (tracked == null) return;
    final text = _labelTextController!.text.trim();
    if (text.isEmpty) return;
    await _perform(() => widget.controller.updateDynamicPoiLabelText(text),
      (result) {
        if (result['success'] == true) _tracked.value = tracked.withLabelText(text);
        if (result['error'] == 'noPoi') _tracked.value = null;
      },
    );
  }

  Future<void> _remove() async {
    if (_tracked.value == null) return;
    await _perform(() => widget.controller.removeDynamicPOI(), (result) {
      if (result['success'] == true || result['error'] == 'noPoi') _tracked.value = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<DynamicPoiInfo?>(
      valueListenable: _tracked,
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
