import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../visio_one/feature_session.dart';
import '../../visio_one/visio_one_controller.dart';
import 'occupancy_simulated_bridge.dart';

/// Pilote la démo `occupancy-simulated` : fait tourner la couleur d'une
/// surface sur un minuteur, à la place d'un vrai flux de capteurs
/// d'occupation (voir `docs/features/occupancy-simulated.md`).
///
/// [FeatureSession] de l'écran (une instance par écran), pas portée par le
/// panneau : fermer le panneau, nécessaire pour voir la carte, ne doit ni
/// arrêter la simulation ni faire oublier qu'elle tourne. Il n'y a jamais
/// qu'un seul minuteur ; quitter l'écran l'annule ([dispose]).
class OccupancySimulationSession implements FeatureSession {
  OccupancySimulationSession(this._controller);

  /// Libre / bientôt occupé / occupé.
  static const List<String> kColors = ['#2ECC71', '#F1C40F', '#E74C3C'];
  static const Duration kInterval = Duration(milliseconds: 2500);

  final VisioOneController _controller;
  Timer? _timer;
  int _colorIndex = 0;
  bool _disposed = false;

  /// Id de la place dont l'occupation est simulée, `null` à l'arrêt.
  final ValueNotifier<String?> runningPlaceId = ValueNotifier<String?>(null);

  /// Démarre (ou redémarre sur [placeId]) la simulation.
  void start(String placeId) {
    stop();
    runningPlaceId.value = placeId;
    _colorIndex = 0;
    _apply(placeId);
    _timer = Timer.periodic(kInterval, (_) {
      _colorIndex = (_colorIndex + 1) % kColors.length;
      _apply(placeId);
    });
  }

  void _apply(String placeId) => _controller.updateOccupancy([
    {'planId': placeId, 'color': kColors[_colorIndex]},
  ]);

  /// Arrête la simulation et rend sa couleur d'origine à la surface simulée
  /// (pas à celle saisie entre-temps dans le champ).
  void stop() {
    _timer?.cancel();
    _timer = null;
    final placeId = runningPlaceId.value;
    if (placeId == null) return;
    _controller.updateOccupancy([
      {'planId': placeId, 'color': null},
    ]);
    if (!_disposed) runningPlaceId.value = null;
  }

  /// Appelée par `VisioOneController.dispose()` : la WebView est détruite
  /// avec l'écran, seul le minuteur reste à annuler.
  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    runningPlaceId.dispose();
  }
}
