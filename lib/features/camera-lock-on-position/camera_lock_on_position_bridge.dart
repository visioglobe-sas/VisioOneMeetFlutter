import '../../visio_one/visio_one_controller.dart';

/// Commandes Native -> JS de `camera-lock-on-position`, implémentées côté JS
/// par `assets/www/features/camera-lock-on-position.js` (qui relaie aussi les
/// événements SDK `trackingon`/`trackingoff`/`trackingchanged` en message
/// `cameraLockChanged`). Voir `docs/features/camera-lock-on-position.md`.
extension CameraLockOnPositionBridge on VisioOneController {
  /// Verrouille/déverrouille la caméra sur la position trackée courante
  /// (`view.lockCameraPositionOnTracking`). Sans effet tant que
  /// `view.allowTracking` est à `false` (pas d'exception). La nouvelle valeur
  /// revient en message `cameraLockChanged`, reflété par
  /// `SimulatedPositionSession.isCameraLocked`.
  Future<void> setCameraLockOnPosition(bool locked) => send('setCameraLockOnPosition', [locked]);
}
