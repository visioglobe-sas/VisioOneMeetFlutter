// dynamic-poi-crud : crée un POI à la volée (`venue.createPOI`) rendu visible
// par un label (`venue.createLabel`), modifie ce label (`venue.updateLabel`)
// et supprime le POI (`venue.removePOI`). Voir docs/features/dynamic-poi-crud.md.
(function (core) {
  // Le POI (et son label) créés à la volée, actuellement suivis — un seul à
  // la fois (contrat de cette démo, pas une limite du SDK). Remis à `null`
  // à chaque rechargement de carte et par `removeDynamicPOI`.
  var dynamicPoi = null;
  var dynamicPoiLabel = null;

  core.onReset(function () {
    dynamicPoi = null;
    dynamicPoiLabel = null;
  });
  core.registerCreatedObjects(function () { return [dynamicPoiLabel]; });

  core.register({
    // Requête/réponse (même schéma que loadCustomData / customDataLoaded) :
    // crée un POI purement logique (`venue.createPOI({id: newId})`) — un
    // POI neuf n'a par lui-même aucune représentation visuelle
    // (`images`/`labels`/`lines`/`surfaces`/`markers` tous vides) — puis
    // lui attache immédiatement un Label (`venue.createLabel`) pour le
    // rendre visible, à la position d'un POI "ancre" déjà existant
    // ([anchorId], via resolveAnchor). `success: false` avec un code
    // `error` (traduit côté natif) dans ces cas, tous des états normaux
    // de la démo, pas des crashs : 'notReady', 'notFound' (ancre
    // introuvable), 'noPosition' (ancre sans élément visuel),
    // 'alreadyExists' (id déjà pris : `POIAlreadyExistsError`, levée de
    // façon synchrone par `createPOI`) ou 'sdk' (autre erreur, avec le
    // `message` du SDK). Voir docs/features/dynamic-poi-crud.md.
    createDynamicPOI: function (requestId, newId, anchorId, labelText) {
      var venue = core.venue;
      if (!venue) {
        core.sendToNative('dynamicPoiCreated', { requestId: requestId, success: false, error: 'notReady' });
        return;
      }

      var anchor = core.resolveAnchor(anchorId);
      if (anchor.error) {
        core.sendToNative('dynamicPoiCreated', { requestId: requestId, success: false, error: anchor.error });
        return;
      }

      var poi;
      var label;
      try {
        poi = venue.createPOI({ id: newId });
      } catch (error) {
        var alreadyExists = error && error.constructor && error.constructor.name === 'POIAlreadyExistsError';
        core.sendToNative('dynamicPoiCreated', {
          requestId: requestId,
          success: false,
          error: alreadyExists || core.findPoi(newId) ? 'alreadyExists' : 'sdk',
          message: core.errorMessage(error),
        });
        return;
      }
      try {
        label = venue.createLabel({
          poi: poi,
          position: anchor.position,
          width: 2,
          text: labelText,
        });
      } catch (error) {
        venue.removePOI(poi);
        core.sendToNative('dynamicPoiCreated', { requestId: requestId, success: false, error: 'sdk', message: core.errorMessage(error) });
        return;
      }

      dynamicPoi = poi;
      dynamicPoiLabel = label;
      core.sendToNative('dynamicPoiCreated', { requestId: requestId, success: true, poiId: newId, text: labelText });
    },

    // Seule "modification" possible du contenu visuel d'un POI dynamique
    // dans cette démo : `venue.updatePOI` ne peut toucher qu'aux
    // catégories du POI (voir `POIUpdateOptions`), jamais à sa
    // représentation visuelle — c'est `venue.updateLabel` sur le Label
    // attaché à la création qui joue ce rôle ici. Requête/réponse (même
    // schéma que createDynamicPOI ci-dessus). Voir
    // docs/features/dynamic-poi-crud.md.
    updateDynamicPoiLabelText: function (requestId, text) {
      var venue = core.venue;
      if (!dynamicPoiLabel) {
        core.sendToNative('dynamicPoiLabelUpdated', { requestId: requestId, success: false, error: 'noPoi' });
        return;
      }
      try {
        venue.updateLabel(dynamicPoiLabel, { text: text });
      } catch (error) {
        core.sendToNative('dynamicPoiLabelUpdated', { requestId: requestId, success: false, error: 'sdk', message: core.errorMessage(error) });
        return;
      }
      core.sendToNative('dynamicPoiLabelUpdated', { requestId: requestId, success: true, text: text });
    },

    // `venue.removePOI` retire le POI ET cascade sur tout élément visuel
    // attaché (ici, le Label créé par createDynamicPOI) : pas besoin d'un
    // removeLabel séparé. Requête/réponse (même schéma que
    // createDynamicPOI ci-dessus). Voir docs/features/dynamic-poi-crud.md.
    removeDynamicPOI: function (requestId) {
      var venue = core.venue;
      if (!dynamicPoi) {
        core.sendToNative('dynamicPoiRemoved', { requestId: requestId, success: false, error: 'noPoi' });
        return;
      }
      var removed = dynamicPoi;
      dynamicPoi = null;
      dynamicPoiLabel = null;
      try {
        venue.removePOI(removed);
      } catch (error) {
        core.sendToNative('dynamicPoiRemoved', { requestId: requestId, success: false, error: 'sdk', message: core.errorMessage(error) });
        return;
      }
      core.sendToNative('dynamicPoiRemoved', { requestId: requestId, success: true });
    },
  });
})(window.MapCore);
