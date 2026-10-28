// runtime-locale : lit la locale courante et les locales disponibles de la
// venue, et change de locale à la volée (`venue.setCurrentLocale`). Aussi
// utilisé par `add-locale`. Voir docs/features/runtime-locale.md.
(function (core) {
  core.register({
    // Requête/réponse (même schéma que getVenueLayout / venueLayout) :
    // renvoie la locale courante (`venue.currentLocale`) et la liste des
    // locales disponibles pour cette venue (`venue.translator.allLocales`).
    // Sur la carte de démo partagée, `allLocales` vaut
    // `['default', 'en', 'fr']` où `'default'` s'avère être un doublon
    // (octet pour octet identique, confirmé en direct) du français —
    // c'est le natif qui ne présente que `'en'`/`'fr'` à l'utilisateur,
    // pas ce pont. Voir docs/features/runtime-locale.md.
    getLocales: function (requestId) {
      var venue = core.venue;
      if (!venue) {
        core.sendToNative('localesLoaded', { requestId: requestId, currentLocale: null, allLocales: [] });
        return;
      }
      core.sendToNative('localesLoaded', {
        requestId: requestId,
        currentLocale: venue.currentLocale,
        allLocales: venue.translator.allLocales,
      });
    },

    // Change la locale courante de la venue (`venue.setCurrentLocale`,
    // `Promise<void>`). D'après sa TSDoc (typings du SDK), le SDK se charge
    // lui-même de re-rendre les labels de POI (via leur `POILocaleEntry`
    // pour cette locale) et toute UI courante (dont la Navigation en
    // cours) dans la nouvelle locale dès que la Promise se résout —
    // aucun re-fetch manuel de données POI n'est nécessaire côté natif,
    // ni aucun message de confirmation dédié : le résultat est
    // directement observable sur la carte. Voir
    // docs/features/runtime-locale.md.
    setCurrentLocale: function (locale) {
      var venue = core.venue;
      if (!venue) return;
      venue.setCurrentLocale(locale).catch(function (error) {
        console.error('[MapBridge] setCurrentLocale a échoué:', error);
      });
    },
  });
})(window.MapCore);
