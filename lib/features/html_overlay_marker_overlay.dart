import 'dart:async';

import 'package:flutter/material.dart';

import '../demo_map.dart';
import '../l10n/app_localizations.dart';
import '../visio_one/visio_one_controller.dart';
import '../visio_one/visio_one_message.dart';

/// POI de la carte de démo partagée qui a une position utilisable (un
/// label) — "Restaurant", rez-de-chaussée du bâtiment B4.
const String _kDefaultAnchorId = DemoMap.anchorPoiId;

/// Overlay de la feature `html-overlay-marker` : champs "Anchor POI ID" et
/// "Badge text", et actions Place badge / Update text / Hide-Show badge /
/// Remove badge, affichés dans le bottom sheet ouvert par le FAB de
/// [VisioOneMapShell]. Chaque action est une commande Native -> JS corrélée
/// par `requestId` sur `controller.messages` (même idiom que
/// `CustomTextLabelOverlay`), la position du badge étant copiée depuis le
/// POI ancre par le même helper JS (`resolveAnchor`) que `dynamic-poi-crud` /
/// `3d-icon-marker` / `custom-text-label`.
///
/// Le badge est un élément DOM créé par le JS du pont
/// (`venue.createMarker({ poi, position, element })`) ; son tap remonte en
/// message `htmlBadgeTapped`, compté sur le contrôleur
/// ([VisioOneController.htmlBadgeTapCount]) et affiché dans la ligne de
/// statut du panneau à sa réouverture. L'état vit sur le contrôleur
/// (`htmlBadge*`) pour survivre à la fermeture du bottom sheet. Voir
/// `docs/features/html-overlay-marker.md`.
class HtmlOverlayMarkerOverlay extends StatefulWidget {
  const HtmlOverlayMarkerOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  State<HtmlOverlayMarkerOverlay> createState() => _HtmlOverlayMarkerOverlayState();
}

class _HtmlOverlayMarkerOverlayState extends State<HtmlOverlayMarkerOverlay> {
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
    _anchorIdController = TextEditingController(text: _c.htmlBadgeAnchorId.value ?? _kDefaultAnchorId);
    _textController = TextEditingController(text: _c.htmlBadgeText.value ?? '');
    _subscription = _c.messages.listen(_onMessage);
  }

  // Texte par défaut localisé (l10n indisponible dans initState).
  bool _defaultTextApplied = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_defaultTextApplied) return;
    _defaultTextApplied = true;
    if (_c.htmlBadgeText.value == null) {
      _textController.text = AppLocalizations.of(context)!.htmlBadgeDefaultText;
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
    const handledTypes = {'htmlBadgePlaced', 'htmlBadgeUpdated', 'htmlBadgeRemoved'};
    if (!handledTypes.contains(message.type)) return;
    final data = message.data;
    if (data is! Map) return;
    final requestId = data['requestId'] as String?;
    final completer = requestId != null ? _pendingRequests.remove(requestId) : null;
    completer?.complete(data.map((key, value) => MapEntry(key.toString(), value)));
  }

  Future<Map<String, Object?>> _sendAndAwait(String tag, void Function(String requestId) send) {
    final requestId = 'html-overlay-marker-$tag-${_requestCounter++}';
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
        'noBadge' => 'No badge placed',
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
      if (result['success'] != true && result['error'] != 'noBadge') _errorMessage = _errorText(result);
    });
  }

  /// Le JS a oublié son badge (retiré, ou inconnu) : remet l'état à zéro.
  void _forgetBadge() {
    _c.htmlBadgeAnchorId.value = null;
    _c.htmlBadgeVisible.value = true;
  }

  Future<void> _place() async {
    final anchorId = _anchorIdController.text.trim();
    final text = _textController.text;
    await _perform(
      'place',
      (requestId) => _c.placeHtmlBadge(requestId, anchorId: anchorId, text: text),
      (result) {
        if (result['success'] == true) {
          _c.htmlBadgeAnchorId.value = anchorId;
          _c.htmlBadgeText.value = text;
          _c.htmlBadgeVisible.value = true;
          _c.htmlBadgeTapCount.value = 0;
          // Le badge n'est affiché que si l'étage de son POI l'est : même
          // appel que la démo `goto-poi` (et `custom-text-label`).
          unawaited(_c.goToPOI(anchorId));
        } else if (result['previousRemoved'] == true) {
          _forgetBadge();
        }
      },
    );
  }

  Future<void> _updateText() async {
    if (_c.htmlBadgeAnchorId.value == null) return;
    final text = _textController.text;
    await _perform(
      'text',
      (requestId) => _c.updateHtmlBadgeText(requestId, text),
      (result) {
        if (result['success'] == true) _c.htmlBadgeText.value = text;
        if (result['error'] == 'noBadge') _forgetBadge();
      },
    );
  }

  Future<void> _toggleVisible() async {
    if (_c.htmlBadgeAnchorId.value == null) return;
    final visible = !_c.htmlBadgeVisible.value;
    await _perform(
      'visibility',
      (requestId) => _c.setHtmlBadgeVisible(requestId, visible),
      (result) {
        if (result['success'] == true) _c.htmlBadgeVisible.value = visible;
        if (result['error'] == 'noBadge') _forgetBadge();
      },
    );
  }

  Future<void> _remove() async {
    if (_c.htmlBadgeAnchorId.value == null) return;
    await _perform(
      'remove',
      (requestId) => _c.removeHtmlBadge(requestId),
      // Succès, badge déjà inconnu ou rejeté par le SDK : dans tous les
      // cas, le JS a oublié sa référence.
      (result) => _forgetBadge(),
    );
  }

  String _statusText(String? placedOn, int tapCount) {
    if (placedOn == null) return 'No badge placed';
    if (tapCount > 0) return 'Badge tapped ($tapCount)';
    return 'Badge placed on $placedOn';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_c.htmlBadgeAnchorId, _c.htmlBadgeVisible, _c.htmlBadgeTapCount]),
      builder: (context, _) {
        final placedOn = _c.htmlBadgeAnchorId.value;
        final placed = placedOn != null;
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
                  helperText: 'Existing POI that owns the badge and gives its position',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _textController,
                decoration: const InputDecoration(labelText: 'Badge text', isDense: true),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _place,
                      child: const Text('Place badge'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy || !placed ? null : _updateText,
                      child: const Text('Update text'),
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
                      child: Text(_c.htmlBadgeVisible.value ? 'Hide badge' : 'Show badge'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy || !placed ? null : _remove,
                      child: const Text('Remove badge'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? _statusText(placedOn, _c.htmlBadgeTapCount.value),
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
}
