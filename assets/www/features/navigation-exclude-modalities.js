// navigation-exclude-modalities : même calcul que `startItinerary`
// (features/compute-navigation.js), avec `excludedAttributes` en plus -- une
// "particularité" de segment (ex. ascenseur) à exclure du graphe de routage.
// Le JSDoc du SDK donne "elevator" comme exemple pour ce champ, mais la
// valeur réellement taguée sur les segments d'ascenseur de cette venue
// (confirmé en direct) est 'lift', pas 'elevator'. Voir
// docs/features/navigation-exclude-modalities.md.
(function (core) {
  core.register({
    // Pas de try/catch ici, volontairement : un couple origine/destination
    // qu'aucune route ne relie une fois l'exclusion appliquée doit échouer
    // exactement comme un couple non relié pour `startItinerary` (aucune
    // trace, aucun message d'erreur explicite renvoyé au natif — voir
    // docs/features/compute-navigation.md).
    startItineraryExcludingModalities: function (args) {
      var venue = core.venue;
      var view = core.view;
      if (!venue || !view) return;
      var navigation = venue.computeNavigation({
        origin: args.origin,
        destination: args.destination,
        isAccessible: !!args.isAccessible,
        type: 'fastest',
        firstNodeAsIntersection: false,
        mergeFloorChangeInstructions: false,
        excludedAttributes: args.excludedAttributes || [],
      });
      var trace = venue.createNavigationTrace(navigation);
      view.setCurrentNavigationTrace(trace);
      core.currentNavigationTrace = trace;
      core.sendToNative('itineraryComputed', { instructions: navigation.instructions });
    },
  });
})(window.MapCore);
