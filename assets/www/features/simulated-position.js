// simulated-position : position WGS84 d'un POI, injection d'une position
// trackée simulée (`view.injectTrackedPosition`) et arrêt du tracking
// (`view.allowTracking = false`). La boucle de va-et-vient vit côté Dart.
// Aussi utilisé par `camera-lock-on-position`, `geofencing` et
// `accuracy-circle-style`. Voir docs/features/simulated-position.md.
(function (core) {
  core.register({
    // Requête/réponse (message `poiPositionResolved`) : position WGS84 d'un
    // POI selon `poiDisplayPosition` (label, puis image/marker, puis centre
    // de la surface), au format `{latitude, longitude}` attendu par
    // `injectTrackedPosition`, ou `null` si le POI est introuvable ou sans
    // élément visuel. `requestId` est renvoyé tel quel pour permettre
    // plusieurs requêtes concurrentes (origine + destination) sans les
    // confondre côté Dart.
    resolvePoiPosition: function (requestId, poiId) {
      var poi = core.findPoi(poiId);
      var found = poi ? core.poiDisplayPosition(poi) : null;
      var position = found ? { latitude: found.latitude, longitude: found.longitude } : null;
      core.sendToNative('poiPositionResolved', { requestId: requestId, poiId: poiId, position: position });
    },

    // Injecte/actualise une position simulée trackée + son cercle de
    // précision (mètres). `view.allowTracking` doit être à `true` avant
    // le premier appel à `injectTrackedPosition`, sans quoi le SDK lève
    // une exception : on l'active ici plutôt que
    // d'exposer une commande séparée, ce booléen n'ayant pas d'autre
    // usage dans cette démo — mais UNIQUEMENT à la transition
    // false -> true : chaque `allowTracking = true` force aussi
    // `lockCameraPositionOnTracking = true` côté SDK, le réaffecter à
    // chaque tick (~150 ms) reverrouillerait la caméra en permanence
    // (interrupteur "Camera lock" ou pan de la carte annulés aussitôt).
    injectTrackedPosition: function (latitude, longitude, precisionCircleRadius) {
      var view = core.view;
      if (!view) return;
      if (!view.allowTracking) view.allowTracking = true;
      view.injectTrackedPosition({
        position: { latitude: latitude, longitude: longitude },
        precisionCircleRadius: precisionCircleRadius,
      });
    },

    // Pas de méthode dédiée côté SDK pour "effacer" le marqueur/cercle
    // trackés : c'est `allowTracking = false` qui les retire de la carte
    // (voir docs/features/simulated-position.md, "Things to know").
    stopTrackedPosition: function () {
      var view = core.view;
      if (!view) return;
      view.allowTracking = false;
    },
  });
})(window.MapCore);
