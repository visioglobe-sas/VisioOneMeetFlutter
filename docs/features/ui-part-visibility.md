# Masquage sélectif de l'UI

## Description

Affiche ou masque individuellement une partie de l'UI overlay que le SDK VisioOne dessine lui-même par-dessus la carte, via `view.setUIPartVisible(uiPart, isVisible)` côté SDK, exposé au pont `window.MapBridge` / `VisioOneController` sous le nom `setUIPartVisible(part, visible)`. Il existe exactement 5 valeurs `uiPart`, sensibles à la casse (voir `visioone/src/VisioOne/View/View.ts`, type `UIPart`) : `floorSelector`, `navigation`, `poiDetails`, `search`, `userTracking`.

Point notable, comme pour `goto-poi`/`floor-selector` : `setUIPartVisible` existait déjà de bout en bout dans ce dépôt *avant* cette branche — `window.MapBridge.setUIPartVisible` dans `assets/www/map.html` et `VisioOneController.setUIPartVisible(String part, bool visible)` dans `lib/visio_one/visio_one_controller.dart` étaient tous les deux déjà présents sur `main` (scaffold initial du dépôt, `docs/COMMUNICATION_GUIDE.md` §3 le documentait déjà). Le seul manquant était l'UI native pour piloter les 5 valeurs : cette branche ajoute exactement ça, cinq interrupteurs dans le bottom sheet.

## Step by step

1. **Vérifier l'existant côté pont** (aucun code à écrire ici, seulement à confirmer) :
   ```js
   // assets/www/map.html, dans window.MapBridge
   setUIPartVisible: function (part, visible) {
     if (!view) return;
     view.setUIPartVisible(part, visible);
   },
   ```
   ```dart
   // lib/visio_one/visio_one_controller.dart
   Future<void> setUIPartVisible(String part, bool visible) =>
       _call('setUIPartVisible', [part, visible]);
   ```
   Rien à ajouter ici — c'était déjà tout câblé, y compris dans `docs/COMMUNICATION_GUIDE.md`.
2. **Écrire l'overlay de feature** (`lib/features/ui_part_visibility_overlay.dart`, widget `UiPartVisibilityOverlay`) : un `SwitchListTile` par valeur `UIPart` (énumérées dans une petite enum Dart privée `_UIPart`, qui porte la chaîne exacte à transmettre au pont), tous à `true` (visible) à l'ouverture du panneau — même défaut que le SDK lui-même, rien n'est masqué tant que l'utilisateur n'a rien touché. Chaque bascule appelle immédiatement `controller.setUIPartVisible(part.value, isVisible)`, effet visible tout de suite sur la carte derrière le panneau puisque le bottom sheet est translucide-scrim mais pas la carte.
3. **Brancher la feature au catalogue** (`lib/features/feature.dart`) : nouvelle entrée `Feature.uiPartVisibility('ui-part-visibility')`, résolue vers `UiPartVisibilityOverlay(controller: controller)` dans `buildOverlay` ; pas de cas à ajouter dans `onMapMessage` (cette feature n'écoute aucun message JS -> Native, elle ne fait qu'émettre des commandes Native -> JS, comme `goto-poi`).
4. **Ajouter l'entrée du menu et les libellés des 5 interrupteurs** dans `lib/l10n/app_en.arb` / `app_fr.arb` (`uiPartVisibilityTitle` / `uiPartVisibilityDescription` pour le menu, `uiPartVisibility<Part>Label` pour chaque interrupteur — ex. `uiPartVisibilityFloorSelectorLabel`), puis régénérer les classes `AppLocalizations` (`flutter gen-l10n`, ou automatique au prochain `flutter pub get` — voir `l10n.yaml`). Contrairement aux autres overlays de ce dépôt (qui codent en dur leurs libellés internes en anglais, voir `ResetViewOverlay`/`ComputeNavigationOverlay`), les 5 libellés d'interrupteurs passent ici par `AppLocalizations` : ce sont des noms de concepts SDK stables (pas une saisie libre de démo), qui valent la peine d'être traduits comme le titre/la description du menu.

## Points d'attention

- **N'appeler `setUIPartVisible` qu'une fois la vue/venue chargée.** Comme tout le reste du pont Native -> JS de ce dépôt, `window.MapBridge.setUIPartVisible` sort en silence (`if (!view) return;`) si appelé avant que `view` existe. En pratique cela ne peut pas arriver ici : le FAB qui ouvre ce panneau n'est affiché par `VisioOneMapShell` qu'une fois l'état `ready` atteint (voir `visio_one_map_shell.dart`), donc `view` est nécessairement prêt dès qu'un interrupteur est visible à l'écran. À retenir si vous réutilisez `setUIPartVisible` ailleurs, en dehors de ce panneau.
- **Les 5 valeurs `uiPart` sont exactes et sensibles à la casse** : `floorSelector`, `navigation`, `poiDetails`, `search`, `userTracking` — pas de variante `snake_case` ni `PascalCase`, pas de 6e valeur. Elles viennent du type `UIPart` de `View.ts` côté SDK ; toute faute de frappe échoue silencieusement côté JS (le SDK ignore une valeur inconnue) sans remonter d'erreur au pont Native, donc une faute de frappe ici ne casse rien de visible à part l'interrupteur qui n'a aucun effet.
- **Masquer `search` ou `navigation` retire le seul moyen client de déclencher ces flux SDK** depuis l'UI par défaut de la carte (pas de recherche de POI au clavier, plus de tracé d'itinéraire déclenché depuis l'UI native du SDK). Dans cette démo, ce n'est jamais définitif : les deux interrupteurs restent accessibles dans le même bottom sheet, donc on peut toujours les rebasculer à ON pour les faire réapparaître. Un client qui masquerait ces parties dans une vraie intégration doit prévoir sa propre UI de remplacement (ex. son propre champ de recherche, son propre bouton itinéraire) avant de les masquer définitivement — ce que les features `goto-poi`/`compute-navigation`/`floor-selector` de ce même dépôt démontrent déjà côté UI native.
- **Aucun état ne persiste entre deux ouvertures de l'écran de feature.** Comme documenté dans `VisioOneHub` (pattern "menu de navigation par feature" : pas d'instance de carte partagée entre écrans), quitter puis rouvrir cet écran recrée une carte fraîche avec les 5 parties d'UI de nouveau visibles, quel que soit leur état au moment de la sortie — cohérent avec le choix de simplicité assumé du dépôt, mais à mentionner si un client s'attend à une persistance.

## Pour aller plus loin

- Voir `docs/COMMUNICATION_GUIDE.md` de ce dépôt (§3) pour l'entrée `setUIPartVisible` dans le tableau Native -> JS.
- Feature liée : `floor-selector` (`docs/features/floor-selector.md`) démontre déjà le recoupement entre une partie d'UI native du SDK (`floorSelector`) et un panneau propre à l'app hôte — ce panneau permet justement de masquer le floor-selector natif du SDK une fois le panneau custom en place, si un client ne veut pas des deux à l'écran en même temps.
