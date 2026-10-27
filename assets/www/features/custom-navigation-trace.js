// custom-navigation-trace : restyle la trace actuellement affichée (créée par
// `startItinerary`, features/compute-navigation.js) via
// `venue.updateNavigationTrace(trace, options)`. Voir
// docs/features/custom-navigation-trace.md.
(function (core) {
  core.register({
    // `options` ne porte que des couleurs (`progressColor`,
    // `progressOutlineColor`, `progressFutureColor`, `previewColor`,
    // `previewOutlineColor`, plus `textureRepeat`/`animationSpeed`, sans
    // effet ici -- voir `NavigationTraceUpdateOptions.d.ts` du package
    // @visioglobe/visioone) : aucun moyen de changer `displayMode` ou
    // l'épaisseur après création. No-op si aucune trace n'existe encore.
    //
    // `venue.updateNavigationTrace()` peut lever une exception interne
    // ("undefined is not an object (evaluating 'o.children[0].material')"
    // sous JavaScriptCore/WKWebView -- même bug que le `TypeError:
    // Cannot read properties of undefined (reading 'material')` de V8
    // côté Vue, tout au fond du pipeline de rendu de ligne du SDK) --
    // confirmé en direct sur ce dépôt (test d'intégration), mais
    // seulement au tout premier appel d'une session, pas à chaque appel
    // (voir docs/features/custom-navigation-trace.md pour le détail) --,
    // alors que chaque couleur de `options` est malgré tout bien
    // appliquée avant que l'exception ne soit levée. On l'avale ici
    // (simple warning console) plutôt que de la laisser remonter comme un
    // `error` non intercepté à `window.onerror` : ce n'est pas un échec,
    // juste un défaut du SDK sur cette trajectoire de code.
    updateNavigationTrace: function (options) {
      var venue = core.venue;
      var trace = core.currentNavigationTrace;
      if (!venue || !trace) return;
      try {
        venue.updateNavigationTrace(trace, options);
      } catch (error) {
        // Un seul argument texte, pas l'objet `error` séparément : les
        // moteurs JS (et le relais console -> `debugPrint`, voir
        // VisioOneController._initialize) sérialisent souvent un `Error`
        // passé tel quel en argument séparé comme `{}` (JSON.stringify
        // d'un Error natif n'expose aucune propriété énumérable), ce qui
        // masquerait le vrai message ici.
        console.warn(
          '[MapBridge] updateNavigationTrace: le SDK a levé une exception (couleurs tout de même appliquées) : ' +
            core.errorMessage(error),
        );
      }
    },
  });
})(window.MapCore);
