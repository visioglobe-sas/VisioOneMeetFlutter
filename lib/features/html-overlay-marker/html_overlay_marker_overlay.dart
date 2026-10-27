import 'dart:async';

import 'package:flutter/material.dart';

import '../../demo_map.dart';
import '../../l10n/app_localizations.dart';
import '../../visio_one/visio_one_controller.dart';
import '../goto-poi/goto_poi_bridge.dart';
import '../shared/bridge_error_text.dart';
import 'html_overlay_marker_bridge.dart';
import 'html_overlay_marker_session.dart';

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
/// message `htmlBadgeTapped`, compté par la session de l'écran
/// ([HtmlOverlayMarkerSession.tapCount]) et affiché dans la ligne de
/// statut du panneau à sa réouverture. L'état vit dans cette session et les
/// champs dans `controller.panel`, pour survivre à la
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

  bool _busy = false;
  String? _errorMessage;

  VisioOneController get _c => widget.controller;
  HtmlOverlayMarkerSession get _s => _c.session<HtmlOverlayMarkerSession>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Texte par défaut localisé (l10n indisponible dans initState).
    _textController ??= _c.panel.text('html-overlay-marker.text', AppLocalizations.of(context)!.htmlBadgeDefaultText);
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
      if (result['success'] != true && result['error'] != 'noBadge') {
        _errorMessage = bridgeErrorText(l10n, result, anchorId: anchorId);
      }
    });
  }

  /// Le JS a oublié son badge (retiré, ou inconnu) : remet l'état à zéro.
  void _forgetBadge() {
    _s.anchorId.value = null;
    _s.visible.value = true;
  }

  Future<void> _place() async {
    final anchorId = _anchorIdController.text.trim();
    final text = _textController!.text;
    await _perform(() => _c.placeHtmlBadge(anchorId: anchorId, text: text), (result) {
      if (result['success'] == true) {
        _s.anchorId.value = anchorId;
        _s.visible.value = true;
        _s.tapCount.value = 0;
        // Le badge n'est affiché que si l'étage de son POI l'est : même
        // appel que la démo `goto-poi` (et `custom-text-label`).
        unawaited(_c.goToPOI(anchorId));
      } else if (result['previousRemoved'] == true) {
        _forgetBadge();
      }
    });
  }

  Future<void> _updateText() async {
    if (_s.anchorId.value == null) return;
    final text = _textController!.text;
    await _perform(() => _c.updateHtmlBadgeText(text), (result) {
      if (result['error'] == 'noBadge') _forgetBadge();
    });
  }

  Future<void> _toggleVisible() async {
    if (_s.anchorId.value == null) return;
    final visible = !_s.visible.value;
    await _perform(() => _c.setHtmlBadgeVisible(visible), (result) {
      if (result['success'] == true) _s.visible.value = visible;
      if (result['error'] == 'noBadge') _forgetBadge();
    });
  }

  Future<void> _remove() async {
    if (_s.anchorId.value == null) return;
    // Succès, badge déjà inconnu ou rejeté par le SDK : dans tous les cas,
    // le JS a oublié sa référence.
    await _perform(() => _c.removeHtmlBadge(), (_) => _forgetBadge());
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
      listenable: Listenable.merge([_s.anchorId, _s.visible, _s.tapCount]),
      builder: (context, _) {
        final placedOn = _s.anchorId.value;
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
                    child: Text(_s.visible.value ? l10n.htmlBadgeHideButton : l10n.htmlBadgeShowButton),
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
              _errorMessage ?? _statusText(l10n, placedOn, _s.tapCount.value),
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
