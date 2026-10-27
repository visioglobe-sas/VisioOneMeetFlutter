import 'dart:async';

import 'package:flutter/material.dart';

import '../demo_map.dart';
import '../l10n/app_localizations.dart';
import '../visio_one/simulated_position_session.dart';
import '../visio_one/visio_one_controller.dart';
import '../visio_one/visio_one_message.dart';
import 'simulated_position_overlay.dart';

/// Overlay de la feature `geofencing` : la même UI de tracking que
/// `simulated-position` ([SimulatedPositionOverlay], réutilisée telle quelle,
/// pas dupliquée), suivie en dessous d'un champ "Zone POI ID" et des boutons
/// "Watch zone" / "Clear".
/// La zone est la première surface du POI résolu, testée à chaque tick de
/// [SimulatedPositionSession] contre la position simulée courante
/// (point-in-polygon, voir `lib/visio_one/geofence_utils.dart` — le SDK
/// n'expose aucune primitive de geofencing) ; une entrée/sortie déclenche une
/// alerte visuelle (`venue.updateSurface`) sur la surface de la zone. Voir
/// `docs/features/geofencing.md`.
///
/// Cet overlay ne porte lui-même que l'état de la requête en cours
/// (`_resolving`/`_error`) : la zone surveillée
/// ([SimulatedPositionSession.zonePlaceId]), l'état dedans/dehors
/// ([SimulatedPositionSession.isInsideZone]) et le champ saisi
/// (`controller.panel`) survivent à la fermeture du bottom sheet.
class GeofencingOverlay extends StatefulWidget {
  const GeofencingOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  State<GeofencingOverlay> createState() => _GeofencingOverlayState();
}

class _GeofencingOverlayState extends State<GeofencingOverlay> {
  late final TextEditingController _zoneIdController =
      widget.controller.panel.text('geofencing.zoneId', DemoMap.geofenceZoneId);

  // Requête/réponse par `requestId` sur `controller.messages` — même idiome
  // que `SimulatedPositionOverlay._pendingRequests`.
  final Map<String, Completer<List<SimulatedPosition>?>> _pendingRequests = {};
  StreamSubscription<VisioOneMessage>? _subscription;
  int _requestCounter = 0;

  bool _resolving = false;
  // Erreur de la dernière requête : POI introuvable, ou POI sans surface.
  ({String placeId, bool noSurface})? _error;

  SimulatedPositionSession get _session => widget.controller.simulatedPosition;

  @override
  void initState() {
    super.initState();
    _subscription = widget.controller.messages.listen(_onMessage);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _onMessage(VisioOneMessage message) {
    if (message.type != 'poiZoneResolved') return;
    final data = message.data;
    if (data is! Map) return;
    final requestId = data['requestId'] as String?;
    final completer = requestId != null ? _pendingRequests.remove(requestId) : null;
    completer?.complete(_parsePositions(data['positions']));
  }

  static List<SimulatedPosition>? _parsePositions(Object? raw) {
    if (raw is! List) return null;
    final positions = <SimulatedPosition>[];
    for (final entry in raw) {
      if (entry is! Map) return null;
      final latitude = entry['latitude'];
      final longitude = entry['longitude'];
      if (latitude is! num || longitude is! num) return null;
      positions.add(SimulatedPosition(latitude: latitude.toDouble(), longitude: longitude.toDouble()));
    }
    return positions;
  }

  Future<List<SimulatedPosition>?> _resolveZone(String poiId) {
    final requestId = 'geofencing-zone-${_requestCounter++}';
    final completer = Completer<List<SimulatedPosition>?>();
    _pendingRequests[requestId] = completer;
    widget.controller.resolvePoiZone(requestId, poiId);
    // Un poiId introuvable répond quand même (positions: null, voir
    // map.html) mais ce garde-fou évite d'attendre indéfiniment un message
    // perdu — même idiome que SimulatedPositionOverlay._resolvePosition.
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _pendingRequests.remove(requestId);
        return null;
      },
    );
  }

  Future<void> _watchZone() async {
    final placeId = _zoneIdController.text.trim();
    if (placeId.isEmpty) return;

    setState(() {
      _resolving = true;
      _error = null;
    });

    final positions = await _resolveZone(placeId);
    if (positions == null || positions.isEmpty) {
      if (mounted) {
        setState(() {
          _resolving = false;
          _error = (placeId: placeId, noSurface: positions != null);
        });
      }
      return;
    }

    // Appliqué même si le panneau a été fermé entre-temps (la zone vit sur
    // la session).
    _session.setZone(placeId: placeId, positions: positions);
    if (mounted) setState(() => _resolving = false);
  }

  void _clearZone() {
    setState(() => _error = null);
    _session.setZone(placeId: null, positions: null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final error = _error;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SimulatedPositionOverlay(
          controller: widget.controller,
          initialOriginId: DemoMap.trackingFrom,
          initialDestinationId: DemoMap.trackingTo,
        ),
        const Divider(height: 24),
        TextField(
          controller: _zoneIdController,
          decoration: InputDecoration(labelText: l10n.geofencingZoneLabel, isDense: true),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(
            error.noSurface ? l10n.geofencingZoneNoSurface(error.placeId) : l10n.poiNotFound(error.placeId),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 12),
        ValueListenableBuilder<String?>(
          valueListenable: _session.zonePlaceId,
          builder: (context, watched, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _resolving ? null : _watchZone,
                      child: Text(_resolving ? l10n.resolvingLabel : l10n.geofencingWatchButton),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _resolving || watched == null ? null : _clearZone,
                    child: Text(l10n.clearButton),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(watched == null ? l10n.geofencingNoZone : l10n.geofencingWatching(watched)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        ValueListenableBuilder<bool>(
          valueListenable: _session.isInsideZone,
          builder: (context, isInside, _) {
            return Text(
              isInside ? l10n.geofencingInside : l10n.geofencingOutside,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isInside ? Theme.of(context).colorScheme.error : null,
                fontWeight: FontWeight.bold,
              ),
            );
          },
        ),
      ],
    );
  }
}
