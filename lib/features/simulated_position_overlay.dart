import 'dart:async';

import 'package:flutter/material.dart';

import '../visio_one/simulated_position_session.dart';
import '../visio_one/visio_one_controller.dart';
import '../visio_one/visio_one_message.dart';

const double _minRadiusMeters = 1;
const double _maxRadiusMeters = 20;

/// Overlay de la feature `simulated-position` : deux champs Place ID
/// ("Origin"/"Destination"), un slider de rayon de précision (mètres) et un
/// bouton toggle Start/Stop, affiché dans le bottom sheet ouvert par le FAB
/// de [VisioOneMapShell]. Anime une position trackée simulée en va-et-vient
/// entre les deux POI via `view.injectTrackedPosition`, en lieu et place
/// d'un vrai flux de positionnement indoor. Voir
/// `docs/features/simulated-position.md`.
///
/// Le va-et-vient lui-même (`Timer.periodic`) est porté par
/// [VisioOneController.simulatedPosition], pas par le `State` de ce widget :
/// contrairement à `OccupancySimulationOverlay` (dont le timer s'arrête dès
/// que le bottom sheet est fermé, ce `State` étant alors détruit), cette
/// simulation doit continuer tant que l'utilisateur n'a pas appuyé sur Stop,
/// même panneau fermé — voir le commentaire de tête de
/// `SimulatedPositionSession`. Ce `State` ne fait que démarrer/arrêter la
/// session et refléter son état courant (`ValueListenableBuilder` sur
/// `session.isRunning`).
class SimulatedPositionOverlay extends StatefulWidget {
  const SimulatedPositionOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  State<SimulatedPositionOverlay> createState() => _SimulatedPositionOverlayState();
}

class _SimulatedPositionOverlayState extends State<SimulatedPositionOverlay> {
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  // Requête/réponse par `requestId` sur `controller.messages` (même idiom que
  // `venueLayout` pour `floor-selector`, adapté ici à deux requêtes
  // concurrentes — origine + destination — qu'il faut pouvoir distinguer).
  final Map<String, Completer<Map<String, double>?>> _pendingRequests = {};
  StreamSubscription<VisioOneMessage>? _subscription;
  int _requestCounter = 0;

  late double _radiusMeters;
  bool _resolving = false;
  String? _error;

  SimulatedPositionSession get _session => widget.controller.simulatedPosition;

  @override
  void initState() {
    super.initState();
    // Reflète le rayon courant de la session (utile si le panneau est
    // rouvert pendant qu'une simulation tourne déjà), pas un rayon par
    // défaut recalculé à chaque ouverture.
    _radiusMeters = _session.radiusMeters;
    _subscription = widget.controller.messages.listen(_onMessage);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _originController.dispose();
    _destinationController.dispose();
    // La session (Timer, allowTracking) n'est volontairement PAS arrêtée
    // ici : elle doit survivre à la fermeture de ce panneau, voir le
    // commentaire de tête de cette classe.
    super.dispose();
  }

  void _onMessage(VisioOneMessage message) {
    if (message.type != 'poiPositionResolved') return;
    final data = message.data;
    if (data is! Map) return;
    final requestId = data['requestId'] as String?;
    final completer = requestId != null ? _pendingRequests.remove(requestId) : null;
    completer?.complete(_parsePosition(data['position']));
  }

  static Map<String, double>? _parsePosition(Object? raw) {
    if (raw is! Map) return null;
    final latitude = raw['latitude'];
    final longitude = raw['longitude'];
    if (latitude is! num || longitude is! num) return null;
    return {'latitude': latitude.toDouble(), 'longitude': longitude.toDouble()};
  }

  Future<Map<String, double>?> _resolvePosition(String poiId) {
    final requestId = 'simulated-position-${_requestCounter++}';
    final completer = Completer<Map<String, double>?>();
    _pendingRequests[requestId] = completer;
    widget.controller.resolvePoiPosition(requestId, poiId);
    // Un poiId introuvable répond quand même (position: null, voir map.html)
    // mais ce garde-fou évite d'attendre indéfiniment un message perdu.
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _pendingRequests.remove(requestId);
        return null;
      },
    );
  }

  void _toggleSimulation() {
    if (_session.isRunning.value) {
      _session.stop();
    } else {
      _startSimulation();
    }
  }

  Future<void> _startSimulation() async {
    final originId = _originController.text.trim();
    final destinationId = _destinationController.text.trim();
    if (originId.isEmpty || destinationId.isEmpty) return;

    setState(() {
      _resolving = true;
      _error = null;
    });

    final origin = await _resolvePosition(originId);
    if (!mounted) return;
    if (origin == null) {
      setState(() {
        _resolving = false;
        _error = 'POI not found: $originId';
      });
      return;
    }

    final destination = await _resolvePosition(destinationId);
    if (!mounted) return;
    if (destination == null) {
      setState(() {
        _resolving = false;
        _error = 'POI not found: $destinationId';
      });
      return;
    }

    _session.radiusMeters = _radiusMeters;
    _session.start(
      origin: SimulatedPosition(latitude: origin['latitude']!, longitude: origin['longitude']!),
      destination: SimulatedPosition(
        latitude: destination['latitude']!,
        longitude: destination['longitude']!,
      ),
    );
    setState(() => _resolving = false);
  }

  void _onRadiusChanged(double value) {
    setState(() => _radiusMeters = value);
    // S'applique dès le prochain tick si la simulation tourne déjà — pas
    // besoin de relancer, voir `SimulatedPositionSession._tick`.
    _session.radiusMeters = value;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _session.isRunning,
      builder: (context, isRunning, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _originController,
              enabled: !isRunning,
              decoration: const InputDecoration(hintText: 'Origin POI ID', isDense: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _destinationController,
              enabled: !isRunning,
              decoration: const InputDecoration(hintText: 'Destination POI ID', isDense: true),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Accuracy radius'),
                Expanded(
                  child: Slider(
                    value: _radiusMeters,
                    min: _minRadiusMeters,
                    max: _maxRadiusMeters,
                    divisions: (_maxRadiusMeters - _minRadiusMeters).toInt(),
                    label: '${_radiusMeters.round()} m',
                    onChanged: _onRadiusChanged,
                  ),
                ),
                SizedBox(width: 36, child: Text('${_radiusMeters.round()} m')),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _resolving ? null : _toggleSimulation,
              child: Text(
                _resolving
                    ? 'Resolving…'
                    : isRunning
                    ? 'Stop simulated position'
                    : 'Simulate position',
              ),
            ),
          ],
        );
      },
    );
  }
}
