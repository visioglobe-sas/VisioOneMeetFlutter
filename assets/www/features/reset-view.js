// reset-view : recentre la caméra sur la vue globale du site
// (`view.goToGlobal()`). Voir docs/features/reset-view.md.
(function (core) {
  core.register({
    goToGlobal: function () {
      var view = core.view;
      if (view) view.goToGlobal();
    },
  });
})(window.MapCore);
