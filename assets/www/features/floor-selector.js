// floor-selector : liste des bâtiments/étages de la venue, changement
// d'étage, et relais de l'événement SDK `currentfloorchanged` (message
// `floorChanged`). Réutilisé par `native-ui-replacement`. Voir
// docs/features/floor-selector.md.
(function (core) {
  // L'événement (`VenueEvent` côté SDK) porte `newBuilding`/`newFloor`
  // (et `oldBuilding`/`oldFloor`), pas de champ `floor` : lire
  // `event.floor` renvoyait toujours null et désélectionnait l'étage
  // du floor-selector natif à chaque changement.
  core.onViewCreated(function (view) {
    view.addEventListener('currentfloorchanged', function (event) {
      core.sendToNative('floorChanged', {
        buildingId: event.newBuilding ? event.newBuilding.id : null,
        floorId: event.newFloor ? event.newFloor.id : null,
      });
    });
  });

  core.register({
    goToFloor: function (buildingId, floorId) {
      var venue = core.venue;
      var view = core.view;
      if (!venue || !view) return;
      var building = venue.venueLayout.buildings.find(function (b) { return b.id === buildingId; });
      if (!building) return;
      if (floorId) {
        var floor = building.floors.find(function (f) { return f.id === floorId; });
        if (floor) view.goToFloor(floor);
      } else {
        view.goToBuilding(building);
      }
    },

    // Requête/réponse (message `venueLayout`) : Building/Floor n'exposent
    // ni nom ni libellé côté SDK (voir Building.d.ts/Floor.d.ts du package
    // @visioglobe/visioone — seulement `id`, `floors`, `defaultFloorID` pour
    // Building, `id`, `altitude`, `levelIndex` pour Floor), exactement comme
    // le floor-selector intégré au SDK, qui affiche le `levelIndex`. On
    // renvoie donc `levelIndex`, à charge du natif de l'afficher (ex.
    // "Floor 2", "Floor -1"), triés du plus haut au plus bas comme un
    // panneau d'ascenseur. `currentBuildingId`/`currentFloorId` permettent
    // de présélectionner le bon bouton dès l'ouverture du panneau, sans
    // attendre un `floorChanged`.
    getVenueLayout: function () {
      var venue = core.venue;
      var view = core.view;
      if (!venue || !view) return;
      core.sendToNative('venueLayout', {
        currentBuildingId: view.currentBuilding ? view.currentBuilding.id : null,
        currentFloorId: view.currentFloor ? view.currentFloor.id : null,
        buildings: venue.venueLayout.buildings.map(function (building) {
          return {
            id: building.id,
            defaultFloorId: building.defaultFloorID,
            floors: building.floors
              .slice()
              .sort(function (a, b) { return b.levelIndex - a.levelIndex; })
              .map(function (floor) {
                return { id: floor.id, levelIndex: floor.levelIndex };
              }),
          };
        }),
      });
    },
  });
})(window.MapCore);
