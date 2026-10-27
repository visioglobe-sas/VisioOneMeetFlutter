import '../../visio_one/visio_one_controller.dart';

/// Commandes Native -> JS de `navigation-exclude-modalities`, implémentées
/// côté JS par `assets/www/features/navigation-exclude-modalities.js`. Voir
/// `docs/features/navigation-exclude-modalities.md`.
extension NavigationExcludeModalitiesBridge on VisioOneController {
  /// Même calcul que `startItinerary` (`compute-navigation`), en excluant
  /// les particularités de segment [excludedAttributes]
  /// (`venue.computeNavigation({..., excludedAttributes})`). Le JSDoc du SDK
  /// donne `"elevator"` en exemple, mais la valeur réellement taguée sur les
  /// segments d'ascenseur de la carte de démo est `'lift'`. Réponse en
  /// message `itineraryComputed`.
  Future<void> startItineraryExcludingModalities({
    required String origin,
    required String destination,
    bool isAccessible = false,
    List<String> excludedAttributes = const [],
  }) {
    return send('startItineraryExcludingModalities', [
      {
        'origin': origin,
        'destination': destination,
        'isAccessible': isAccessible,
        'excludedAttributes': excludedAttributes,
      },
    ]);
  }
}
