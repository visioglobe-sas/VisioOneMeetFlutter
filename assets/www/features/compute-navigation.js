// compute-navigation : calcule un itinéraire entre deux POI
// (`venue.computeNavigation`) et l'affiche (`venue.createNavigationTrace` +
// `view.setCurrentNavigationTrace`). Aussi utilisé par `accessible-mode`
// (`isAccessible: true`) et `custom-navigation-trace`. Voir
// docs/features/compute-navigation.md.
(function (core) {
  core.register({
    // Réponse : message `itineraryComputed` ({ instructions }). Pas de
    // try/catch : un couple origine/destination qu'aucune route ne relie ne
    // crée aucune trace et ne renvoie aucun message d'erreur explicite.
    startItinerary: function (args) {
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
      });
      var trace = venue.createNavigationTrace(navigation);
      view.setCurrentNavigationTrace(trace);
      // Retenue pour `custom-navigation-trace` (restylage après coup).
      core.currentNavigationTrace = trace;
      core.sendToNative('itineraryComputed', { instructions: navigation.instructions });
    },
  });
})(window.MapCore);
