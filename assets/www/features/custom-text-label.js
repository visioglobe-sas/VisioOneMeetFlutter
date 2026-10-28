// custom-text-label : place un texte libre sur la carte (`venue.createLabel`),
// le modifie en direct (`venue.updateLabel`), le fait pivoter (retrait +
// recréation) et le retire (`venue.removeLabel`). Voir
// docs/features/custom-text-label.md.
(function (core) {
  // Label créé par cette démo et les options avec lesquelles il a été créé :
  // `rotation` n'existe que dans `LabelCreateOptions` (pas dans
  // `LabelUpdateOptions`), donc changer la rotation d'un label placé impose
  // de le retirer puis de le recréer avec les mêmes valeurs. Une seule
  // instance à la fois. Vidé à chaque rechargement de carte.
  var textLabel = null;
  var textLabelOptions = null;

  core.onReset(function () {
    textLabel = null;
    textLabelOptions = null;
  });
  core.registerCreatedObjects(function () { return [textLabel]; });

  core.register({
    // `custom-text-label` : place un texte libre sur la carte
    // (`venue.createLabel`), possédé par un POI existant dont la position
    // est copiée via resolveAnchor, décalée de ~4 m (offsetPosition) pour
    // ne pas recouvrir le label propre du POI. `height` est TOUJOURS passé
    // (sinon le SDK le cale sur `width` : boîte carrée, texte déformé).
    // Tout est validé AVANT de toucher au label existant (texte non vide,
    // POI ancre, position issue des données de la carte — jamais de notre
    // propre label, encore attaché à l'ancre) : un échec de validation
    // laisse le label déjà placé intact. Ce n'est qu'ensuite que l'ancien
    // label est retiré et le nouveau créé (un seul à la fois) ;
    // `previousRemoved` signale un échec du SDK après ce retrait.
    // Requête/réponse `textLabelPlaced` avec `error` = 'textRequired' /
    // 'notFound' / 'noPosition' / 'sdk' (message du SDK).
    // Voir docs/features/custom-text-label.md.
    placeTextLabel: function (requestId, anchorId, text, color, width, height, rotation) {
      var venue = core.venue;
      if (!venue) {
        core.sendToNative('textLabelPlaced', { requestId: requestId, success: false, error: 'notReady' });
        return;
      }
      if (!text || !String(text).trim()) {
        core.sendToNative('textLabelPlaced', { requestId: requestId, success: false, error: 'textRequired' });
        return;
      }
      var anchor = core.resolveAnchor(anchorId);
      if (anchor.error) {
        core.sendToNative('textLabelPlaced', { requestId: requestId, success: false, error: anchor.error });
        return;
      }
      var position = core.offsetPosition(anchor.position);
      var options = {
        poi: anchor.poi,
        position: position,
        width: width,
        height: height,
        text: text,
        color: color,
        rotation: rotation,
      };
      var previousRemoved = false;
      try {
        if (textLabel) {
          var previous = textLabel;
          textLabel = null;
          textLabelOptions = null;
          previousRemoved = true;
          venue.removeLabel(previous);
        }
        textLabel = venue.createLabel(options);
        textLabelOptions = options;
      } catch (error) {
        core.sendToNative('textLabelPlaced', {
          requestId: requestId,
          success: false,
          error: 'sdk',
          message: core.errorMessage(error),
          previousRemoved: previousRemoved,
        });
        return;
      }
      core.sendToNative('textLabelPlaced', { requestId: requestId, success: true, poiId: anchorId });
    },

    // `venue.updateLabel(label, changes)` sur le label placé, en direct.
    // `changes` = { text } | { color } | { width, height } — width et
    // height TOUJOURS ensemble (`width` seul remet `height = width`).
    // `rotation` n'est pas accepté ici (voir rotateTextLabel). Réponse
    // `textLabelUpdated`, `error` = 'noLabel' / 'textRequired' / 'sdk'.
    updateTextLabel: function (requestId, changes) {
      var venue = core.venue;
      if (!textLabel) {
        core.sendToNative('textLabelUpdated', { requestId: requestId, success: false, error: 'noLabel' });
        return;
      }
      if ('text' in changes && (!changes.text || !String(changes.text).trim())) {
        core.sendToNative('textLabelUpdated', { requestId: requestId, success: false, error: 'textRequired' });
        return;
      }
      try {
        venue.updateLabel(textLabel, changes);
      } catch (error) {
        core.sendToNative('textLabelUpdated', {
          requestId: requestId,
          success: false,
          error: 'sdk',
          message: core.errorMessage(error),
        });
        return;
      }
      Object.keys(changes).forEach(function (key) { textLabelOptions[key] = changes[key]; });
      core.sendToNative('textLabelUpdated', { requestId: requestId, success: true });
    },

    // Rotation d'un label placé : absente de `LabelUpdateOptions`, donc
    // removeLabel + createLabel avec les mêmes options (position, taille,
    // texte, couleur courants) et la nouvelle rotation. Réponse
    // `textLabelUpdated` ; en cas d'échec de la recréation, le label a
    // disparu (`previousRemoved`).
    rotateTextLabel: function (requestId, rotation) {
      var venue = core.venue;
      if (!textLabel) {
        core.sendToNative('textLabelUpdated', { requestId: requestId, success: false, error: 'noLabel' });
        return;
      }
      var options = Object.assign({}, textLabelOptions, { rotation: rotation });
      try {
        venue.removeLabel(textLabel);
        textLabel = null;
        textLabelOptions = null;
        textLabel = venue.createLabel(options);
        textLabelOptions = options;
      } catch (error) {
        core.sendToNative('textLabelUpdated', {
          requestId: requestId,
          success: false,
          error: 'sdk',
          message: core.errorMessage(error),
          previousRemoved: textLabel === null,
        });
        return;
      }
      core.sendToNative('textLabelUpdated', { requestId: requestId, success: true });
    },

    // `venue.removeLabel(label)` puis on oublie la référence : un second
    // appel est un no-op côté app (`error: 'noLabel'`) — le SDK, lui,
    // lèverait `Provided label is not registered`.
    removeTextLabel: function (requestId) {
      var venue = core.venue;
      if (!textLabel) {
        core.sendToNative('textLabelRemoved', { requestId: requestId, success: false, error: 'noLabel' });
        return;
      }
      try {
        venue.removeLabel(textLabel);
      } catch (error) {
        textLabel = null;
        textLabelOptions = null;
        core.sendToNative('textLabelRemoved', {
          requestId: requestId,
          success: false,
          error: 'sdk',
          message: core.errorMessage(error),
        });
        return;
      }
      textLabel = null;
      textLabelOptions = null;
      core.sendToNative('textLabelRemoved', { requestId: requestId, success: true });
    },
  });
})(window.MapCore);
