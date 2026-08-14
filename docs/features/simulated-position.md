# Position simulée

## Description

Anime une position trackée simulée (avec son cercle de précision) en va-et-vient entre deux POI, via `view.allowTracking = true` puis `view.injectTrackedPosition({ position, precisionCircleRadius })` côté SDK VisioOne, exposés au pont `window.MapBridge` / `VisioOneController` sous les noms `injectTrackedPosition(latitude, longitude, precisionCircleRadius)` et `stopTrackedPosition()`.

Contrairement à `goto-poi`/`compute-navigation`/`floor-selector`, aucune de ces trois commandes n'existait sur le pont avant cette branche — `injectTrackedPosition` est une méthode neuve côté SDK pour ce dépôt. Une nouvelle commande de résolution, `resolvePoiPosition(requestId, poiId)`, a aussi été ajoutée : un POI n'expose pas de lat/lng directement (voir "Points d'attention"), donc convertir un Place ID saisi par l'utilisateur en coordonnées WGS84 exploitables par `injectTrackedPosition` demande un aller-retour JS -> Dart, sur le même schéma requête/réponse que `getVenueLayout`/`venueLayout` (`floor-selector`).

Il n'y a pas de vrai positionnement indoor derrière : un `Timer.periodic` interpole linéairement entre l'origine et la destination, ping-pong à l'infini, en lieu et place d'un vrai flux BLE/Wi-Fi/UWB (voir `ROADMAP.md` du hub, "Suivi de position indoor réel" reste hors scope tant qu'aucun matériel n'est disponible).

## Step by step

1. **Ajouter les trois commandes côté JS** (`assets/www/map.html`, dans `window.MapBridge`) :
   ```js
   resolvePoiPosition: function (requestId, poiId) {
     if (!venue) return;
     var poi = venue.pois.find(function (p) { return p.id === poiId; });
     var source = poi
       ? (poi.markers[0] || poi.labels[0] || poi.images[0])
       : null;
     var position = source
       ? { latitude: source.position.latitude, longitude: source.position.longitude }
       : null;
     sendToNative('poiPositionResolved', { requestId: requestId, poiId: poiId, position: position });
   },

   injectTrackedPosition: function (latitude, longitude, precisionCircleRadius) {
     if (!view) return;
     view.allowTracking = true;
     view.injectTrackedPosition({
       position: { latitude: latitude, longitude: longitude },
       precisionCircleRadius: precisionCircleRadius,
     });
   },

   stopTrackedPosition: function () {
     if (!view) return;
     view.allowTracking = false;
   },
   ```
2. **Exposer les appels Dart typés** (`lib/visio_one/visio_one_controller.dart`) :
   ```dart
   Future<void> resolvePoiPosition(String requestId, String poiId) =>
       _call('resolvePoiPosition', [requestId, poiId]);

   Future<void> injectTrackedPosition({
     required double latitude,
     required double longitude,
     required double precisionCircleRadius,
   }) => _call('injectTrackedPosition', [latitude, longitude, precisionCircleRadius]);

   Future<void> stopTrackedPosition() => _run('window.MapBridge.stopTrackedPosition()');
   ```
   Documenté dans les deux tableaux de `docs/COMMUNICATION_GUIDE.md` §3 (deux commandes Native → JS + un événement de réponse `poiPositionResolved`), comme toute évolution du contrat de messages.
3. **Porter le va-et-vient par une session, pas par l'overlay** (`lib/visio_one/simulated_position_session.dart`, classe `SimulatedPositionSession`) : un `Timer.periodic` (150 ms) qui interpole linéairement entre `origin`/`destination` (fraction `t` qui va de 0 à 1 puis revient à 0, `~0,04`/tick soit ~25 ticks par traversée), et appelle `controller.injectTrackedPosition(...)` à chaque tick avec le `radiusMeters` courant. Cette session est créée une fois dans le constructeur de `VisioOneController` (`controller.simulatedPosition`), pas dans le `State` de l'overlay — voir "Points d'attention" pour pourquoi.
4. **Écrire l'overlay de feature** (`lib/features/simulated_position_overlay.dart`, widget `SimulatedPositionOverlay`) : deux champs Place ID ("Origin POI ID" / "Destination POI ID"), un `Slider` de rayon (1 à 20 m, défaut 5 m), et un bouton toggle Start/Stop (`ValueListenableBuilder` sur `session.isRunning` pour refléter l'état réel de la session, y compris si le panneau est rouvert pendant qu'elle tourne déjà). Au Start :
   - résout `origin`/`destination` via `controller.resolvePoiPosition(requestId, poiId)`, un `requestId` par appel pour distinguer les deux réponses concurrentes sur `controller.messages` (`poiPositionResolved`) ;
   - si l'un des deux ne résout à aucune position, affiche `POI not found: <id>` sous les champs et n'appelle pas `session.start(...)` ;
   - sinon, appelle `session.start(origin: ..., destination: ...)`.
   Au Stop : `session.stop()`, qui annule le `Timer` et appelle `controller.stopTrackedPosition()`.
5. **Brancher la feature au catalogue** (`lib/features/feature.dart`) : nouvelle entrée `Feature.simulatedPosition('simulated-position')`, résolue vers `SimulatedPositionOverlay(controller: controller)` dans `buildOverlay` ; pas de nouveau cas dans `onMapMessage` (l'overlay écoute `controller.messages` lui-même pour `poiPositionResolved`, même idiom que `floor-selector` pour `venueLayout`).
6. **Ajouter l'entrée du menu** (titre + description EN/FR) dans `lib/l10n/app_en.arb` / `app_fr.arb` (`simulatedPositionTitle` / `simulatedPositionDescription`), puis régénérer les classes `AppLocalizations` (`flutter gen-l10n`, ou automatique au prochain `flutter pub get`).

## Points d'attention

- **`injectTrackedPosition` exige `view.allowTracking = true` au préalable**, sans quoi le SDK lève une exception (voir `View.ts`, commentaire sur `allowTracking` : "Setting it to true is mandatory for the features to work"). `window.MapBridge.injectTrackedPosition` l'active systématiquement lui-même à chaque appel plutôt que d'exposer une commande séparée pour l'activer — ce booléen n'a pas d'autre usage dans cette démo, pas besoin de le piloter indépendamment.
- **Pas de méthode dédiée côté SDK pour arrêter/effacer le marqueur simulé et son cercle.** C'est `allowTracking = false` qui les retire de la carte (revérifié dans `View.ts` : aucune méthode `clearTrackedPosition`/`removeTrackedPosition` n'existe) — d'où `stopTrackedPosition()` qui ne fait que ça, au lieu d'un `injectTrackedPosition(null)` ou équivalent qui n'existe pas.
- **Un POI n'expose pas de lat/lng directement.** `POI` (voir `POI.d.ts` du package `@visioglobe/visioone`) ne porte que `markers`, `labels`, `images`, `surfaces` — la position WGS84 vient de la première entrée disponible parmi `markers[0].position`, `labels[0].position`, `images[0].position` (toutes trois de type `Position`, `{latitude, longitude, altitude?}`, exactement le format attendu par `injectTrackedPosition`). Si aucune des trois n'existe (POI purement surfacique, sans marker/label/image) ou si l'ID est introuvable, `resolvePoiPosition` répond `position: null` — traité côté Dart comme "POI not found", même affichage que pour un ID invalide.
- **Le rayon de précision ne s'applique qu'au prochain tick.** Bouger le slider pendant que la simulation tourne change `session.radiusMeters` immédiatement, mais la valeur n'est lue par `injectTrackedPosition` qu'au tick suivant (au plus 150 ms plus tard) — pas de redémarrage nécessaire, mais pas un effet instantané au pixel près non plus.
- **La session survit à la fermeture du bottom sheet, contrairement à `OccupancySimulationOverlay`.** Ce dernier porte son `Timer` dans le `State` de son overlay, qui est détruit (`dispose()`, timer annulé) dès que le bottom sheet se ferme. Ici, l'exigence est différente : la position simulée doit continuer de bouger sur la carte même panneau fermé, jusqu'à un Stop explicite ou la sortie de l'écran de feature (qui détruit tout, `VisioOneController`/`WebView` comprises). D'où `SimulatedPositionSession`, portée par `VisioOneController` (une instance par carte, créée dans son constructeur, disposée dans `VisioOneController.dispose()`) plutôt que par l'overlay — le seul état qui doit survivre à une réouverture du panneau dans ce dépôt, à ce jour.
- **Ceci démontre la mécanique d'un dot tracké**, pas une vraie intégration de positionnement indoor : pour un cas client réel, remplacer le `Timer.periodic` de `SimulatedPositionSession` par un abonnement à la vraie source (BLE/Wi-Fi/UWB) qui appellerait `controller.injectTrackedPosition(...)` à chaque nouvelle position reçue, sans toucher au pont ni au SDK.

## Pour aller plus loin

- Voir `docs/COMMUNICATION_GUIDE.md` de ce dépôt (§3 pour le contrat de messages complet, §6/§7 pour la procédure suivie ici : deux commandes **et** un événement de réponse).
- Feature liée : `floor-selector` (`docs/features/floor-selector.md`) est le précédent de ce dépôt pour le schéma requête/réponse par message JS -> Native, et pour un overlay qui écoute `controller.messages` directement plutôt que via `Feature.onMapMessage`.
- Feature liée : `occupancy-simulated` (`docs/features/occupancy-simulated.md`) est le précédent pour le `Timer.periodic` côté Dart pilotant une commande de pont en boucle — la différence de portée du `Timer` (overlay vs contrôleur) est le seul écart d'architecture entre les deux.
- Version "vrai capteur" : voir le `ROADMAP.md` du hub (`VisioOneHub`), positionnement indoor réel (BLE/Wi-Fi/UWB) — hors scope tant qu'aucun matériel n'est disponible.
