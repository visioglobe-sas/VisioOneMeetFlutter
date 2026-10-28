// custom-theme : thèmes de scène 3D (`view.themes`, `view.setTheme`) et
// couleurs d'accent de l'UI du SDK (`view.accentColor` /
// `view.textAccentColor`). La carte de cet écran est créée avec
// `{ enableShadows: true }`. Voir docs/features/custom-theme.md.
(function (core) {
  core.register({
    // `custom-theme` : liste des thèmes de scène 3D enregistrés
    // (`view.themes`, lecture seule — `['day', 'night', 'goldenHour']`
    // en 1.1.0). Requête/réponse `themesLoaded` ({requestId, themes}) ;
    // `themes` vide si la carte n'est pas prête. Il n'existe pas de
    // getter du thème courant (1.1.0 inclus) : c'est le natif qui le suit.
    // Voir docs/features/custom-theme.md.
    getThemes: function (requestId) {
      var view = core.view;
      core.sendToNative('themesLoaded', {
        requestId: requestId,
        themes: view ? view.themes.slice() : [],
      });
    },

    // `view.setTheme(name)` : change uniquement l'éclairage de la scène
    // 3D (lumières directionnelle + ambiante), jamais l'UI — et sans
    // effet visible si la vue n'a pas été créée avec
    // `enableShadows: true` (voir `setup`). Lève
    // `Cannot apply given theme <name> as it isn't registered.` pour un
    // id absent de `view.themes` : rapporté via `themeApplied`.
    setTheme: function (name) {
      var view = core.view;
      if (!view) return;
      try {
        view.setTheme(name);
        core.sendToNative('themeApplied', { success: true, theme: name });
      } catch (error) {
        console.error('[MapBridge] setTheme a échoué:', error);
        core.sendToNative('themeApplied', {
          success: false,
          theme: name,
          message: core.errorMessage(error),
        });
      }
    },

    // `view.accentColor` / `view.textAccentColor` : propriétés
    // assignables, appliquées en direct à l'UI du SDK (bouton "Go" de la
    // fiche POI, "Add a step"...). Une valeur qui n'est ni hex, ni rgba,
    // ni hsl lève `Invalid color format provided...` : rapporté via
    // `accentColorsApplied`.
    setAccentColors: function (accentColor, textAccentColor) {
      var view = core.view;
      if (!view) return;
      try {
        view.accentColor = accentColor;
        view.textAccentColor = textAccentColor;
        core.sendToNative('accentColorsApplied', { success: true });
      } catch (error) {
        console.error('[MapBridge] setAccentColors a échoué:', error);
        core.sendToNative('accentColorsApplied', {
          success: false,
          message: core.errorMessage(error),
        });
      }
    },
  });
})(window.MapCore);
