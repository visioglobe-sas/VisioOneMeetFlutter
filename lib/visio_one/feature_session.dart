/// État d'une feature qui doit vivre aussi longtemps que son écran, et pas
/// seulement le temps d'une ouverture du panneau : une boucle ou un minuteur
/// (position simulée, occupation, visite caméra) ou le miroir d'un état
/// renvoyé par le SDK même panneau fermé (projection caméra, taps sur un
/// badge HTML).
///
/// Créée par `FeatureSpec.createSession` (voir `lib/features/feature.dart`)
/// juste après le `VisioOneController` de l'écran, attachée à celui-ci
/// (`VisioOneController.attachSession`), et libérée avec lui en quittant
/// l'écran. Une session écoute elle-même `controller.messages` si besoin.
/// Les simples valeurs de formulaire, elles, vivent dans
/// `VisioOneController.panel` ([PanelState]).
abstract class FeatureSession {
  /// Arrête boucles/minuteurs et libère les notifiers. Appelée par
  /// `VisioOneController.dispose()`.
  void dispose();
}
