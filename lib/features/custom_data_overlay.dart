import 'dart:async';

import 'package:flutter/material.dart';

import '../visio_one/visio_one_controller.dart';
import '../visio_one/visio_one_message.dart';

/// Résultat d'un chargement de CustomData — voir `_CustomDataOverlayState._load`.
class _CustomDataResult {
  const _CustomDataResult({required this.found, required this.customData});

  final bool found;
  final Map<String, String> customData;
}

/// Overlay de la feature `custom-data` : un champ Place ID + un bouton
/// "Load", affiché dans le bottom sheet ouvert par le FAB de
/// [VisioOneMapShell]. "Load" enchaîne les deux appels SDK exigés par cette
/// démo en une seule commande de pont — `venue.refreshCustomData()` puis
/// `venue.getPOICustomData(poi)` côté JS (voir `assets/www/map.html`,
/// `window.MapBridge.loadCustomData`) — plutôt que deux boutons séparés,
/// cohérent avec `startItinerary` qui enchaîne déjà plusieurs appels SDK
/// côté JS pour une seule commande Native -> JS. Voir
/// `docs/features/custom-data.md`.
class CustomDataOverlay extends StatefulWidget {
  const CustomDataOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  State<CustomDataOverlay> createState() => _CustomDataOverlayState();
}

/// Place IDs confirmés (via `mapserver.visioglobe.com`) comme portant de
/// vraies `CustomData` sur la carte `kCustomDataMapHash` utilisée par cette
/// démo (voir `VisioOneMapShell`/`lib/features/feature_screen.dart` et
/// `docs/features/custom-data.md`) — proposés en accès rapide ci-dessous
/// pour ne pas obliger à connaître/taper un Place ID à la main pour voir un
/// résultat non vide.
const List<String> _kKnownPoiIdsWithCustomData = ['B1', 'B3-UL00-ID0065', 'B3-UL00-ID0064'];

class _CustomDataOverlayState extends State<CustomDataOverlay> {
  final TextEditingController _placeIdController = TextEditingController();

  // Requête/réponse par `requestId` sur `controller.messages` (même idiom
  // que `poiPositionResolved` pour `simulated-position`).
  final Map<String, Completer<_CustomDataResult>> _pendingRequests = {};
  StreamSubscription<VisioOneMessage>? _subscription;
  int _requestCounter = 0;

  bool _loading = false;
  // null = rien chargé encore ; sinon dernier résultat affiché, avec le
  // Place ID qui l'a produit (peut différer du contenu courant du champ
  // texte si l'utilisateur l'a modifié depuis le dernier "Load").
  bool? _found;
  Map<String, String>? _customData;
  String? _lastPoiId;

  @override
  void initState() {
    super.initState();
    _subscription = widget.controller.messages.listen(_onMessage);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _placeIdController.dispose();
    super.dispose();
  }

  void _onMessage(VisioOneMessage message) {
    if (message.type != 'customDataLoaded') return;
    final data = message.data;
    if (data is! Map) return;
    final requestId = data['requestId'] as String?;
    final completer = requestId != null ? _pendingRequests.remove(requestId) : null;
    if (completer == null) return;

    final found = data['found'] == true;
    final rawCustomData = data['customData'];
    final customData = <String, String>{};
    if (rawCustomData is Map) {
      for (final entry in rawCustomData.entries) {
        customData[entry.key.toString()] = entry.value.toString();
      }
    }
    completer.complete(_CustomDataResult(found: found, customData: customData));
  }

  /// Remplit le champ Place ID avec un des [_kKnownPoiIdsWithCustomData] et
  /// lance immédiatement le chargement — un seul tap pour voir une vraie
  /// liste clé/valeur non vide, plutôt que de devoir taper l'ID à la main
  /// puis appuyer sur "Load".
  void _loadKnownPoi(String poiId) {
    _placeIdController.text = poiId;
    _load();
  }

  Future<void> _load() async {
    final poiId = _placeIdController.text.trim();
    if (poiId.isEmpty) return;

    final requestId = 'custom-data-${_requestCounter++}';
    final completer = Completer<_CustomDataResult>();
    _pendingRequests[requestId] = completer;

    setState(() {
      _loading = true;
      _found = null;
      _customData = null;
    });

    widget.controller.loadCustomData(requestId, poiId);
    // Un poiId introuvable répond quand même (found: false, voir map.html)
    // mais ce garde-fou évite d'attendre indéfiniment un message perdu.
    final result = await completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _pendingRequests.remove(requestId);
        return const _CustomDataResult(found: false, customData: <String, String>{});
      },
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _found = result.found;
      _customData = result.customData;
      _lastPoiId = poiId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Known POIs with real custom data:', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final poiId in _kKnownPoiIdsWithCustomData)
              ActionChip(
                label: Text(poiId),
                onPressed: _loading ? null : () => _loadKnownPoi(poiId),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _placeIdController,
                decoration: const InputDecoration(hintText: 'Place ID', isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _loading ? null : _load,
              child: Text(_loading ? 'Loading…' : 'Load'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildResult(context),
      ],
    );
  }

  Widget _buildResult(BuildContext context) {
    final found = _found;
    if (found == null) return const SizedBox.shrink();

    if (!found) {
      return Text(
        'POI not found: $_lastPoiId',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }

    final customData = _customData ?? const <String, String>{};
    if (customData.isEmpty) {
      return const Text('No custom data for this POI.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final entry in customData.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text('${entry.key}: ${entry.value}'),
          ),
      ],
    );
  }
}
