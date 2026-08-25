# Verrou caméra sur la position

## Description

Bascule un interrupteur "Camera lock", façon "recentrer sur ma position" d'une appli GPS, qui verrouille le focus de la caméra sur la position trackée simulée de `simulated-position`. Côté SDK VisioOne, c'est `view.lockCameraPositionOnTracking` (booléen) exposé au pont `window.MapBridge` / `VisioOneController` sous le nom `setCameraLockOnPosition(locked)`.

Cette feature dépend directement de `simulated-position` (`docs/features/simulated-position.md`) : verrouiller la caméra sur une position qui ne bouge pas ne démontrerait rien. L'écran de cette branche réutilise donc tel quel `SimulatedPositionOverlay` (champs Place ID Origin/Destination, slider de rayon, bouton Start/Stop) et ajoute par-dessus l'interrupteur de verrouillage, plutôt que de dupliquer la logique de résolution de POI et de démarrage/arrêt du va-et-vient — voir "Step by step".

`lockCameraPositionOnTracking` a une sœur, `lockCameraOrientationOnTracking` (verrouille aussi l'*orientation* de la caméra, en s'appuyant sur les données du capteur d'orientation de l'appareil) : volontairement hors scope de cette branche, qui ne démontre que le verrou de *position*.

## Step by step

1. **Ajouter la commande côté JS** (`assets/www/map.html`, dans `window.MapBridge`) :
   ```js
   setCameraLockOnPosition: function (locked) {
     if (!view) return;
     view.lockCameraPositionOnTracking = !!locked;
   },
   ```
2. **Exposer l'appel Dart typé** (`lib/visio_one/visio_one_controller.dart`) :
   ```dart
   Future<void> setCameraLockOnPosition(bool locked) =>
       _call('setCameraLockOnPosition', [locked]);
   ```
   Documenté dans le tableau Native → JS de `docs/COMMUNICATION_GUIDE.md` §3 (une seule commande, pas d'événement de réponse — c'est fire-and-forget, comme `setUIPartVisible`).
3. **Porter l'état du verrou sur `SimulatedPositionSession`, pas sur l'overlay** (`lib/visio_one/simulated_position_session.dart`) : un nouveau `ValueNotifier<bool> isCameraLocked`, et une méthode `setCameraLocked(bool locked)` qui met à jour ce notifier puis appelle `controller.setCameraLockOnPosition(locked)`. Même raisonnement que pour `isRunning` (voir `docs/features/simulated-position.md`, "Points d'attention") : cet état doit rester cohérent même si le panneau est fermé/réouvert pendant que la simulation tourne. `start()` et `stop()` remettent tous les deux `isCameraLocked` à `false` (voir "Points d'attention").
4. **Écrire l'overlay de feature par composition** (`lib/features/camera_lock_on_position_overlay.dart`, widget `CameraLockOnPositionOverlay`) : un `Column` qui empile `SimulatedPositionOverlay(controller: controller)` tel quel, puis un `SwitchListTile` "Camera lock" piloté par deux `ValueListenableBuilder` imbriqués sur `session.isRunning` (pour l'activer/désactiver) et `session.isCameraLocked` (pour son état). `onChanged` n'est renseigné que si `isRunning` est vrai — sinon `null`, ce qui grise l'interrupteur nativement (Material `SwitchListTile`).
5. **Brancher la feature au catalogue** (`lib/features/feature.dart`) : nouvelle entrée `Feature.cameraLockOnPosition('camera-lock-on-position')`, résolue vers `CameraLockOnPositionOverlay(controller: controller)` dans `buildOverlay` ; pas de nouveau cas dans `onMapMessage` (aucun message JS → Native propre à cette feature, la résolution de POI est entièrement gérée par `SimulatedPositionOverlay` qu'elle réutilise).
6. **Ajouter l'entrée du menu** (titre + description EN/FR) dans `lib/l10n/app_en.arb` / `app_fr.arb` (`cameraLockOnPositionTitle` / `cameraLockOnPositionDescription`), puis régénérer les classes `AppLocalizations` (`flutter gen-l10n`, ou automatique au prochain `flutter pub get`).

## Points d'attention

- **`lockCameraPositionOnTracking` n'a d'effet que si `allowTracking` est déjà à `true`.** D'après le commentaire de `View.ts` côté SDK : *"Set it to true to bind camera focus on tracking position. This won't have any effect if flag 'allowTracking' isn't set to true."* — contrairement à `injectTrackedPosition`, qui lève une exception si `allowTracking` est encore `false`, ici c'est un no-op silencieux, pas une erreur. `allowTracking` est déjà mis à `true` par `injectTrackedPosition` dès que la simulation de `simulated-position` démarre (voir son propre doc), donc dans cet écran l'ordre est toujours le bon : l'interrupteur de verrou n'est de toute façon affiché actif qu'une fois la simulation lancée (voir point suivant).
- **L'interrupteur est désactivé tant qu'aucune simulation ne tourne**, via `onChanged: isRunning ? session.setCameraLocked : null` — verrouiller la caméra sur une position qui n'existe pas encore n'a pas de sens, et un `SwitchListTile` avec `onChanged: null` se grise nativement sans code supplémentaire.
- **Le verrou repart systématiquement à `false` dès qu'une simulation s'arrête ou (re)démarre**, jamais laissé "collé" à `true` : `SimulatedPositionSession.stop()` et `.start()` appellent tous les deux `_setCameraLocked(false)` (qui court-circuite si déjà à `false`, pour ne pas spammer le pont). Ça couvre les trois cas demandés — Stop explicite, erreur "POI not found" (qui survient forcément avant tout `start()`, donc le verrou est déjà à `false` et l'interrupteur déjà grisé à ce moment-là), et sortie de l'écran de feature. Ce dernier cas est en réalité couvert "gratuitement" : chaque écran de feature crée son propre `VisioOneController`/`SimulatedPositionSession` frais (voir `VisioOneMapShell`), donc rouvrir l'écran repart toujours d'un `isCameraLocked` à `false` par construction, sans code de reset dédié à la fermeture.
- **Deux instances distinctes de `SimulatedPositionSession`.** L'écran `simulated-position` et l'écran `camera-lock-on-position` ont chacun leur propre `VisioOneController` (et donc leur propre `SimulatedPositionSession`) : démarrer une simulation sur l'un n'affecte pas l'autre. C'est cohérent avec le reste du dépôt (aucune carte partagée entre écrans de feature), mais à garder en tête si vous vous attendez à un état partagé entre les deux démos.
- **Choisir deux POI suffisamment éloignés pour voir l'effet.** Comme pour `simulated-position`, deux places de parking adjacentes ne montreront quasiment aucun mouvement de caméra une fois le verrou activé — préférez deux POI dans des zones clairement distinctes du site (`poi-click`, en tapant la carte, permet de trouver des ID valides).
- **`lockCameraOrientationOnTracking` (verrou d'orientation) est hors scope.** Cette branche ne touche qu'à `lockCameraPositionOnTracking`. Une démo de verrou d'orientation nécessiterait en plus une source de données d'orientation d'appareil (capteur), qu'aucune feature de ce dépôt n'expose à ce jour.

## Pour aller plus loin

- Voir `docs/features/simulated-position.md` : prérequis direct de cette feature, notamment pour `injectTrackedPosition`/`allowTracking` et pourquoi la session de tracking vit sur le contrôleur plutôt que sur l'overlay.
- Voir `docs/COMMUNICATION_GUIDE.md` §3 pour l'entrée `setCameraLockOnPosition` dans le tableau Native → JS.
- Version "vrai capteur" : voir le `ROADMAP.md` du hub (`VisioOneHub`), positionnement indoor réel (BLE/Wi-Fi/UWB) — le verrou caméra fonctionnerait à l'identique une fois une vraie source de position branchée sur `injectTrackedPosition`.
