// ui-part-visibility : affiche/masque un élément de l'UI fournie par le SDK
// (`view.setUIPartVisible`). Aussi utilisé par `native-ui-replacement`. Voir
// docs/features/ui-part-visibility.md.
(function (core) {
  core.register({
    setUIPartVisible: function (part, visible) {
      var view = core.view;
      if (!view) return;
      view.setUIPartVisible(part, visible);
    },
  });
})(window.MapCore);
