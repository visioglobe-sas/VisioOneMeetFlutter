// clickable-surface : rend la/les surface(s) d'un POI cliquables
// (`venue.updateSurface(surface, { isInteractive, ... })`). Voir
// docs/features/clickable-surface.md.
(function (core) {
  core.register({
    // Le SDK gère lui-même le survol/tap (hoverColor/selectionColor) sans
    // qu'aucun listener ne soit nécessaire côté app pour ce changement de
    // couleur — c'est `isInteractive: true` qui active ce comportement.
    // `color` est la couleur "au repos" ; on la remet à `'initial'` (pas
    // `undefined`, voir docs/features/clickable-surface.md) en désactivant,
    // pour ne pas laisser la surface bloquée sur une couleur custom
    // précédente.
    setSurfaceInteractive: function (placeId, interactive) {
      var venue = core.venue;
      var poi = core.findPoi(placeId);
      if (!poi) return;
      poi.surfaces.forEach(function (surface) {
        venue.updateSurface(
          surface,
          interactive
            ? { isInteractive: true, color: '#2ECC71', hoverColor: '#F1C40F', selectionColor: '#E74C3C' }
            : { isInteractive: false, color: 'initial' },
        );
      });
    },
  });
})(window.MapCore);
