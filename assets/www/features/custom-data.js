// custom-data : (re)charge les CustomData métier (`venue.refreshCustomData()`)
// puis lit celles d'un POI (`venue.getPOICustomData(poi)`). Voir
// docs/features/custom-data.md.
(function (core) {
  core.register({
    // `getPOICustomData` est une lecture synchrone qui renvoie toujours un
    // objet — jamais null/undefined — vide `{}` si le POI n'a pas de
    // CustomData. `refreshCustomData()` rejette si aucune CustomData n'est
    // publiée pour cette carte (404 sur customData.json) : un état normal
    // pour une démo sans données publiées, pas une erreur à faire remonter
    // au natif — on l'avale ici (juste un warning console) et on continue,
    // `getPOICustomData` renverra `{}` de toute façon. Réponse
    // `customDataLoaded` ({ requestId, poiId, found, customData }).
    loadCustomData: function (requestId, poiId) {
      var venue = core.venue;
      if (!venue) {
        core.sendToNative('customDataLoaded', { requestId: requestId, poiId: poiId, found: false, customData: null });
        return;
      }
      venue
        .refreshCustomData()
        .catch(function (error) {
          console.warn(
            '[MapBridge] refreshCustomData a échoué (probablement aucune CustomData publiée pour cette carte) :',
            error,
          );
        })
        .then(function () {
          var poi = core.findPoi(poiId);
          if (!poi) {
            core.sendToNative('customDataLoaded', { requestId: requestId, poiId: poiId, found: false, customData: null });
            return;
          }
          core.sendToNative('customDataLoaded', {
            requestId: requestId,
            poiId: poiId,
            found: true,
            customData: venue.getPOICustomData(poi),
          });
        });
    },
  });
})(window.MapCore);
