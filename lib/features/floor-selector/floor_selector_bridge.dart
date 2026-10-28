import '../../visio_one/visio_one_controller.dart';

/// Commandes Native -> JS de `floor-selector`, implémentées côté JS par
/// `assets/www/features/floor-selector.js` (qui relaie aussi l'événement SDK
/// `currentfloorchanged` en message `floorChanged`). Voir
/// `docs/features/floor-selector.md`.
extension FloorSelectorBridge on VisioOneController {
  /// Change de bâtiment, et éventuellement d'étage au sein de ce bâtiment
  /// (`view.goToFloor(floor)`, ou `view.goToBuilding(building)` sans
  /// [floorId]).
  Future<void> goToFloor({required String buildingId, String? floorId}) =>
      send('goToFloor', [buildingId, floorId]);

  /// Demande la liste des bâtiments/étages de la venue courante. La réponse
  /// arrive sur [VisioOneController.messages] en message `venueLayout`
  /// (`{currentBuildingId, currentFloorId, buildings}`), sans `requestId` :
  /// il n'y a qu'une venue, et `floorChanged` met ensuite la sélection à jour.
  Future<void> getVenueLayout() => send('getVenueLayout');
}
