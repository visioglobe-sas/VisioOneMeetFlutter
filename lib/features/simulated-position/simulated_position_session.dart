import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../visio_one/feature_session.dart';
import '../../visio_one/visio_one_controller.dart';
import '../../visio_one/visio_one_message.dart';
import '../accuracy-circle-style/accuracy_circle_style_bridge.dart';
import '../camera-lock-on-position/camera_lock_on_position_bridge.dart';
import '../geofencing/geofence_utils.dart';
import '../geofencing/geofencing_bridge.dart';
import 'simulated_position_bridge.dart';

export 'simulated_position_bridge.dart' show SimulatedPosition;

/// Pilote l'injection d'une position simulée en va-et-vient entre deux
/// points, via des appels périodiques à `SimulatedPositionBridge.injectTrackedPosition`.
///
/// [FeatureSession] de l'écran (créée par `FeatureSpec.createSession` pour
/// `simulated-position`, `camera-lock-on-position`, `geofencing` et
/// `accuracy-circle-style`) plutôt qu'état de l'overlay
/// (`SimulatedPositionOverlay`) : contrairement à cet
/// overlay — recréé à chaque ouverture du bottom sheet, comme tous les
/// overlays de ce dépôt — cette session doit continuer de tourner tant que
/// l'utilisateur n'a pas explicitement appuyé sur Stop, y compris pendant que
/// le panneau est fermé. Seul un Stop explicite, ou la sortie de l'écran de
/// feature (qui détruit tout, `VisioOneController` et `WebView` comprises),
/// doit l'arrêter. C'est la même mécanique de `Timer.periodic` que
/// `OccupancySimulationSession`, session elle aussi.
class SimulatedPositionSession implements FeatureSession {
  SimulatedPositionSession(this._controller) {
    _subscription = _controller.messages.listen((message) {
      if (message.type != 'cameraLockChanged') return;
      final data = message.data;
      final locked = data is Map ? data['locked'] : null;
      if (locked is bool) onCameraLockChanged(locked);
    });
  }

  late final StreamSubscription<VisioOneMessage> _subscription;

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
  double get radiusMeters => _radiusMeters ?? kDefaultRadiusMeters;
  set radiusMeters(double value) => _radiusMeters = value;
  double? _radiusMeters;

  /// Rayon utilisé tant qu'aucun overlay n'en a fixé un (voir [radiusMeters]).
  static const double kDefaultRadiusMeters = 5;

  /// `true` si un rayon a déjà été fixé explicitement sur cette session —
  /// permet à un overlay d'imposer son propre rayon par défaut à la première
  /// ouverture seulement (ex. 6 m pour `accuracy-circle-style`), sans écraser
  /// le choix de l'utilisateur aux réouvertures suivantes du bottom sheet.
  bool get hasRadius => _radiusMeters != null;

  /// Style graphique (couleur hex + opacité) du cercle de précision de la
  /// position trackée (pas de la flèche centrale), choisi par la démo `accuracy-circle-style`
  /// (`null` = jamais choisi : les autres features gardent le style par
  /// défaut du SDK, aucun appel n'est fait). Porté ici, comme
  /// [isCameraLocked], pour survivre à la fermeture/réouverture du bottom
  /// sheet — et parce que le SDK n'expose aucun getter pour le relire.
  String? get trackerColor => _trackerColor;
  double? get trackerOpacity => _trackerOpacity;
  String? _trackerColor;
  double? _trackerOpacity;

  /// Mémorise le style et l'envoie immédiatement au SDK
  /// (`view.updatePositionTrackerGraphicOptions`). Sans danger hors tracking
  /// : le SDK ne fait que stocker ces options, appliquées au prochain
  /// `injectTrackedPosition` (donc au prochain tick, ~150 ms, si la
  /// simulation tourne). Voir `docs/features/accuracy-circle-style.md`.
  void setTrackerGraphicOptions({required String color, required double opacity}) {
    _trackerColor = color;
    _trackerOpacity = opacity;
    _controller.updatePositionTrackerGraphicOptions(color: color, opacity: opacity);
  }

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
  ///
  /// Simple MIROIR de l'état SDK, jamais écrit par l'app elle-même : mis à
  /// jour uniquement par [onCameraLockChanged], sur les events SDK
  /// `trackingon` (Start : le SDK verrouille de lui-même), `trackingoff`
  /// (Stop : déverrouillé) et `trackingchanged` (interrupteur, ou pan de la
  /// carte qui déverrouille). Voir `docs/features/camera-lock-on-position.md`.
  final ValueNotifier<bool> isCameraLocked = ValueNotifier<bool>(false);

  /// Id du POI zone actuellement surveillé par la démo `geofencing` (ou
  /// `null` si aucune zone n'est configurée) — voir [setZone]. Observable
  /// pour que le panneau rouvert affiche la zone surveillée.
  final ValueNotifier<String?> zonePlaceId = ValueNotifier<String?>(null);

  /// Polygone WGS84 déjà résolu pour [zonePlaceId] (`poi.surfaces[0].positions`,
  /// via `GeofencingBridge.resolvePoiZone`).
  List<SimulatedPosition>? _zonePositions;

  /// `true` si la position trackée courante est à l'intérieur de la zone
  /// configurée par [setZone]. Portée ici plutôt que par l'overlay de la
  /// feature, pour la même raison que [isCameraLocked] : reste cohérente
  /// même si l'overlay est recréé (réouverture du bottom sheet) pendant que
  /// la session tourne, et sert à ne rappeler
  /// `GeofencingBridge.setZoneAlert` qu'aux transitions (voir
  /// [_updateZoneAlert]), pas à chaque tick. Voir
  /// `docs/features/geofencing.md`.
  final ValueNotifier<bool> isInsideZone = ValueNotifier<bool>(false);

  /// Configure (ou retire, si [positions] est `null`) la zone de geofencing
  /// à tester à chaque tick de [_tick] contre la position simulée courante.
  /// N'exige pas que la simulation soit démarrée : le polygone est
  /// simplement mémorisé, testé dès le prochain tick si/quand [start] tourne
  /// déjà ou tourne plus tard — voir `docs/features/geofencing.md`.
  void setZone({required String? placeId, required List<SimulatedPosition>? positions}) {
    // Retire l'alerte de l'ancienne zone avant d'en changer.
    _updateZoneAlert(false);
    zonePlaceId.value = placeId;
    _zonePositions = positions;
  }

  void _updateZoneAlert(bool inside) {
    if (_disposed || isInsideZone.value == inside) return;
    isInsideZone.value = inside;
    final placeId = zonePlaceId.value;
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
    // Le SDK remet couleur/opacité à ses valeurs par défaut à chaque
    // `allowTracking = false` (voir [stop]) : on réapplique le style choisi
    // avant le premier `injectTrackedPosition` de cette simulation.
    final color = _trackerColor;
    final opacity = _trackerOpacity;
    if (color != null && opacity != null) {
      _controller.updatePositionTrackerGraphicOptions(color: color, opacity: opacity);
    }
    _tick();
    _timer = Timer.periodic(_tickInterval, (_) => _tick());
  }

  /// Verrouille/déverrouille la caméra sur la position trackée courante.
  /// N'a d'effet visible côté SDK que si la simulation tourne déjà
  /// (`view.allowTracking = true`, activé par [start]) — voir
  /// `docs/features/camera-lock-on-position.md`. Ne touche pas
  /// [isCameraLocked] : c'est l'event SDK `trackingchanged` en retour (via
  /// [onCameraLockChanged]) qui le met à jour.
  void setCameraLocked(bool locked) => _controller.setCameraLockOnPosition(locked);

  /// Appelé à chaque message `cameraLockChanged`
  /// (relais des events SDK `trackingon`/`trackingoff`/`trackingchanged`,
  /// voir `assets/www/features/camera-lock-on-position.js`).
  /// Ignoré après [dispose] (un dernier event peut encore arriver de la
  /// WebView pendant la destruction de l'écran).
  void onCameraLockChanged(bool locked) {
    if (_disposed) return;
    isCameraLocked.value = locked;
  }

  bool _disposed = false;

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
  /// (`allowTracking = false`, voir `SimulatedPositionBridge.stopTrackedPosition`
  /// — pas de méthode dédiée côté SDK pour les effacer autrement).
  ///
  /// `isCameraLocked` repasse à `false` tout seul : `allowTracking = false`
  /// déverrouille côté SDK et émet `trackingoff` (voir [onCameraLockChanged]).
  void stop() {
    if (_disposed) return;
    final wasRunning = _timer != null;
    _timer?.cancel();
    _timer = null;
    _origin = null;
    _destination = null;
    if (wasRunning) {
      _controller.stopTrackedPosition();
    }
    isRunning.value = false;
    // Revert l'alerte visuelle de zone (si elle était active) mais garde la
    // zone elle-même configurée (`zonePlaceId`/`_zonePositions`) : un
    // redémarrage doit reprendre la surveillance sans ressaisir le POI zone.
    _updateZoneAlert(false);
  }

  /// À appeler depuis `VisioOneController.dispose()` — annule le `Timer` en
  /// cours plutôt que de le laisser tourner sur un contrôleur/WebView détruit.
  /// Pas d'appel `stopTrackedPosition` ici, contrairement à [stop] : la
  /// WebView est de toute façon en train d'être détruite avec le reste de
  /// l'écran de feature. La sortie de l'écran
  /// (Retour depuis `FeatureScreen`) reste couverte côté UX : chaque écran de
  /// feature recrée son propre `VisioOneController`/`SimulatedPositionSession`
  /// (voir `VisioOneMapShell`), donc `isCameraLocked` redémarre toujours à
  /// `false` à la prochaine ouverture, sans état qui traverserait deux
  /// visites de l'écran.
  @override
  void dispose() {
    _disposed = true;
    _subscription.cancel();
    _timer?.cancel();
    isRunning.dispose();
    isCameraLocked.dispose();
    isInsideZone.dispose();
    zonePlaceId.dispose();
  }
}
