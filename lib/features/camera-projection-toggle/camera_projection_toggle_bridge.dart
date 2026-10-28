import '../../visio_one/visio_one_controller.dart';

/// Commandes Native -> JS de `camera-projection-toggle`, implémentées côté JS
/// par `assets/www/features/camera-projection-toggle.js`. Voir
/// `docs/features/camera-projection-toggle.md`.
extension CameraProjectionToggleBridge on VisioOneController {
  /// Recrée la carte avec `createView(..., { cameraProjection: projection })`
  /// (`'perspective'` ou `'orthographic'`) : `cameraProjection` n'est qu'une
  /// option de création de vue, le JS rejoue donc tout `setup` avec les mêmes
  /// hash/baseURL/options. Réponse : `loading`, puis `ready`
  /// (`{cameraProjection}`) ou `error`.
  Future<void> setCameraProjection(String projection) => send('setCameraProjection', [projection]);
}
