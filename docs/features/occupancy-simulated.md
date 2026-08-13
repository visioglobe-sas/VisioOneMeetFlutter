# Occupation temps réel (données simulées)

## Description

Colore dynamiquement la surface d'un POI pour refléter un statut d'occupation (libre / bientôt occupé / occupé), via une nouvelle commande `updateOccupancy` ajoutée au pont `window.MapBridge` / `VisioOneController`.

Il n'y a pas de vrai capteur derrière : un `Timer.periodic` côté Dart fait tourner la couleur toutes les 2,5 secondes, en lieu et place d'un flux IoT réel. C'est le point de départ pour brancher une vraie source de données (websocket, polling d'API) sans rien changer côté pont ou côté SDK.

## Step by step

1. **Ajouter la commande côté JS** (`assets/www/map.html`, dans `window.MapBridge`) :
   ```js
   updateOccupancy: function (occupancy) {
     if (!venue) return;
     occupancy.forEach(function (entry) {
       var poi = venue.pois.find(function (p) { return p.id === entry.planId; });
       if (!poi) return;
       poi.surfaces.forEach(function (surface) {
         venue.updateSurface(surface, { color: entry.color });
       });
     });
   },
   ```
2. **Exposer la commande côté Dart** (`lib/visio_one/visio_one_controller.dart`), en suivant le même pattern que les autres commandes natives → JS (`_call`, arguments encodés en JSON) :
   ```dart
   Future<void> updateOccupancy(List<Map<String, Object?>> occupancy) =>
       _call('updateOccupancy', [occupancy]);
   ```
3. **Piloter un timer depuis l'overlay de feature** (`lib/features/occupancy_simulation_overlay.dart`, widget `OccupancySimulationOverlay`) : démarrer un `Timer.periodic` qui appelle `controller.updateOccupancy([{'planId': placeId, 'color': nextColor}])` à chaque tick, et l'annuler (`Timer.cancel()`) quand la simulation s'arrête ou que l'overlay est disposé.
4. **Toujours remettre `color: null` en arrêtant la simulation** — sinon la surface reste bloquée sur la dernière couleur simulée.
5. Exposer un contrôle utilisateur (ici, un champ "Place ID" + un bouton toggle) — une feature du catalogue doit être démontrable via une interaction, pas seulement câblée en silence.

## Points d'attention

- **`planId` doit être un vrai ID de POI de la carte chargée.** `venue.pois.find(...)` échoue silencieusement (pas d'erreur remontée côté Dart) si l'ID ne correspond à rien.
- **`color: null` réinitialise l'apparence de la surface**, même mécanisme que `clearSelection` avec `selectionColor: undefined` côté JS — c'est la façon de "rendre" une place à son état normal, pas une couleur par défaut à coder en dur.
- **Ne jamais appeler `JSON.parse()` sur un argument reçu dans `window.MapBridge.*`** (piège déjà documenté dans `docs/COMMUNICATION_GUIDE.md` §5) : Dart encode déjà les arguments via `jsonEncode` avant de les interpoler dans le script généré, donc par le temps que la méthode JS s'exécute, l'argument est déjà une valeur JS native (ici, une liste d'objets), pas du texte JSON à re-parser.
- **Annuler le `Timer` dans `dispose()`**, pas seulement quand l'utilisateur arrête la simulation — sinon le timer continue de tourner sur un `State` détruit.
- Ceci démontre la **mécanique** de mise à jour temps réel, pas une vraie intégration IoT — pour un cas client réel, remplacer le `Timer.periodic` par un abonnement à la vraie source (websocket, polling d'API) sans toucher au pont ni au SDK.

## Pour aller plus loin

- Voir `docs/COMMUNICATION_GUIDE.md` de ce repo pour le contrat de messages complet du pont.
- Version "vrai capteur" : voir le `ROADMAP.md` du hub (`VisioOneHub`), feature "Suivi d'actifs connectés (IoT)" — hors scope tant qu'aucun flux IoT réel n'est disponible.
