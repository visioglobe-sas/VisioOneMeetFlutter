// add-locale : ajoute une locale à l'exécution (`venue.translator.addLocale`)
// et relit ses traductions (`venue.translator.translate`). Voir
// docs/features/add-locale.md.
(function (core) {
  core.register({
    // `add-locale` : ajoute une locale `'es'` jamais authorée dans
    // VisioMapEditor pour cette carte (`venue.translator.addLocale`,
    // synchrone, void) puis relit chaque clé de `resources` via
    // `venue.translator.translate(key, 'es')` (également synchrone) dans
    // le même aller-retour de pont, comme `loadCustomData` (features/custom-data.js)
    // enchaîne `refreshCustomData`/`getPOICustomData`. `addLocale` est
    // backé par un bundle i18next générique, complètement séparé des
    // données de traduction propres à la venue (POI/étage/bâtiment,
    // elles, sont parsées une fois au chargement depuis le JSON de la
    // carte publiée) : il ne peut jamais changer le nom d'un POI/label
    // sur la carte, seulement les clés d'UI/nav prédéfinies du SDK et les
    // clés applicatives arbitraires. Voir docs/features/add-locale.md.
    addSpanishLocale: function (requestId, resources) {
      var venue = core.venue;
      if (!venue) {
        core.sendToNative('spanishLocaleAdded', { requestId: requestId, values: {} });
        return;
      }
      venue.translator.addLocale('es', resources);
      var values = {};
      Object.keys(resources).forEach(function (key) {
        values[key] = venue.translator.translate(key, 'es');
      });
      core.sendToNative('spanishLocaleAdded', { requestId: requestId, values: values });
    },
  });
})(window.MapCore);
