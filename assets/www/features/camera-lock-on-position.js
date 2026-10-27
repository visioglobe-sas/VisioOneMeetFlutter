// camera-lock-on-position : verrouille/déverrouille la caméra sur la position
// trackée (`view.lockCameraPositionOnTracking`) et relaie sa valeur au natif
// (message `cameraLockChanged`). Voir docs/features/camera-lock-on-position.md.
(function (core) {
  // Le SDK modifie lui-même `lockCameraPositionOnTracking` —
  // `allowTracking = true` le force à `true` (event `trackingon`),
  // `allowTracking = false` à `false` (`trackingoff`), et un pan/une
  // manipulation de la carte pendant le tracking le repasse à `false`
  // (`trackingchanged`, émis aussi par le setter). Aucun de ces events ne
  // porte la valeur : on relit la propriété et on la relaie au natif, qui en
  // fait la seule source de vérité de l'interrupteur (pas d'état parallèle
  // côté app).
  core.onViewCreated(function (view) {
    function forwardCameraLock() {
      core.sendToNative('cameraLockChanged', { locked: !!view.lockCameraPositionOnTracking });
    }
    view.addEventListener('trackingon', forwardCameraLock);
    view.addEventListener('trackingoff', forwardCameraLock);
    view.addEventListener('trackingchanged', forwardCameraLock);
  });

  core.register({
    // D'après sa doc dans les typings du SDK, ce booléen "won't have any
    // effect if flag 'allowTracking' isn't set to true" : contrairement à
    // `injectTrackedPosition`, aucune exception n'est levée si on l'active
    // avant — pas besoin de garde ici. L'interrupteur natif ne change pas sa
    // valeur lui-même : il suit l'event `trackingchanged` que ce setter
    // déclenche. Ne gère pas `lockCameraOrientationOnTracking` (verrouillage
    // de l'orientation, nécessite les données du capteur d'orientation de
    // l'appareil) : hors scope.
    setCameraLockOnPosition: function (locked) {
      var view = core.view;
      if (!view) return;
      view.lockCameraPositionOnTracking = !!locked;
    },
  });
})(window.MapCore);
