# Réagir au clic sur un POI

## Description

Affiche les infos du POI que l'utilisateur vient de taper sur la carte (nom + identifiant), dans un panneau natif Flutter, en réaction à l'événement SDK `poiclick` sur `view`.

Le message JS -> Native correspondant (`poiSelected`, payload `{id, name}`) existait déjà de bout en bout côté pont avant cette branche : `assets/www/map.html` (fonction `forwardViewEvents`) l'émettait bien à chaque tap sur un POI, et `VisioOneController` le recevait sur son flux `messages`. Ce qui manquait était la dernière étape : router ce message vers une UI visible. `lib/visio_one/visio_one_map_shell.dart`, méthode `_onMessage`, avait un `default:` avec un commentaire explicite disant que `poiSelected` (et les autres types non gérés) "sont à router vers l'UI native de l'app hôte. Rien à faire ici dans ce squelette d'intégration." — c'est exactement ce commentaire que cette branche referme.

## Step by step

1. **Vérifier l'existant côté pont** (rien à ajouter ici) :
   ```js
   // assets/www/map.html, dans forwardViewEvents(view)
   v.addEventListener('poiclick', function (event) {
     var poi = event.pois && event.pois[0];
     if (!poi) return;
     sendToNative('poiSelected', {
       id: poi.id,
       name: poi.labels && poi.labels[0] ? poi.labels[0].text : null,
     });
   });
   ```
   Déjà présent sur `main`, avec la ligne `poiSelected` déjà documentée dans `docs/COMMUNICATION_GUIDE.md` §3.

2. **Donner à `VisioOneMapShell` un point d'extension pour les messages qu'il ne gère pas lui-même** (`lib/visio_one/visio_one_map_shell.dart`) : un callback optionnel `onMessage`, appelé depuis le `default:` de `_onMessage` :
   ```dart
   final void Function(BuildContext context, VisioOneMessage message)? onMessage;
   // ...
   default:
     if (mounted) widget.onMessage?.call(context, message);
   ```
   Ce callback est optionnel (`null` par défaut) plutôt qu'un `case 'poiSelected':` codé en dur directement dans le squelette partagé : `map.html` diffuse le même événement `poiclick` sur **toutes** les cartes créées par n'importe quel écran de feature (chaque écran recrée sa propre carte, mais charge le même `map.html`). Un `case` en dur aurait fait apparaître le panneau POI sur les écrans `reset-view` et `occupancy-simulated` aussi, pas seulement sur l'écran dédié à `poi-click`.

3. **Écrire la réaction UI propre à la feature** (`lib/features/poi_click_overlay.dart`, fonction `handlePoiSelectedMessage`) : extraire `id`/`name` du payload et ouvrir un bottom sheet modal avec ces infos.
   ```dart
   void handlePoiSelectedMessage(BuildContext context, VisioOneMessage message) {
     if (message.type != 'poiSelected') return;
     final data = message.data;
     final id = data is Map ? data['id'] as String? : null;
     final name = data is Map ? data['name'] as String? : null;
     if (id == null && name == null) return;
     showModalBottomSheet<void>(
       context: context,
       backgroundColor: Theme.of(context).colorScheme.surface,
       showDragHandle: true,
       builder: (sheetContext) => /* nom + ID du POI */,
     );
   }
   ```

4. **Brancher la feature au catalogue** (`lib/features/feature.dart`) : nouvelle entrée `Feature.poiClick`, avec sa propre méthode `onMapMessage` qui délègue à `handlePoiSelectedMessage` — les autres features n'implémentent rien ici.

5. **Relier `FeatureScreen` au nouveau callback** (`lib/features/feature_screen.dart`) :
   ```dart
   VisioOneMapShell(
     hash: kDefaultMapHash,
     overlayBuilder: (context, controller) => feature.buildOverlay(context, controller),
     onMessage: (context, message) => feature.onMapMessage(context, message),
   )
   ```

6. **Ajouter l'entrée du menu** (titre + description EN/FR) dans `lib/l10n/app_en.arb` / `app_fr.arb` (`poiClickTitle` / `poiClickDescription`), résolues automatiquement dans `Feature.title`/`Feature.description`.

7. **Garder un contenu au FAB, même sans contrôle à piloter** : `PoiClickOverlay` (le widget renvoyé par `Feature.buildOverlay` pour `poiClick`) n'a ni champ ni bouton — juste un rappel textuel que la réaction se produit ailleurs (au tap sur un POI), pas depuis ce panneau. Choix délibéré pour garder l'écran cohérent avec les autres (un FAB toujours présent une fois la carte prête), plutôt que de complexifier `VisioOneMapShell`/`FeatureScreen` pour rendre le FAB optionnel par feature.

## Points d'attention

- **Le message était déjà "reçu mais non routé" avant cette branche** (statut 🟡 dans `VisioOneHub/CHECKLIST.md`) : `VisioOneController.messages` recevait bien `poiSelected` en streaming, mais `VisioOneMapShell._onMessage` l'avalait silencieusement dans son `default:`. Un bon rappel que 🟡 signifie "câblé jusqu'au bridge, pas jusqu'à l'UI" — le flux Dart existait, mais rien n'écoutait dessus côté widget.
- **`map.html` est un bundle partagé par tous les écrans de feature**, et chaque écran recrée sa propre carte (pas d'instance partagée entre écrans — voir `CLAUDE.md` du hub). Ça veut dire que l'événement `poiclick` (et donc le message `poiSelected`) se déclenche sur **n'importe quel** écran de feature où l'utilisateur tape un POI, pas seulement sur l'écran `poi-click`. D'où le choix d'un callback `onMessage` optionnel sur `VisioOneMapShell` plutôt qu'un `case` en dur dans le squelette partagé : seul l'écran `poi-click` renseigne ce callback, les autres restent inertes face à ce message.
- **`event.pois[0]`, pas `event.pois`** : `poiclick` peut en théorie remonter plusieurs POI si des surfaces se superposent ; le pont n'en retient que le premier (voir `map.html`). Pas un souci observé avec la carte de démo, mais à garder en tête si la carte cible a des géométries chevauchantes.
- **`name` peut être `null`** si le POI n'a pas de label (`poi.labels` vide) — le panneau retombe alors sur l'ID comme titre (`name ?? id!`). Ne jamais supposer `name` non nul juste parce qu'`id` l'est.
- **Le bottom sheet ici est déclenché par l'événement carte, pas par un tap sur le FAB** — seule feature du catalogue à s'écarter du pattern "FAB ouvre le panneau". Le style visuel reste identique (fond opaque `colorScheme.surface`, poignée de glissement, dismissable par swipe/tap sur le scrim) pour rester cohérent avec le reste de l'app, mais le déclencheur est différent : documenté explicitement pour qu'un futur lecteur ne cherche pas en vain un bouton qui ouvrirait ce panneau.
- **`_onMessage` tourne sur l'isolate Dart racine**, pas un thread d'arrière-plan (voir `docs/COMMUNICATION_GUIDE.md` §8) : appeler `showModalBottomSheet` directement depuis le callback est sûr, sans repost manuel.

## Pour aller plus loin

- Voir `docs/COMMUNICATION_GUIDE.md` de ce dépôt (§3 et §7) pour le contrat de messages complet du pont et la procédure pour ajouter un nouvel événement JS -> Native.
- Feature liée : `goto-poi` (`goToPOI`) fait le chemin inverse — centrer la caméra sur un POI choisi côté Dart plutôt que réagir à un tap venant de la carte.
