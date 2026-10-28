// geofencing : polygone d'une zone (première surface d'un POI) et alerte
// visuelle d'entrée/sortie (`venue.updateSurface`). Le test
// point-dans-polygone est fait côté Dart (le SDK n'expose aucune primitive
// de geofencing). Voir docs/features/geofencing.md.
(function (core) {
  core.register({
    // Résout le polygone WGS84 de la première surface d'un POI ("zone" pour
    // cette démo). Contrairement à `resolvePoiPosition` (position
    // ponctuelle), on lit ici `surface.positions` (`Position[]`, même forme
    // `{latitude, longitude}` que celle attendue par injectTrackedPosition,
    // aucune conversion nécessaire). Réponse `poiZoneResolved` avec
    // `positions: null` si `poiId` ne correspond à aucun POI,
    // `positions: []` si le POI existe mais n'a aucune surface — deux
    // états distincts, laissés au natif d'afficher chacun son propre
    // message.
    resolvePoiZone: function (requestId, poiId) {
      var poi = core.findPoi(poiId);
      if (!poi) {
        core.sendToNative('poiZoneResolved', { requestId: requestId, poiId: poiId, positions: null });
        return;
      }
      var surface = poi.surfaces[0];
      var positions = surface
        ? surface.positions.map(function (pos) {
            return { latitude: pos.latitude, longitude: pos.longitude };
          })
        : [];
      core.sendToNative('poiZoneResolved', { requestId: requestId, poiId: poiId, positions: positions });
    },

    // Colore (ou réinitialise, `active: false`) la/les surface(s) du POI
    // zone — même idiome que `updateOccupancy` (`venue.updateSurface(surface,
    // { color })`), `'initial'` et non `undefined` pour restaurer la couleur
    // du bundle de carte (voir la même remarque sur setSurfaceInteractive).
    setZoneAlert: function (placeId, active) {
      var venue = core.venue;
      var poi = core.findPoi(placeId);
      if (!poi) return;
      poi.surfaces.forEach(function (surface) {
        venue.updateSurface(surface, { color: active ? '#E74C3C' : 'initial' });
      });
    },
  });
})(window.MapCore);
