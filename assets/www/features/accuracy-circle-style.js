// accuracy-circle-style : couleur/opacité du cercle de précision de la
// position trackée (`view.updatePositionTrackerGraphicOptions`). Voir
// docs/features/accuracy-circle-style.md.
(function (core) {
  core.register({
    // Cercle de précision seulement (pas la flèche centrale). Le SDK ne fait
    // que stocker ces options (appliquées au prochain injectTrackedPosition)
    // et les remet à ses valeurs par défaut (#0094f0, 0.3) dès que
    // `allowTracking` repasse à false — le natif les réapplique donc à
    // chaque Start. Couleur invalide ou opacité non numérique => throw côté
    // SDK, d'où le try/catch.
    updatePositionTrackerGraphicOptions: function (color, opacity) {
      var view = core.view;
      if (!view) return;
      try {
        view.updatePositionTrackerGraphicOptions({ color: color, opacity: opacity });
      } catch (error) {
        console.error('[MapBridge] updatePositionTrackerGraphicOptions a échoué :', error);
      }
    },
  });
})(window.MapCore);
