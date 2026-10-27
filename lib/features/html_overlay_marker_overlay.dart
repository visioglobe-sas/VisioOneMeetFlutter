import 'dart:async';

import 'package:flutter/material.dart';

import '../demo_map.dart';
import '../l10n/app_localizations.dart';
import '../visio_one/visio_one_controller.dart';
import '../visio_one/visio_one_message.dart';
import 'shared/bridge_error_text.dart';

/// Overlay de la feature `html-overlay-marker` : champs "Anchor POI ID" et
/// "Badge text", et actions Place badge / Update text / Hide-Show badge /
/// Remove badge, affichés dans le bottom sheet ouvert par le FAB de
/// `VisioOneMapShell`. Chaque action est une commande Native -> JS corrélée
/// par `requestId` sur `controller.messages`, la position du badge étant
/// copiée depuis le POI ancre par le helper JS partagé `poiDisplayPosition`
/// (via `resolveAnchor`).
///
/// Le badge est un élément DOM créé par le JS du pont
/// (`venue.createMarker({ poi, position, element })`) ; son tap remonte en
/// message `htmlBadgeTapped`, compté sur le contrôleur
/// ([VisioOneController.htmlBadgeTapCount]) et affiché dans la ligne de
/// statut du panneau à sa réouverture. L'état vit sur le contrôleur
/// (`htmlBadge*`) et les champs dans `controller.panel`, pour survivre à la
/// fermeture du bottom sheet ; une réponse arrivée panneau fermé met quand
/// même cet état à jour. Voir `docs/features/html-overlay-marker.md`.
class HtmlOverlayMarkerOverlay extends StatefulWidget {
  const HtmlOverlayMarkerOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  State<HtmlOverlayMarkerOverlay> createState() => _HtmlOverlayMarkerOverlayState();
}

class _HtmlOverlayMarkerOverlayState extends State<HtmlOverlayMarkerOverlay> {
  late final TextEditingController _anchorIdController =
      _c.panel.text('html-overlay-marker.anchorId', DemoMap.anchorPoiId);
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
    _textController ??= _c.panel.text('html-overlay-marker.text', AppLocalizations.of(context)!.htmlBadgeDefaultText);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _onMessage(VisioOneMessage message) {
    const handledTypes = {'htmlBadgePlaced', 'htmlBadgeUpdated', 'htmlBadgeRemoved'};
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
    final requestId = 'html-overlay-marker-$tag-${_requestCounter++}';
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
      if (result['success'] != true && result['error'] != 'noBadge') {
        _errorMessage = bridgeErrorText(l10n, result, anchorId: anchorId);
      }
    });
  }

  /// Le JS a oublié son badge (retiré, ou inconnu) : remet l'état à zéro.
  void _forgetBadge() {
    _c.htmlBadgeAnchorId.value = null;
    _c.htmlBadgeVisible.value = true;
  }

  Future<void> _place() async {
    final anchorId = _anchorIdController.text.trim();
    final text = _textController!.text;
    await _perform('place', (requestId) => _c.placeHtmlBadge(requestId, anchorId: anchorId, text: text), (result) {
      if (result['success'] == true) {
        _c.htmlBadgeAnchorId.value = anchorId;
        _c.htmlBadgeVisible.value = true;
        _c.htmlBadgeTapCount.value = 0;
        // Le badge n'est affiché que si l'étage de son POI l'est : même
        // appel que la démo `goto-poi` (et `custom-text-label`).
        unawaited(_c.goToPOI(anchorId));
      } else if (result['previousRemoved'] == true) {
        _forgetBadge();
      }
    });
  }

  Future<void> _updateText() async {
    if (_c.htmlBadgeAnchorId.value == null) return;
    final text = _textController!.text;
    await _perform('text', (requestId) => _c.updateHtmlBadgeText(requestId, text), (result) {
      if (result['error'] == 'noBadge') _forgetBadge();
    });
  }

  Future<void> _toggleVisible() async {
    if (_c.htmlBadgeAnchorId.value == null) return;
    final visible = !_c.htmlBadgeVisible.value;
    await _perform('visibility', (requestId) => _c.setHtmlBadgeVisible(requestId, visible), (result) {
      if (result['success'] == true) _c.htmlBadgeVisible.value = visible;
      if (result['error'] == 'noBadge') _forgetBadge();
    });
  }

  Future<void> _remove() async {
    if (_c.htmlBadgeAnchorId.value == null) return;
    // Succès, badge déjà inconnu ou rejeté par le SDK : dans tous les cas,
    // le JS a oublié sa référence.
    await _perform('remove', (requestId) => _c.removeHtmlBadge(requestId), (_) => _forgetBadge());
  }

  String _statusText(AppLocalizations l10n, String? placedOn, int tapCount) {
    if (placedOn == null) return l10n.htmlBadgeStatusNone;
    if (tapCount > 0) return l10n.htmlBadgeStatusTapped(tapCount);
    return l10n.htmlBadgeStatusPlaced(placedOn);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: Listenable.merge([_c.htmlBadgeAnchorId, _c.htmlBadgeVisible, _c.htmlBadgeTapCount]),
      builder: (context, _) {
        final placedOn = _c.htmlBadgeAnchorId.value;
        final placed = placedOn != null;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _anchorIdController,
              decoration: InputDecoration(
                labelText: l10n.anchorPoiIdLabel,
                helperText: l10n.htmlBadgeAnchorHelper,
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              decoration: InputDecoration(labelText: l10n.htmlBadgeTextLabel, isDense: true),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(onPressed: _busy ? null : _place, child: Text(l10n.htmlBadgePlaceButton)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy || !placed ? null : _updateText,
                    child: Text(l10n.updateTextButton),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy || !placed ? null : _toggleVisible,
                    child: Text(_c.htmlBadgeVisible.value ? l10n.htmlBadgeHideButton : l10n.htmlBadgeShowButton),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy || !placed ? null : _remove,
                    child: Text(l10n.htmlBadgeRemoveButton),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? _statusText(l10n, placedOn, _c.htmlBadgeTapCount.value),
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
