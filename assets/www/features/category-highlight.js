// category-highlight : liste les catégories de la venue (`venue.categories`,
// noms via `venue.translator.translateCategory`) et met en avant / rétablit
// les surfaces des POI d'une catégorie (`venue.updateSurface`). Voir
// docs/features/category-highlight.md.
(function (core) {
  function poisOfCategory(venue, categoryId) {
    return venue.pois.filter(function (poi) {
      return poi.categories.some(function (c) { return c.id === categoryId; });
    });
  }

  core.register({
    // Réponse `categoriesLoaded` ({ requestId, categories: [{id, label}] }).
    // `id` (`Category = { readonly id: string }`) est un identifiant interne
    // brut (une chaîne numérique sur la carte de démo partagée, ex.
    // "1".."11"), pas un libellé -- confirmé en direct. Le nom lisible vient
    // de `venue.translator.translateCategory()`. `id` sert au filtrage/à la
    // mise en avant, `label` est uniquement pour l'affichage.
    getCategories: function (requestId) {
      var venue = core.venue;
      if (!venue) {
        core.sendToNative('categoriesLoaded', { requestId: requestId, categories: [] });
        return;
      }
      var locale = venue.currentLocale;
      core.sendToNative('categoriesLoaded', {
        requestId: requestId,
        categories: venue.categories.map(function (c) {
          var translated = venue.translator.translateCategory(c, locale);
          return { id: c.id, label: (translated && translated.name) || c.id };
        }),
      });
    },

    // Pas de méthode SDK dédiée pour "highlight by category" : construite à
    // partir de primitives — filtre sur `poi.categories` (un POI peut avoir
    // plusieurs catégories) puis `venue.updateSurface(surface, { color })`
    // par surface. Un POI sans surface (marker/label seul) ne se surligne
    // simplement pas visuellement : ce n'est pas un bug. Le natif est
    // responsable de réinitialiser la catégorie précédemment mise en avant
    // avant d'appeler ceci, pour ne jamais en cumuler deux.
    highlightCategory: function (categoryId) {
      var venue = core.venue;
      if (!venue) return;
      poisOfCategory(venue, categoryId).forEach(function (poi) {
        poi.surfaces.forEach(function (surface) {
          venue.updateSurface(surface, { color: '#FF6B00' });
        });
      });
    },

    // Réinitialise ('initial', pas `undefined` — seul `'initial'` restaure
    // la couleur définie par le bundle de carte, voir
    // docs/features/clickable-surface.md) les surfaces de tous les POI de
    // la catégorie.
    clearCategoryHighlight: function (categoryId) {
      var venue = core.venue;
      if (!venue) return;
      poisOfCategory(venue, categoryId).forEach(function (poi) {
        poi.surfaces.forEach(function (surface) {
          venue.updateSurface(surface, { color: 'initial' });
        });
      });
    },
  });
})(window.MapCore);
