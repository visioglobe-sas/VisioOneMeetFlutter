import '../../visio_one/visio_one_controller.dart';

/// Commandes Native -> JS de `ui-part-visibility`, implémentées côté JS par
/// `assets/www/features/ui-part-visibility.js`. Aussi utilisées par
/// `native-ui-replacement`. Voir `docs/features/ui-part-visibility.md`.
extension UiPartVisibilityBridge on VisioOneController {
  /// Affiche/masque un élément de l'UI fournie par le SDK
  /// (`view.setUIPartVisible(part, visible)`) : `floorSelector`, `search`,
  /// `poiDetails`, `navigation` ou `userTracking`.
  Future<void> setUIPartVisible(String part, bool visible) => send('setUIPartVisible', [part, visible]);
}
