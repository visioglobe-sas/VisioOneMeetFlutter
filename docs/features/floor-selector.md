# Sélection d'étage / bâtiment

## Description

Change de bâtiment et/ou d'étage depuis un panneau natif, via `view.goToFloor(floor)` / `view.goToBuilding(building)` côté SDK VisioOne, exposés au pont `window.MapBridge` / `VisioOneController` sous le nom `goToFloor(buildingId, floorId?)`.

Point notable, comme pour `goto-poi` : `goToFloor` existait déjà de bout en bout dans ce dépôt *avant* cette branche — `window.MapBridge.goToFloor` dans `assets/www/map.html` et `VisioOneController.goToFloor({required String buildingId, String? floorId})` dans `lib/visio_one/visio_one_controller.dart` étaient tous les deux déjà présents sur `main`. C'est exactement ce que `VisioOneHub/CHECKLIST.md` traquait sous 🟡 : « `goToFloor` existe sur le contrôleur, pas relié à une UI ». Mais contrairement à `goto-poi`, la pièce manquante n'était pas juste un bouton : sans identifiants de bâtiment/étage connus côté Dart, aucun bouton n'aurait su quoi afficher ni quel `buildingId`/`floorId` passer, sans les coder en dur — ce que ce dépôt s'interdit. Il a donc fallu une nouvelle commande de pont pour faire remonter la structure réelle de la venue (`getVenueLayout` / message `venueLayout`) avant de pouvoir construire le panneau.

**Cette feature coexiste avec le floor-selector natif du SDK**, affiché automatiquement sur la carte sans aucun code applicatif (partie d'UI `floorSelector`, pilotable via `setUIPartVisible` — voir `docs/features/`). Le panneau construit ici ne le remplace pas : il démontre que l'app hôte peut piloter les mêmes changements d'étage/bâtiment depuis sa **propre** UI (menu, liste, bouton personnalisé...), un besoin réel pour un client qui veut une UI cohérente avec le reste de son app plutôt que le widget par défaut du SDK. Les deux UI restent synchronisées automatiquement : chacune écoute l'évènement `currentfloorchanged` du SDK.

## Step by step

1. **Vérifier l'existant côté pont** (aucun code à écrire ici) :
   ```js
   // assets/www/map.html, dans window.MapBridge
   goToFloor: function (buildingId, floorId) {
     if (!venue || !view) return;
     var building = venue.venueLayout.buildings.find(function (b) { return b.id === buildingId; });
     if (!building) return;
     if (floorId) {
       var floor = building.floors.find(function (f) { return f.id === floorId; });
       if (floor) view.goToFloor(floor);
     } else {
       view.goToBuilding(building);
     }
   },
   ```
   ```dart
   // lib/visio_one/visio_one_controller.dart
   Future<void> goToFloor({required String buildingId, String? floorId}) =>
       _call('goToFloor', [buildingId, floorId]);
   ```
   Rien à ajouter ici — c'était déjà tout câblé.
2. **Ajouter la commande manquante côté pont** : `getVenueLayout()` (Native -> JS) et son événement de réponse `venueLayout` (JS -> Native), sur le même schéma requête/réponse que `startItinerary` / `itineraryComputed` (une commande fire-and-forget côté Dart, une réponse asynchrone sur le flux `messages`) :
   ```js
   // assets/www/map.html
   getVenueLayout: function () {
     if (!venue || !view) return;
     sendToNative('venueLayout', {
       currentBuildingId: view.currentBuilding ? view.currentBuilding.id : null,
       currentFloorId: view.currentFloor ? view.currentFloor.id : null,
       buildings: venue.venueLayout.buildings.map(function (building) {
         return {
           id: building.id,
           defaultFloorId: building.defaultFloorID,
           floors: building.floors
             .slice()
             .sort(function (a, b) { return b.levelIndex - a.levelIndex; })
             .map(function (floor) { return { id: floor.id, levelIndex: floor.levelIndex }; }),
         };
       }),
     });
   },
   ```
   ```dart
   // lib/visio_one/visio_one_controller.dart
   Future<void> getVenueLayout() => _run('window.MapBridge.getVenueLayout()');
   ```
   Documenté dans les deux tableaux de `docs/COMMUNICATION_GUIDE.md` §3, comme toute évolution du contrat de messages.
3. **Écrire l'overlay de feature** (`lib/features/floor_selector_overlay.dart`, widget `FloorSelectorOverlay`) :
   - À l'ouverture (`initState`), s'abonne directement à `controller.messages` (pas via `Feature.onMapMessage`, voir "Points d'attention") et appelle `controller.getVenueLayout()`.
   - Sur réception de `venueLayout` : construit la liste des bâtiments/étages, présélectionne le bâtiment/étage courant (`currentBuildingId`/`currentFloorId`).
   - Affiche, si plus d'un bâtiment, une rangée de `ChoiceChip` (un par bâtiment) au-dessus d'une colonne de boutons pleine largeur (un par étage du bâtiment sélectionné, triés du plus haut au plus bas), le bouton de l'étage courant mis en évidence (`FilledButton` + icône check vs `OutlinedButton`).
   - Chaque tap appelle `controller.goToFloor(buildingId: ..., floorId: ...)` (ou sans `floorId` pour un changement de bâtiment, qui bascule sur l'étage par défaut du bâtiment).
   - Sur réception de `floorChanged` : met à jour la sélection affichée, pour rester synchronisé si l'étage change par un autre biais (floor-selector natif du SDK, `goToPOI` d'un autre écran...).
4. **Brancher la feature au catalogue** (`lib/features/feature.dart`) : nouvelle entrée `Feature.floorSelector('floor-selector')`, résolue vers `FloorSelectorOverlay(controller: controller)` dans `buildOverlay` ; pas de nouveau cas dans `onMapMessage` (l'overlay écoute `controller.messages` lui-même, voir point 3).
5. **Ajouter l'entrée du menu** (titre + description EN/FR) dans `lib/l10n/app_en.arb` / `app_fr.arb` (`floorSelectorTitle` / `floorSelectorDescription`), puis régénérer les classes `AppLocalizations` (`flutter gen-l10n`, ou automatique au prochain `flutter pub get`).

## Points d'attention

- **`goToFloor` avait déjà la méthode câblée jusqu'au bout du pont JS, avant cette branche** (statut 🟡 dans `VisioOneHub/CHECKLIST.md`), mais contrairement à `goto-poi` (où il ne manquait qu'un bouton), ici il manquait une **source de données** : sans connaître les `buildingId`/`floorId` réels de la venue, impossible de construire des boutons sans les coder en dur pour une carte de démo précise — ce que la consigne interdit explicitement. D'où l'ajout de `getVenueLayout`/`venueLayout`, la seule vraie nouveauté de pont de cette branche.
- **`Building`/`Floor` n'exposent aucun nom ou libellé côté SDK** (`@visioglobe/visioone`, `Building.d.ts`/`Floor.d.ts` : `Building` n'a que `id`, `floors`, `defaultFloorID` ; `Floor` n'a que `id`, `altitude`, `levelIndex`) — vérifié dans les types TypeScript vendus avec le package npm, pas dans une doc à part. Le floor-selector natif du SDK lui-même n'affiche que `levelIndex.toString()` (vérifié en grepant `visioone.umd.cjs`), faute de mieux. Ce panneau fait donc pareil : les boutons affichent `Floor <levelIndex>` (ex. `Floor 0`, `Floor -1`), pas de nom lisible. Un client qui veut des libellés (« RDC », « Étage 1 »...) devra les dériver côté app (mapping statique `floorId -> libellé`, ou convention de nommage sur les `id` publiés par VisioMapEditor), pas depuis cet appel SDK.
- **Recoupement volontaire avec le floor-selector par défaut du SDK** : le SDK affiche déjà son propre widget de sélection d'étage sur la carte (partie d'UI `floorSelector`, visible sans aucun code applicatif, masquable via `setUIPartVisible('floorSelector', false)`). Cette feature n'a pas vocation à le remplacer — elle démontre la capacité de l'app hôte à piloter le même changement depuis sa propre UI. Les deux restent synchronisés : notre overlay réagit à `currentfloorchanged` (relayé en `floorChanged`) exactement comme le ferait n'importe quel autre listener du SDK, donc actionner l'un met bien à jour l'autre.
- **L'overlay écoute `controller.messages` directement, plutôt que de passer par `Feature.onMapMessage`** (le mécanisme utilisé par `poi-click`) : `onMapMessage` route les messages non gérés par `VisioOneMapShell` vers l'écran de feature *actif*, pas vers l'overlay du bottom sheet lui-même (qui peut être fermé et rouvert indépendamment de l'écran). Comme `venueLayout`/`floorChanged` ne concernent que ce panneau tant qu'il est monté, et que `controller.messages` est un `Stream` broadcast (donc multi-abonnés sans conflit), l'overlay s'y abonne lui-même dans `initState`/`dispose` — plus simple que d'étendre le mécanisme partagé pour un seul consommateur.
- **Tri des étages du plus haut au plus bas** (`levelIndex` décroissant) côté JS avant l'envoi, pour afficher le panneau comme un tableau d'ascenseur classique (le plus haut étage en haut de liste) — choix de présentation de ce dépôt, pas une garantie d'ordre du SDK (`venue.venueLayout.buildings[].floors` n'est pas documenté comme trié).
- **Changer de bâtiment sans étage précisé** (`floorId: null`) bascule sur l'étage par défaut du bâtiment (`view.goToBuilding(building)`, qui utilise `defaultFloorID` en interne côté SDK) — comportement du SDK, pas quelque chose que ce pont recalcule lui-même.
- **`goToFloor` échoue silencieusement si `buildingId`/`floorId` ne correspond à rien** (mêmes `Array.find` que `goToPOI`) — mais avec cette feature, ce cas ne devrait plus se produire en pratique puisque les identifiants affichés proviennent toujours de `venueLayout`, jamais d'une saisie libre.

## Pour aller plus loin

- Voir `docs/COMMUNICATION_GUIDE.md` de ce dépôt (§3, tableaux Native → JS / JS → Native, et §6/§7 pour la procédure suivie ici : ajouter une commande **et** un événement de réponse).
- Feature liée : `goto-poi` (`docs/features/goto-poi.md`) est le cas le plus simple de ce même statut 🟡 — un bouton manquant, sans nouvelle donnée à faire remonter du SDK.
