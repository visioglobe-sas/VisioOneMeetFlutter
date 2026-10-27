// 3d-icon-marker : place une image (icône) sur un POI existant
// (`venue.createImage`), change son orientation (`venue.updateImage`) et la
// retire (`venue.removeImage`). Voir docs/features/3d-icon-marker.md.
(function (core) {
  // Images créées par cette démo, indexées par un id choisi côté natif :
  // `venue.updateImage` / `venue.removeImage` prennent l'objet `Image`
  // lui-même, qui ne peut pas traverser le pont. Vidé à chaque rechargement
  // de carte.
  var iconImages = {};

  core.onReset(function () {
    iconImages = {};
  });
  core.registerCreatedObjects(function () {
    return Object.keys(iconImages).map(function (id) { return iconImages[id]; });
  });

  core.register({
    // `3d-icon-marker` : place une image (icône) au-dessus d'un POI
    // existant (`venue.createImage`), dont il est à la fois le
    // propriétaire (`poi`) et la source de position (via resolveAnchor). Une seule image par `imageId` :
    // si une image est déjà placée sous cet id, elle est d'abord retirée.
    // Requête/réponse (même schéma que createDynamicPOI) avec `error` =
    // 'notFound' / 'noPosition' / 'sdk' (message du SDK) en cas d'échec.
    // Voir docs/features/3d-icon-marker.md.
    placeIconImage: function (requestId, imageId, anchorId, url, orientationType) {
      var venue = core.venue;
      if (!venue) {
        core.sendToNative('iconImagePlaced', { requestId: requestId, success: false, error: 'notReady' });
        return;
      }
      var anchor = core.resolveAnchor(anchorId);
      if (anchor.error) {
        core.sendToNative('iconImagePlaced', { requestId: requestId, success: false, error: anchor.error });
        return;
      }
      // `previousRemoved` signale au natif qu'une image précédente a déjà
      // été retirée avant un éventuel échec de createImage (ex. url
      // vide) : l'état devient alors "aucune icône placée".
      var previousRemoved = false;
      try {
        if (iconImages[imageId]) {
          venue.removeImage(iconImages[imageId]);
          delete iconImages[imageId];
          previousRemoved = true;
        }
        iconImages[imageId] = venue.createImage({
          poi: anchor.poi,
          position: anchor.position,
          width: 6,
          height: 6,
          url: url,
          orientationType: orientationType,
        });
      } catch (error) {
        core.sendToNative('iconImagePlaced', {
          requestId: requestId,
          success: false,
          error: 'sdk',
          message: core.errorMessage(error),
          previousRemoved: previousRemoved,
        });
        return;
      }
      core.sendToNative('iconImagePlaced', { requestId: requestId, success: true, imageId: imageId, poiId: anchorId });
    },

    // `venue.updateImage(image, { orientationType })` sur une image déjà
    // placée par placeIconImage — prend effet immédiatement, sans
    // recréer l'image. Voir docs/features/3d-icon-marker.md.
    updateIconImageOrientation: function (requestId, imageId, orientationType) {
      var venue = core.venue;
      var image = iconImages[imageId];
      if (!image) {
        core.sendToNative('iconImageUpdated', { requestId: requestId, success: false, error: 'noImage' });
        return;
      }
      try {
        venue.updateImage(image, { orientationType: orientationType });
      } catch (error) {
        core.sendToNative('iconImageUpdated', {
          requestId: requestId,
          success: false,
          error: 'sdk',
          message: core.errorMessage(error),
        });
        return;
      }
      core.sendToNative('iconImageUpdated', { requestId: requestId, success: true, orientationType: image.orientationType });
    },

    // `venue.removeImage(image)` : retire l'image de la carte et de
    // `poi.images` du POI ancre. Voir docs/features/3d-icon-marker.md.
    removeIconImage: function (requestId, imageId) {
      var venue = core.venue;
      var image = iconImages[imageId];
      if (!image) {
        core.sendToNative('iconImageRemoved', { requestId: requestId, success: false, error: 'noImage' });
        return;
      }
      try {
        venue.removeImage(image);
      } catch (error) {
        core.sendToNative('iconImageRemoved', {
          requestId: requestId,
          success: false,
          error: 'sdk',
          message: core.errorMessage(error),
        });
        return;
      }
      delete iconImages[imageId];
      core.sendToNative('iconImageRemoved', { requestId: requestId, success: true });
    },
  });
})(window.MapCore);
