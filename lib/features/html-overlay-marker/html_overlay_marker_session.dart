import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../visio_one/feature_session.dart';
import '../../visio_one/visio_one_controller.dart';
import '../../visio_one/visio_one_message.dart';

/// État de `html-overlay-marker`, porté par l'écran pour survivre à la
/// fermeture du bottom sheet : le badge est tappé panneau fermé (le panneau
/// est modal), donc le compteur doit suivre `htmlBadgeTapped` sans overlay
/// monté. Voir `docs/features/html-overlay-marker.md`.
class HtmlOverlayMarkerSession implements FeatureSession {
  HtmlOverlayMarkerSession(VisioOneController controller) {
    _subscription = controller.messages.listen((message) {
      if (message.type != 'htmlBadgeTapped') return;
      final data = message.data;
      final count = data is Map ? data['count'] : null;
      if (count is int) tapCount.value = count;
    });
  }

  late final StreamSubscription<VisioOneMessage> _subscription;

  /// Id du POI ancre du badge, ou `null` si aucun badge n'est placé.
  final ValueNotifier<String?> anchorId = ValueNotifier<String?>(null);

  /// Visibilité du badge placé (`venue.updateMarker(marker, { isVisible })`).
  final ValueNotifier<bool> visible = ValueNotifier<bool>(true);

  /// Nombre de taps sur le badge placé (message `htmlBadgeTapped` `{count}`),
  /// remis à 0 à chaque placement réussi.
  final ValueNotifier<int> tapCount = ValueNotifier<int>(0);

  @override
  void dispose() {
    _subscription.cancel();
    anchorId.dispose();
    visible.dispose();
    tapCount.dispose();
  }
}
