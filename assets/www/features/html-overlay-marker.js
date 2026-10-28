// html-overlay-marker : épingle un élément HTML (un badge) sur la carte
// (`venue.createMarker({ poi, position, element })`), le modifie, le
// masque (`venue.updateMarker`) et le retire (`venue.removeMarker`) ; un tap
// sur le badge remonte au natif (message `htmlBadgeTapped`). Voir
// docs/features/html-overlay-marker.md.
(function (core) {
  // Badge créé par cette démo et son compteur de taps (remis à 0 à chaque
  // placement réussi). Le `Marker` du SDK (et son élément DOM) ne peuvent
  // pas traverser le pont : ils restent ici. Une seule instance à la fois.
  // Vidé à chaque rechargement de carte.
  var htmlBadge = null;
  var htmlBadgeTapCount = 0;

  var HTML_BADGE_STYLE =
    'background:#0B6BCB;color:#FFFFFF;font:600 14px sans-serif;padding:6px 12px;' +
    'border-radius:14px;white-space:nowrap;box-shadow:0 2px 6px rgba(0,0,0,.3);cursor:pointer';

  core.onReset(function () {
    htmlBadge = null;
    htmlBadgeTapCount = 0;
  });
  core.registerCreatedObjects(function () { return [htmlBadge]; });

  core.register({
    // `html-overlay-marker` : épingle un élément HTML (un badge) sur la
    // carte via `venue.createMarker({ poi, position, element })`. Le SDK
    // déplace l'élément dans son propre conteneur d'overlay, au-dessus
    // de la scène 3D (jamais masqué par la géométrie), et en possède la
    // mise en page (position/translate/transform/z-index) : on ne stylise
    // donc ni `transform` ni `position` dessus. Validation AVANT de toucher
    // au badge existant (texte non vide, POI ancre, position issue des
    // données de la carte — jamais de notre propre badge, encore dans
    // `poi.markers`) ; position décalée de ~4 m comme custom-text-label.
    // Le SDK force `pointer-events: none` à la création : on le remet à
    // `auto` juste après, et le `click` est stoppé (stopPropagation) pour
    // ne pas retomber sur la carte (fiche du POI dessous), puis relayé au
    // natif (`htmlBadgeTapped`, `count`). Requête/réponse `htmlBadgePlaced`
    // avec `error` = 'textRequired' / 'notFound' / 'noPosition' / 'sdk',
    // plus `previousRemoved`. Voir docs/features/html-overlay-marker.md.
    placeHtmlBadge: function (requestId, anchorId, text) {
      var venue = core.venue;
      if (!venue) {
        core.sendToNative('htmlBadgePlaced', { requestId: requestId, success: false, error: 'notReady' });
        return;
      }
      if (!text || !String(text).trim()) {
        core.sendToNative('htmlBadgePlaced', { requestId: requestId, success: false, error: 'textRequired' });
        return;
      }
      var anchor = core.resolveAnchor(anchorId);
      if (anchor.error) {
        core.sendToNative('htmlBadgePlaced', { requestId: requestId, success: false, error: anchor.error });
        return;
      }
      var position = core.offsetPosition(anchor.position);

      var element = document.createElement('div');
      element.setAttribute('style', HTML_BADGE_STYLE);
      element.textContent = text;

      var previousRemoved = false;
      try {
        if (htmlBadge) {
          var previous = htmlBadge;
          htmlBadge = null;
          previousRemoved = true;
          venue.removeMarker(previous);
        }
        var marker = venue.createMarker({ poi: anchor.poi, position: position, element: element });
        // Le SDK pose `pointer-events: none` à la création (et ne le
        // réécrit plus ensuite) : sans ça, le badge n'est pas tappable.
        element.style.pointerEvents = 'auto';
        element.addEventListener('click', function (event) {
          event.stopPropagation();
          if (htmlBadge !== marker) return;
          htmlBadgeTapCount += 1;
          core.sendToNative('htmlBadgeTapped', { count: htmlBadgeTapCount });
        });
        htmlBadge = marker;
        htmlBadgeTapCount = 0;
      } catch (error) {
        core.sendToNative('htmlBadgePlaced', {
          requestId: requestId,
          success: false,
          error: 'sdk',
          message: core.errorMessage(error),
          previousRemoved: previousRemoved,
        });
        return;
      }
      core.sendToNative('htmlBadgePlaced', { requestId: requestId, success: true, poiId: anchorId });
    },

    // Change le texte du badge : simple édition DOM de `marker.element`
    // (nœud vivant), aucun appel SDK. Réponse `htmlBadgeUpdated`,
    // `error` = 'noBadge' / 'textRequired'.
    updateHtmlBadgeText: function (requestId, text) {
      if (!htmlBadge) {
        core.sendToNative('htmlBadgeUpdated', { requestId: requestId, success: false, error: 'noBadge' });
        return;
      }
      if (!text || !String(text).trim()) {
        core.sendToNative('htmlBadgeUpdated', { requestId: requestId, success: false, error: 'textRequired' });
        return;
      }
      htmlBadge.element.textContent = text;
      core.sendToNative('htmlBadgeUpdated', { requestId: requestId, success: true });
    },

    // `venue.updateMarker(marker, { isVisible })` : `false` passe
    // l'élément en `display: none` (il reste dans le DOM). Réponse
    // `htmlBadgeUpdated`, `error` = 'noBadge' / 'sdk'.
    setHtmlBadgeVisible: function (requestId, visible) {
      var venue = core.venue;
      if (!htmlBadge) {
        core.sendToNative('htmlBadgeUpdated', { requestId: requestId, success: false, error: 'noBadge' });
        return;
      }
      try {
        venue.updateMarker(htmlBadge, { isVisible: visible });
      } catch (error) {
        core.sendToNative('htmlBadgeUpdated', {
          requestId: requestId,
          success: false,
          error: 'sdk',
          message: core.errorMessage(error),
        });
        return;
      }
      core.sendToNative('htmlBadgeUpdated', { requestId: requestId, success: true, visible: visible });
    },

    // `venue.removeMarker(marker)` (le SDK détache aussi l'élément du
    // DOM) puis on oublie la référence : un second appel est un no-op
    // côté app (`error: 'noBadge'`) — le SDK, lui, lèverait
    // `Provided marker is not registered`.
    removeHtmlBadge: function (requestId) {
      var venue = core.venue;
      if (!htmlBadge) {
        core.sendToNative('htmlBadgeRemoved', { requestId: requestId, success: false, error: 'noBadge' });
        return;
      }
      var marker = htmlBadge;
      htmlBadge = null;
      try {
        venue.removeMarker(marker);
      } catch (error) {
        core.sendToNative('htmlBadgeRemoved', {
          requestId: requestId,
          success: false,
          error: 'sdk',
          message: core.errorMessage(error),
        });
        return;
      }
      core.sendToNative('htmlBadgeRemoved', { requestId: requestId, success: true });
    },
  });
})(window.MapCore);
