// poi-click : relaie l'événement SDK `poiclick` de la vue au natif
// (message `poiSelected` `{id, name}`). Voir docs/features/poi-click.md.
(function (core) {
  core.onViewCreated(function (view) {
    view.addEventListener('poiclick', function (event) {
      var poi = event.pois && event.pois[0];
      if (!poi) return;
      core.sendToNative('poiSelected', {
        id: poi.id,
        name: poi.labels && poi.labels[0] ? poi.labels[0].text : null,
      });
    });
  });
})(window.MapCore);
