import 'dart:async';

import 'package:flutter/foundation.dart';

import 'geofence_utils.dart';
import 'visio_one_controller.dart';

/// Coordonnées WGS84 minimales nécessaires à l'interpolation — pas besoin
/// d'altitude pour cette démo, voir `docs/features/simulated-position.md`.
class SimulatedPosition {
  const SimulatedPosition({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

/// Pilote l'injection d'une position simulée en va-et-vient entre deux
/// points, via des appels périodiques à `VisioOneController.injectTrackedPosition`.
///
/// Portée par [VisioOneController] (une instance par carte, créée dans son
/// constructeur privé) plutôt que par l'overlay de la feature
/// (`SimulatedPositionOverlay`, dans `lib/features/`) : contrairement à cet
/// overlay — recréé à chaque ouverture du bottom sheet, comme tous les
/// overlays de ce dépôt — cette session doit continuer de tourner tant que
/// l'utilisateur n'a pas explicitement appuyé sur Stop, y compris pendant que
/// le panneau est fermé. Seul un Stop explicite, ou la sortie de l'écran de
/// feature (qui détruit tout, `VisioOneController` et `WebView` comprises),
/// doit l'arrêter. C'est la même mécanique de `Timer.periodic` que
/// `OccupancySimulationOverlay` (voir `docs/features/occupancy-simulated.md`),
/// juste déplacée d'un `State` de `StatefulWidget` (qui ne survit pas à la
/// fermeture du bottom sheet) vers un objet porté par le contrôleur (qui y
/// survit).
class SimulatedPositionSession {
  SimulatedPositionSession(this._controller);

  static const Duration _tickInterval = Duration(milliseconds: 150);

  // Fraction du trajet parcourue à chaque tick : ~25 ticks pour un aller
  // simple (~3,75 s), un rythme de marche plausible pour une démo.
  static const double _stepPerTick = 0.04;

  final VisioOneController _controller;

  Timer? _timer;
  SimulatedPosition? _origin;
  SimulatedPosition? _destination;
  double _t = 0;
  double _direction = 1;

  /// Rayon du cercle de précision courant, en mètres. Modifiable même pendant
  /// que la simulation tourne : pris en compte au prochain tick (voir
  /// [_tick]), pas besoin de relancer. Lu par l'overlay pour préremplir son
  /// slider si le panneau est rouvert pendant que la session tourne déjà.
  double radiusMeters = 5;

  /// `true` tant que le va-et-vient tourne. Exposé en [ValueNotifier] pour
  /// que l'overlay affiche le bon état (Start/Stop) même s'il est recréé
  /// (réouverture du bottom sheet) pendant que la session continue de
  /// tourner en arrière-plan.
  final ValueNotifier<bool> isRunning = ValueNotifier<bool>(false);

  /// `true` si la caméra est verrouillée sur la position trackée courante
  /// (`view.lockCameraPositionOnTracking`, feature `camera-lock-on-position`).
  /// Portée ici plutôt que par l'overlay de cette feature, pour la même
  /// raison que [isRunning] : elle doit rester cohérente même si l'overlay
  /// est recréé (réouverture du bottom sheet) pendant que la session tourne.
  /// Toujours remise à `false` par [start] et [stop] — voir
  /// `docs/features/camera-lock-on-position.md`, "Points d'attention", pour
  /// pourquoi ce verrou ne doit jamais survivre à un redémarrage/arrêt.
  final ValueNotifier<bool> isCameraLocked = ValueNotifier<bool>(false);

  /// Id du POI zone actuellement surveillé par la démo `geofencing` (ou
  /// `null` si aucune zone n'est configurée), et le polygone WGS84 déjà
  /// résolu pour ce POI (`poi.surfaces[0].positions`, via
  /// `VisioOneController.resolvePoiZone`) — voir [setZone].
  String? _zonePlaceId;
  List<SimulatedPosition>? _zonePositions;

  /// `true` si la position trackée courante est à l'intérieur de la zone
  /// configurée par [setZone]. Portée ici plutôt que par l'overlay de la
  /// feature, pour la même raison que [isCameraLocked] : reste cohérente
  /// même si l'overlay est recréé (réouverture du bottom sheet) pendant que
  /// la session tourne, et sert à ne rappeler
  /// `VisioOneController.setZoneAlert` qu'aux transitions (voir
  /// [_updateZoneAlert]), pas à chaque tick. Voir
  /// `docs/features/geofencing.md`.
  final ValueNotifier<bool> isInsideZone = ValueNotifier<bool>(false);

  /// Configure (ou retire, si [positions] est `null`) la zone de geofencing
  /// à tester à chaque tick de [_tick] contre la position simulée courante.
  /// N'exige pas que la simulation soit démarrée : le polygone est
  /// simplement mémorisé, testé dès le prochain tick si/quand [start] tourne
  /// déjà ou tourne plus tard — voir `docs/features/geofencing.md`.
  void setZone({required String? placeId, required List<SimulatedPosition>? positions}) {
    _zonePlaceId = placeId;
    _zonePositions = positions;
    _updateZoneAlert(false);
  }

  void _updateZoneAlert(bool inside) {
    if (isInsideZone.value == inside) return;
    isInsideZone.value = inside;
    final placeId = _zonePlaceId;
    if (placeId != null) _controller.setZoneAlert(placeId, inside);
  }

  /// Démarre (ou redémarre, si déjà en cours) le va-et-vient entre [origin]
  /// et [destination].
  void start({required SimulatedPosition origin, required SimulatedPosition destination}) {
    _timer?.cancel();
    _origin = origin;
    _destination = destination;
    _t = 0;
    _direction = 1;
    isRunning.value = true;
    // Chaque (re)démarrage repart verrouillage désactivé : un opt-in
    // délibéré à chaque fois, pas un état qui traîne d'une simulation
    // précédente.
    _setCameraLocked(false);
    _tick();
    _timer = Timer.periodic(_tickInterval, (_) => _tick());
  }

  /// Verrouille/déverrouille la caméra sur la position trackée courante.
  /// N'a d'effet visible côté SDK que si la simulation tourne déjà
  /// (`view.allowTracking = true`, activé par [start]) — voir
  /// `docs/features/camera-lock-on-position.md`.
  void setCameraLocked(bool locked) => _setCameraLocked(locked);

  void _setCameraLocked(bool locked) {
    if (isCameraLocked.value == locked) return;
    isCameraLocked.value = locked;
    _controller.setCameraLockOnPosition(locked);
  }

  void _tick() {
    final origin = _origin;
    final destination = _destination;
    if (origin == null || destination == null) return;

    final latitude = origin.latitude + (destination.latitude - origin.latitude) * _t;
    final longitude = origin.longitude + (destination.longitude - origin.longitude) * _t;

    _controller.injectTrackedPosition(
      latitude: latitude,
      longitude: longitude,
      precisionCircleRadius: radiusMeters,
    );

    // `geofencing` : testé à chaque tick plutôt que sur un event dédié — le
    // SDK n'émet aucun `trackedpositionchanged` (voir
    // docs/features/geofencing.md), cette boucle déjà existante pour
    // l'injection de position est le point d'accroche naturel.
    final zonePositions = _zonePositions;
    if (zonePositions != null) {
      _updateZoneAlert(
        isPointInPolygon(latitude: latitude, longitude: longitude, polygon: zonePositions),
      );
    }

    _t += _stepPerTick * _direction;
    if (_t >= 1) {
      _t = 1;
      _direction = -1;
    } else if (_t <= 0) {
      _t = 0;
      _direction = 1;
    }
  }

  /// Arrête le va-et-vient et retire le marqueur/cercle de la carte
  /// (`allowTracking = false`, voir `VisioOneController.stopTrackedPosition`
  /// — pas de méthode dédiée côté SDK pour les effacer autrement).
  ///
  /// Déverrouille aussi systématiquement la caméra (`isCameraLocked`) : un
  /// Stop explicite doit laisser la prochaine simulation repartir
  /// déverrouillée (voir aussi [start], qui fait la même remise à zéro à
  /// chaque (re)démarrage).
  void stop() {
    final wasRunning = _timer != null;
    _timer?.cancel();
    _timer = null;
    _origin = null;
    _destination = null;
    if (wasRunning) {
      _controller.stopTrackedPosition();
    }
    isRunning.value = false;
    _setCameraLocked(false);
    // Revert l'alerte visuelle de zone (si elle était active) mais garde la
    // zone elle-même configurée (`_zonePlaceId`/`_zonePositions`) : un
    // redémarrage doit reprendre la surveillance sans ressaisir le POI zone
    // — contrairement à `isCameraLocked`, ce n'est pas un opt-in à refaire
    // à chaque (re)démarrage.
    _updateZoneAlert(false);
  }

  /// À appeler depuis `VisioOneController.dispose()` — annule le `Timer` en
  /// cours plutôt que de le laisser tourner sur un contrôleur/WebView détruit.
  /// Pas d'appel `stopTrackedPosition`/`setCameraLockOnPosition(false)` ici,
  /// comme pour [stop] : la WebView est de toute façon en train d'être
  /// détruite avec le reste de l'écran de feature. La sortie de l'écran
  /// (Retour depuis `FeatureScreen`) reste couverte côté UX : chaque écran de
  /// feature recrée son propre `VisioOneController`/`SimulatedPositionSession`
  /// (voir `VisioOneMapShell`), donc `isCameraLocked` redémarre toujours à
  /// `false` à la prochaine ouverture, sans état qui traverserait deux
  /// visites de l'écran.
  void dispose() {
    _timer?.cancel();
    isRunning.dispose();
    isCameraLocked.dispose();
    isInsideZone.dispose();
  }
}
