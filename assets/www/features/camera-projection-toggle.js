// camera-projection-toggle : `cameraProjection` est une option de
// `createView` uniquement (`view.cameraProjection` est en lecture seule,
// aucun changement à chaud) -- changer de projection rejoue donc `setup`
// (destroyView -> unloadVenue -> loadVenue -> createView, voir
// bridge/core.js) avec les mêmes hash/baseURL/options de vue, plus
// `cameraProjection`. Réponse : `loading` puis `ready` ({ cameraProjection })
// ou `error`. Voir docs/features/camera-projection-toggle.md.
(function (core) {
  core.register({
    setCameraProjection: function (projection) {
      var last = core.lastSetup;
      if (!last) return;
      var options = Object.assign({}, last.viewOptions || {}, { cameraProjection: projection });
      window.MapBridge.setup(last.hash, last.baseURL, options, last.authorizationToken);
    },
  });
})(window.MapCore);
