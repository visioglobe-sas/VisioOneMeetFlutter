# Itinéraire

## Description

Calcule et affiche un itinéraire entre deux POI (origine, destination), via `venue.computeNavigation({ origin, destination, isAccessible, ... })` + `view.setCurrentNavigationTrace(trace)` côté SDK VisioOne, exposé au pont `window.MapBridge` / `VisioOneController` sous le nom `startItinerary({ origin, destination, isAccessible })`.

Point notable, comme pour `goto-poi` : `startItinerary` existait déjà de bout en bout côté pont *avant* cette branche — `window.MapBridge.startItinerary` dans `assets/www/map.html` (qui répond même côté JS -> Native avec un message `itineraryComputed`, `{ instructions }`) et `VisioOneController.startItinerary({ required String origin, required String destination, bool isAccessible = false })` dans `lib/visio_one/visio_one_controller.dart` étaient tous les deux déjà présents sur `main`. C'est exactement ce que `VisioOneHub/CHECKLIST.md` traquait sous 🟡 : « `startItinerary` existe, pas relié à une UI ». Le seul manquant était une affordance UI — deux champs (origine/destination) et un bouton pour déclencher la commande.

## Step by step

1. **Vérifier l'existant côté pont** (aucun code à écrire ici, seulement à confirmer) :
   ```js
   // assets/www/map.html, dans window.MapBridge
   startItinerary: function (args) {
     if (!venue || !view) return;
     var navigation = venue.computeNavigation({
       origin: args.origin,
       destination: args.destination,
       isAccessible: !!args.isAccessible,
       type: 'fastest',
       firstNodeAsIntersection: false,
       mergeFloorChangeInstructions: false,
     });
     var trace = venue.createNavigationTrace(navigation);
     view.setCurrentNavigationTrace(trace);
     sendToNative('itineraryComputed', { instructions: navigation.instructions });
   },
   ```
   ```dart
   // lib/visio_one/visio_one_controller.dart
   Future<void> startItinerary({
     required String origin,
     required String destination,
     bool isAccessible = false,
   }) {
     return _call('startItinerary', [
       {'origin': origin, 'destination': destination, 'isAccessible': isAccessible},
     ]);
   }
   ```
   Rien à ajouter ni dans `map.html`, ni dans `VisioOneController` : la commande complète (calcul + affichage de la trace sur la carte) était déjà là.
2. **Écrire l'overlay de feature** (`lib/features/compute_navigation_overlay.dart`, widget `ComputeNavigationOverlay`) : deux champs texte ("From (place ID)" / "To (place ID)") empilés en `Column`, plus un bouton "Itinerary" qui appelle `controller.startItinerary(origin: ..., destination: ...)`. Reprend l'UX du sibling React Native (`src/features/ComputeNavigationOverlay.tsx`), seule plateforme où cette feature était déjà complète — deux champs + un bouton, pas de gestion des instructions renvoyées par `itineraryComputed` (voir "Points d'attention").
3. **Brancher la feature au catalogue** (`lib/features/feature.dart`) : nouvelle entrée `Feature.computeNavigation('compute-navigation')`, résolue vers `ComputeNavigationOverlay(controller: controller)` dans `buildOverlay` ; pas de cas à ajouter dans `onMapMessage` (fire-and-forget comme `goto-poi`, cette feature n'a pas besoin d'écouter `itineraryComputed`).
4. **Ajouter l'entrée du menu** (titre + description EN/FR) dans `lib/l10n/app_en.arb` / `app_fr.arb` (`computeNavigationTitle` / `computeNavigationDescription`), régénérées dans `AppLocalizations` par `flutter pub get` (voir `l10n.yaml`).

## Points d'attention

- **Le contrôleur avait déjà la méthode, câblée jusqu'au bout du pont JS, avant cette branche** (statut 🟡 dans `VisioOneHub/CHECKLIST.md`), exactement comme `goto-poi` et `reset-view` avant elles : ce qui manquait n'était ni le SDK, ni le pont, seulement un bouton pour déclencher la commande. Confirmé en lisant le code existant plutôt que supposé, comme demandé par le workflow du hub.
- **`itineraryComputed` (la réponse JS -> Native avec `instructions`) n'est pas consommée côté Dart.** Le résultat visuellement utile — le tracé affiché sur la carte — vient de `view.setCurrentNavigationTrace(trace)`, déjà exécuté côté JS avant l'envoi du message ; les `instructions` texte-à-texte ne sont donc affichées nulle part dans cette démo, ni ici ni sur le sibling React Native qui sert de référence UX (`src/screens/useVisioMap.ts`, `startItinerary`, fire-and-forget identique). Un client voulant afficher des instructions turn-by-turn devrait écouter ce message (`VisioOneController.messages`, `type == 'itineraryComputed'`) comme le fait `FloorSelectorOverlay` pour `venueLayout`/`floorChanged`.
- **`origin`/`destination` sont des Place ID**, pas des coordonnées ni des noms affichés — mêmes identifiants que ceux utilisés par `goto-poi`. Un ID invalide ou introuvable fait échouer `venue.computeNavigation` côté JS (try/catch implicite dans `_run` de `VisioOneController`, qui logue et n'interrompt pas l'app) : pas d'erreur remontée à l'UI, la carte ne montre simplement aucun tracé.
- **`isAccessible` existe déjà sur le contrôleur** (paramètre nommé optionnel, défaut `false`) mais n'a pas de champ dédié dans cet overlay, pour rester au plus près de l'UI de référence React Native (deux champs + un bouton, pas de toggle accessibilité). Voir aussi la ligne "Exclusion de modalités" du catalogue (`docs/features/navigation-exclude-modalities.md` côté hub) pour une future feature qui exposerait ce paramètre à l'utilisateur.

## Pour aller plus loin

- Feature liée : `goto-poi` (`docs/features/goto-poi.md`), même situation de départ (méthode déjà câblée jusqu'au pont, juste besoin d'un bouton) et mêmes Place ID en entrée.
- Feature liée : `floor-selector` (`docs/features/floor-selector.md`) montre le pattern à suivre si une future itération veut consommer `itineraryComputed` (écouter `controller.messages` tant que l'overlay est monté).
