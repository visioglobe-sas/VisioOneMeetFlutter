// explore-mode : lit/change `view.currentExploreMode` ('global' /
// 'building' / 'floor') et relaie l'événement SDK `exploremodechanged`
// (message `exploreModeChanged`). Voir docs/features/explore-mode.md.
(function (core) {
  // Déclenché à chaque changement de `view.currentExploreMode`, quelle
  // qu'en soit la source — `setExploreMode` ci-dessous, mais aussi une
  // interaction directe caméra/carte (déplacer la caméra en/hors d'un
  // bâtiment en mode 'global' l'ouvre/le ferme ; un clic en mode
  // 'building' bascule automatiquement en mode 'floor'). Relayé sans
  // condition pour que le panneau natif reste synchronisé même quand ce
  // n'est pas lui qui a causé le changement — même schéma que
  // `currentfloorchanged` (features/floor-selector.js).
  core.onViewCreated(function (view) {
    view.addEventListener('exploremodechanged', function (event) {
      core.sendToNative('exploreModeChanged', { currentExploreMode: event.currentExploreMode });
    });
  });

  core.register({
    // Une simple affectation de propriété, pas un appel de méthode : le SDK
    // anime lui-même la transition caméra/scène et déclenche
    // `exploremodechanged` une fois appliquée — aucun message de
    // confirmation séparé n'est envoyé ici. Voir le type `ExploreMode` des
    // typings de @visioglobe/visioone pour la sémantique de chaque mode.
    setExploreMode: function (mode) {
      var view = core.view;
      if (!view) return;
      view.currentExploreMode = mode;
    },

    // Requête/réponse (message `exploreMode`, sans requestId puisqu'il n'y a
    // jamais qu'un seul mode d'exploration courant à répondre) : renvoie le
    // mode courant pour présélectionner le bon bouton dès l'ouverture du
    // panneau, sans attendre un `exploremodechanged`.
    getExploreMode: function () {
      var view = core.view;
      if (!view) return;
      core.sendToNative('exploreMode', { currentExploreMode: view.currentExploreMode });
    },
  });
})(window.MapCore);
