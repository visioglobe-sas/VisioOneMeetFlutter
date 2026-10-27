import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../visio_one/feature_session.dart';
import '../../visio_one/visio_one_controller.dart';
import '../../visio_one/visio_one_message.dart';

/// État de `camera-projection-toggle` : projection caméra de la vue courante
/// telle que rapportée par le SDK (`view.cameraProjection`, en lecture
/// seule : `'perspective'` ou `'orthographic'`), ou `null` pendant un
/// (re)chargement de la carte. Session de l'écran (créée avant le premier
/// chargement), parce que le premier `ready` arrive avant toute ouverture du
/// panneau. Voir `docs/features/camera-projection-toggle.md`.
class CameraProjectionSession implements FeatureSession {
  CameraProjectionSession(VisioOneController controller) {
    _subscription = controller.messages.listen((message) {
      if (message.type == 'loading') projection.value = null;
      if (message.type == 'ready') {
        final data = message.data;
        final value = data is Map ? data['cameraProjection'] : null;
        projection.value = value is String ? value : null;
      }
    });
  }

  late final StreamSubscription<VisioOneMessage> _subscription;

  /// Mis à jour à chaque message `loading` (-> `null`) et `ready` (-> valeur
  /// du SDK).
  final ValueNotifier<String?> projection = ValueNotifier<String?>(null);

  @override
  void dispose() {
    _subscription.cancel();
    projection.dispose();
  }
}
