import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../visio_one/visio_one_controller.dart';
import 'simulated_position_bridge.dart';
import 'simulated_position_session.dart';

const double _minRadiusMeters = 1;
const double _maxRadiusMeters = 20;

/// Overlay de la feature `simulated-position` : deux champs Place ID
/// ("Origin"/"Destination"), un slider de rayon de précision (mètres) et un
/// bouton toggle Start/Stop, affiché dans le bottom sheet ouvert par le FAB
/// de `VisioOneMapShell`. Anime une position trackée simulée en va-et-vient
/// entre les deux POI via `view.injectTrackedPosition`, en lieu et place
/// d'un vrai flux de positionnement indoor. Voir
/// `docs/features/simulated-position.md`.
///
/// Le va-et-vient lui-même (`Timer.periodic`) est porté par la session de
/// l'écran ([SimulatedPositionSession]), pas par le `State` de ce widget :
/// la simulation doit continuer tant que l'utilisateur n'a pas appuyé sur
/// Stop, même panneau fermé — voir le commentaire de tête de
/// `SimulatedPositionSession`. Les ids saisis vivent dans
/// `controller.panel` (clés `tracking.origin` / `tracking.destination`) : le
/// panneau rouvert affiche les POI entre lesquels la position se déplace.
/// Ce `State` ne fait que démarrer/arrêter la session et refléter son état
/// courant (`ValueListenableBuilder` sur `session.isRunning`).
class SimulatedPositionOverlay extends StatefulWidget {
  const SimulatedPositionOverlay({
    super.key,
    required this.controller,
    this.initialOriginId,
    this.initialDestinationId,
    this.initialRadiusMeters,
  });

  final VisioOneController controller;

  /// Valeurs par défaut des champs Origin/Destination (première ouverture).
  final String? initialOriginId;
  final String? initialDestinationId;

  /// Rayon par défaut imposé à la session si aucun rayon n'y a encore été
  /// fixé (voir [SimulatedPositionSession.hasRadius]) ; `null` = celui de la
  /// session ([SimulatedPositionSession.kDefaultRadiusMeters]).
  final double? initialRadiusMeters;

  @override
  State<SimulatedPositionOverlay> createState() => _SimulatedPositionOverlayState();
}

class _SimulatedPositionOverlayState extends State<SimulatedPositionOverlay> {
  late final TextEditingController _originController;
  late final TextEditingController _destinationController;

  late double _radiusMeters;
  bool _resolving = false;
  // Id du POI introuvable lors du dernier Start, affiché traduit.
  String? _notFoundId;

  SimulatedPositionSession get _session => widget.controller.session<SimulatedPositionSession>();

  @override
  void initState() {
    super.initState();
    // Reflète le rayon courant de la session (utile si le panneau est
    // rouvert pendant qu'une simulation tourne déjà), pas un rayon par
    // défaut recalculé à chaque ouverture.
    final initialRadius = widget.initialRadiusMeters;
    if (initialRadius != null && !_session.hasRadius) {
      _session.radiusMeters = initialRadius;
    }
    _radiusMeters = _session.radiusMeters;
    _originController = widget.controller.panel.text('tracking.origin', widget.initialOriginId ?? '');
    _destinationController = widget.controller.panel.text('tracking.destination', widget.initialDestinationId ?? '');
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
      _notFoundId = null;
    });

    // `null` si le POI est introuvable (ou sans réponse du pont à temps).
    final origin = await widget.controller.resolvePoiPosition(originId);
    final destination = origin == null ? null : await widget.controller.resolvePoiPosition(destinationId);
    if (origin == null || destination == null) {
      if (mounted) {
        setState(() {
          _resolving = false;
          _notFoundId = origin == null ? originId : destinationId;
        });
      }
      return;
    }

    // Démarre même si le panneau a été fermé entre-temps : la session vit
    // sur le contrôleur, le panneau rouvert affichera "Stop".
    _session.radiusMeters = _radiusMeters;
    _session.start(origin: origin, destination: destination);
    if (mounted) setState(() => _resolving = false);
  }

  void _onRadiusChanged(double value) {
    setState(() => _radiusMeters = value);
    // S'applique dès le prochain tick si la simulation tourne déjà — pas
    // besoin de relancer, voir `SimulatedPositionSession._tick`.
    _session.radiusMeters = value;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
              decoration: InputDecoration(labelText: l10n.trackingOriginLabel, isDense: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _destinationController,
              enabled: !isRunning,
              decoration: InputDecoration(labelText: l10n.trackingDestinationLabel, isDense: true),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(l10n.trackingRadiusLabel),
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
            if (_notFoundId != null) ...[
              const SizedBox(height: 4),
              Text(l10n.poiNotFound(_notFoundId!), style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _resolving ? null : _toggleSimulation,
              child: Text(
                _resolving
                    ? l10n.resolvingLabel
                    : isRunning
                    ? l10n.trackingStopButton
                    : l10n.trackingStartButton,
              ),
            ),
          ],
        );
      },
    );
  }
}
