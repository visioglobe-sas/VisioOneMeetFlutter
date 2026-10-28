import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../demo_map.dart';
import '../../visio_one/feature_session.dart';
import '../../visio_one/visio_one_controller.dart';
import '../../visio_one/visio_one_message.dart';
import 'camera_showcase_carousel_bridge.dart';

/// État de la visite caméra `camera-showcase-carousel`, tel que rapporté par
/// `assets/www/features/camera-showcase-carousel.js` (message `carouselState`).
enum CameraCarouselState { stopped, running, paused }

/// Instantané immuable de la visite : état + arrêt courant (1-based), pour
/// la ligne de statut du panneau.
@immutable
class CameraCarouselStatus {
  const CameraCarouselStatus({required this.state, this.index, this.total, this.poiId});

  static const CameraCarouselStatus stopped = CameraCarouselStatus(state: CameraCarouselState.stopped);

  final CameraCarouselState state;

  /// Numéro (1-based) de l'arrêt en cours / interrompu, `null` si arrêtée.
  final int? index;
  final int? total;
  final String? poiId;

  /// Parse les données d'un message `carouselState`
  /// (`{state, index, total, poiId}`), ou `null` si illisibles.
  static CameraCarouselStatus? fromMessageData(Object? data) {
    if (data is! Map) return null;
    final state = switch (data['state']) {
      'running' => CameraCarouselState.running,
      'paused' => CameraCarouselState.paused,
      'stopped' => CameraCarouselState.stopped,
      _ => null,
    };
    if (state == null) return null;
    final index = data['index'];
    final total = data['total'];
    final poiId = data['poiId'];
    return CameraCarouselStatus(
      state: state,
      index: index is num ? index.toInt() : null,
      total: total is num ? total.toInt() : null,
      poiId: poiId is String ? poiId : null,
    );
  }
}

/// Pilote la visite caméra automatique `camera-showcase-carousel`.
///
/// La boucle elle-même (`goToFloor` -> `goToPOI` -> pause de 3 s, en boucle)
/// tourne côté JS, dans `assets/www/features/camera-showcase-carousel.js` —
/// au niveau de la page, pas du panneau —
/// ainsi que la détection des touchers sur la carte (pause) et le minuteur
/// de reprise de 10 s. Cette session ([FeatureSession] de l'écran, comme
/// `SimulatedPositionSession`) plutôt que
/// l'overlay du bottom sheet (recréé à chaque ouverture), n'envoie que les
/// commandes Start/Stop et reflète en [status] l'état renvoyé par la page —
/// y compris quand le changement vient d'un toucher ou du minuteur, pas du
/// natif. Quitter l'écran détruit la WebView, donc la boucle ; [dispose]
/// envoie quand même un Stop explicite. Voir
/// `docs/features/camera-showcase-carousel.md`.
class CameraCarouselSession implements FeatureSession {
  CameraCarouselSession(this._controller) {
    _subscription = _controller.messages.listen((message) {
      if (message.type == 'carouselState') onStateMessage(message.data);
    });
  }

  /// Arrêts de la visite sur la carte de démo partagée (3 bâtiments,
  /// 4 étages), visités dans cet ordre, en boucle.
  static const List<String> kStops = DemoMap.carouselStopIds;

  final VisioOneController _controller;
  late final StreamSubscription<VisioOneMessage> _subscription;
  bool _disposed = false;

  /// Dernier état connu de la visite. Mis à jour uniquement par
  /// [onStateMessage] (miroir de la page, jamais deviné côté natif).
  final ValueNotifier<CameraCarouselStatus> status = ValueNotifier<CameraCarouselStatus>(CameraCarouselStatus.stopped);

  Future<void> start() => _controller.startCarousel(kStops);

  Future<void> stop() => _controller.stopCarousel();

  /// Appelé à chaque message `carouselState`.
  void onStateMessage(Object? data) {
    if (_disposed) return;
    final parsed = CameraCarouselStatus.fromMessageData(data);
    if (parsed != null) status.value = parsed;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _subscription.cancel();
    if (status.value.state != CameraCarouselState.stopped) {
      _controller.stopCarousel();
    }
    status.dispose();
  }
}
