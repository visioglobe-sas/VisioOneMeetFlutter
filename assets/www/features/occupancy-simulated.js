// occupancy-simulated : colore la/les surface(s) d'un ou plusieurs POI selon
// un statut d'occupation (`venue.updateSurface(surface, { color })`). Le
// minuteur qui fait tourner les couleurs vit côté Dart. Voir
// docs/features/occupancy-simulated.md.
(function (core) {
  core.register({
    // `occupancy` : [{ planId, color }] ; `color: null` réinitialise la
    // surface.
    updateOccupancy: function (occupancy) {
      var venue = core.venue;
      if (!venue) return;
      occupancy.forEach(function (entry) {
        var poi = core.findPoi(entry.planId);
        if (!poi) return;
        poi.surfaces.forEach(function (surface) {
          venue.updateSurface(surface, { color: entry.color });
        });
      });
    },
  });
})(window.MapCore);
