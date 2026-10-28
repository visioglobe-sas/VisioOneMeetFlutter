// goto-poi : centre la caméra sur un POI (`view.goToFloor` puis
// `view.goToPOI`) et efface la sélection visuelle. `goToPOI` est aussi
// appelée par `3d-icon-marker`, `custom-text-label` et `html-overlay-marker`
// pour afficher l'étage de l'objet placé. Voir docs/features/goto-poi.md.
(function (core) {
  core.register({
    goToPOI: function (poiId) {
      var venue = core.venue;
      var view = core.view;
      if (!venue || !view) return;
      var poi = core.findPoi(poiId);
      if (!poi) return;
      view.goToFloor(poi.floor).then(function () {
        view.goToPOI(poi);
      });
    },

    clearSelection: function () {
      var venue = core.venue;
      if (!venue) return;
      venue.pois.forEach(function (poi) {
        poi.surfaces.forEach(function (surface) {
          venue.updateSurface(surface, { selectionColor: undefined });
        });
      });
    },
  });
})(window.MapCore);
