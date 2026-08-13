# Aller à un lieu / POI

## Description

Centre la caméra sur un POI donné par son identifiant et le sélectionne visuellement, via `view.goToPOI(poi)` (précédé d'un `view.goToFloor(poi.floor)` pour basculer sur le bon étage) côté SDK VisioOne, exposé au pont `window.MapBridge` / `VisioOneController` sous le nom `goToPOI`.

Point notable, comme pour `reset-view` : `goToPOI` existait déjà de bout en bout dans ce dépôt *avant* cette branche — `window.MapBridge.goToPOI` dans `assets/www/map.html` et `VisioOneController.goToPOI(String poiId)` dans `lib/visio_one/visio_one_controller.dart` étaient tous les deux déjà présents sur `main` (et documentés dans `docs/COMMUNICATION_GUIDE.md`, section 5, comme exemple de référence pour l'encodage JSON des arguments). C'est exactement ce que `VisioOneHub/CHECKLIST.md` traquait sous 🟡 : « `goToPOI` existe sur le contrôleur, pas relié à un bouton ». Le seul manquant était une affordance UI pour déclencher cette commande — et un moyen de revenir en arrière (`clearSelection`, lui aussi déjà présent).

## Step by step

1. **Vérifier l'existant côté pont** (aucun code à écrire ici, seulement à confirmer) :
   ```js
   // assets/www/map.html, dans window.MapBridge
   goToPOI: function (poiId) {
     if (!venue || !view) return;
     var poi = venue.pois.find(function (p) { return p.id === poiId; });
     if (!poi) return;
     view.goToFloor(poi.floor).then(function () {
       view.goToPOI(poi);
     });
   },
   // ...
   clearSelection: function () {
     if (!venue) return;
     venue.pois.forEach(function (poi) {
       poi.surfaces.forEach(function (surface) {
         venue.updateSurface(surface, { selectionColor: undefined });
       });
     });
   },
   ```
   ```dart
   // lib/visio_one/visio_one_controller.dart
   Future<void> goToPOI(String poiId) => _call('goToPOI', [poiId]);
   Future<void> clearSelection() => _run('window.MapBridge.clearSelection()');
   ```
   Les deux commandes (aller à, effacer la sélection) étaient déjà là côté pont — rien à ajouter ni dans `map.html`, ni dans `VisioOneController`.
2. **Écrire l'overlay de feature** (`lib/features/goto_poi_overlay.dart`, widget `GotoPoiOverlay`) : un champ texte "Place ID" + un bouton "Go" qui appelle `controller.goToPOI(placeId)`, et un bouton "Clear" qui appelle `controller.clearSelection()`. Même agencement en `Row` que `OccupancySimulationOverlay` (champ extensible + bouton(s) collés à droite), pour rester visuellement cohérent avec les autres écrans de feature.
3. **Brancher la feature au catalogue** (`lib/features/feature.dart`) : nouvelle entrée `Feature.gotoPoi('goto-poi')`, résolue vers `GotoPoiOverlay(controller: controller)` dans `buildOverlay` ; pas de cas à ajouter dans `onMapMessage` (cette feature n'écoute aucun message JS -> Native, elle ne fait qu'émettre des commandes Native -> JS).
4. **Ajouter l'entrée du menu** (titre + description EN/FR) dans `lib/l10n/app_en.arb` / `app_fr.arb` (`gotoPoiTitle` / `gotoPoiDescription`), puis régénérer les classes `AppLocalizations` (`flutter gen-l10n`, ou automatique au prochain `flutter pub get` — voir `l10n.yaml`).

## Points d'attention

- **Le contrôleur avait déjà la méthode, câblée jusqu'au bout du pont JS, avant cette branche** (statut 🟡 dans `VisioOneHub/CHECKLIST.md`) : contrairement à `poi-click` (où c'était le sens JS -> Native qui manquait de routage UI), ici c'est le sens Native -> JS qui n'avait tout simplement aucun bouton pour le déclencher. Un bon rappel que 🟡 peut désigner un manque côté UI dans n'importe quelle direction du pont, pas seulement la réception de messages.
- **"Clear" n'a pas besoin de connaître le `placeId` actuellement sélectionné.** Contrairement à `updateOccupancy` (où arrêter la simulation exige de réappliquer `color: null` sur le POI précisément ciblé — voir `docs/features/occupancy-simulated.md`), la sélection visuelle est un état global côté SDK : `clearSelection()` parcourt tous les POI de la venue et retire leur `selectionColor`, sans paramètre. Pas besoin de mémoriser un état côté Dart pour ce bouton.
- **Aucun changement de `placeId` sur "Clear"** : le champ texte n'est pas vidé au clic sur "Clear", pour permettre de retaper "Go" sur le même Place ID sans avoir à le ressaisir — comportement identique à `clearPlace` sur le sibling React Native (`src/screens/useVisioMap.ts`, `src/features/GoToPoiOverlay.tsx`), qui ne réinitialise pas non plus le state `placeId`.
- **`goToPOI` échoue silencieusement si l'ID ne correspond à aucun POI** (`venue.pois.find(...)` renvoie `undefined`, la fonction retourne sans rien faire) — même piège que documenté pour `updateOccupancy`. Pas d'erreur remontée côté Dart : un ID invalide se traduit juste par une caméra qui ne bouge pas.
- **`goToPOI` change aussi d'étage si besoin** (`view.goToFloor(poi.floor)` avant `view.goToPOI(poi)`) : contrairement à `goToGlobal` (`reset-view`), qui ne fait que recentrer la caméra sur la vue globale sans toucher à l'étage affiché.

## Pour aller plus loin

- Voir `docs/COMMUNICATION_GUIDE.md` de ce dépôt (section 5, qui prend `goToPOI` comme exemple de référence pour l'encodage JSON des arguments Dart -> JS, et l'avertissement sur `JSON.parse`) pour le contrat de messages complet du pont.
- Feature liée : `poi-click` (`docs/features/poi-click.md`) fait le chemin inverse — réagir à un tap sur la carte plutôt qu'émettre une commande depuis un bouton natif.
