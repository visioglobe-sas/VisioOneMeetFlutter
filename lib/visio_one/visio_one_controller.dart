import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'simulated_position_session.dart';
import 'visio_one_message.dart';

/// État observable du POI dynamique actuellement suivi par la démo
/// `dynamic-poi-crud` — un seul à la fois (contrat de cette démo, pas une
/// limite du SDK, voir [VisioOneController.dynamicPoi]). Immuable : chaque
/// changement (création, texte de label modifié) remplace l'instance plutôt
/// que de la muter, comme le reste de l'état exposé par ce contrôleur.
class DynamicPoiInfo {
  const DynamicPoiInfo({required this.id, required this.labelText});

  /// Id du POI créé à la volée (`newId` passé à
  /// [VisioOneController.createDynamicPOI]).
  final String id;

  /// Dernier texte connu du label attaché à ce POI.
  final String labelText;

  DynamicPoiInfo withLabelText(String labelText) => DynamicPoiInfo(id: id, labelText: labelText);
}

/// Nom du `JavaScriptChannel` exposé à `map.html` (`window.VisioOneBridge`).
///
/// Un seul canal JS -> Native, avec une enveloppe `{type, data}` (voir
/// [VisioOneMessage]) plutôt qu'un canal par événement : garde la surface
/// de pont minimale, comme recommandé dans les guides des autres plateformes
/// (`GUIDE_COMMUNICATION_SDK.md`, `APP_SDK_COMMUNICATION.md`).
const String kVisioOneBridgeChannel = 'VisioOneBridge';

/// Pont typé Native <-> SDK VisioOne (exécuté en JS dans la WebView).
///
/// - **Native -> JS** : une méthode Dart par commande, qui appelle
///   `window.MapBridge.<methode>(...)` via [WebViewController.runJavaScript].
///   Chaque argument structuré est encodé en JSON ([jsonEncode]) avant
///   interpolation dans le script — jamais de concaténation de texte brut,
///   pour éviter toute injection JS (voir `docs/COMMUNICATION_GUIDE.md`).
/// - **JS -> Native** : un seul [JavaScriptChannel] ([kVisioOneBridgeChannel]),
///   exposé en flux typé via [messages].
class VisioOneController {
  VisioOneController._(this._webViewController) {
    simulatedPosition = SimulatedPositionSession(this);
  }

  final WebViewController _webViewController;
  final StreamController<VisioOneMessage> _messages =
      StreamController<VisioOneMessage>.broadcast();

  /// Pilote le va-et-vient de `simulated-position`. Voir sa documentation de
  /// tête pour pourquoi cette session vit ici plutôt que dans l'overlay de la
  /// feature : elle doit survivre à la fermeture du bottom sheet.
  late final SimulatedPositionSession simulatedPosition;

  /// Crée le contrôleur et son [WebViewController] sous-jacent.
  ///
  /// Doit rester asynchrone : l'activation du débogage Android
  /// (`AndroidWebViewController.enableDebugging`) doit être faite avant la
  /// création du `WebViewController` pour être prise en compte.
  static Future<VisioOneController> create() async {
    if (kDebugMode && WebViewPlatform.instance is AndroidWebViewPlatform) {
      await AndroidWebViewController.enableDebugging(true);
    }

    final webViewController = WebViewController();
    final controller = VisioOneController._(webViewController);
    await controller._initialize();
    return controller;
  }

  /// Le [WebViewController] sous-jacent, à passer à [WebViewWidget].
  WebViewController get webViewController => _webViewController;

  /// Flux des messages JS -> Native (`ready`, `error`, `poiSelected`, ...).
  Stream<VisioOneMessage> get messages => _messages.stream;

  Future<void> _initialize() async {
    await _webViewController.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _webViewController.setBackgroundColor(const Color(0xFF000000));
    await _webViewController.addJavaScriptChannel(
      kVisioOneBridgeChannel,
      onMessageReceived: _handleRawMessage,
    );
    if (kDebugMode) {
      await _webViewController.setOnConsoleMessage((message) {
        debugPrint('VisioOne[console.${message.level.name}]: ${message.message}');
      });
    }

    if (kDebugMode) {
      final platform = _webViewController.platform;
      if (platform is WebKitWebViewController) {
        await platform.setInspectable(true);
      }
    }
  }

  /// Charge la page hôte bundlée (`assets/www/map.html`, référencée dans
  /// `pubspec.yaml`). Le SDK VisioOne lui-même n'est initialisé qu'à l'appel
  /// de [setup], déclenché depuis `onPageFinished` par [VisioOneMapScreen].
  Future<void> loadMapPage() {
    return _webViewController.loadFlutterAsset('assets/www/map.html');
  }

  /// Initialise (ou réinitialise) la carte pour le hash donné.
  ///
  /// `hash` est la chaîne de 41 caractères identifiant une carte publiée
  /// sur my.visioglobe.com (voir docs/INTEGRATION_GUIDE.md, partie D).
  ///
  /// `baseURL` correspond à l'option `baseURL` de `loadVenue` (voir
  /// `docs/features/custom-base-url.md`) : le serveur de cartes à
  /// interroger, à la place du SaaS Visioglobe par défaut
  /// (`https://mapserver.visioglobe.com/`) utilisé quand `baseURL` est
  /// `null`. Ce n'est pas une propriété mutable sur une venue déjà
  /// chargée : la seule façon de la changer est de rappeler [setup], qui
  /// recharge entièrement la carte (même chemin que pour changer de hash).
  ///
  /// `viewOptions` est passé tel quel en 3e argument de `createView`
  /// (`null` = aucun, comportement par défaut du SDK). Seule `custom-theme`
  /// le renseigne (`{'enableShadows': true}`), voir
  /// `docs/features/custom-theme.md`.
  Future<void> setup(String hash, {String? baseURL, Map<String, Object>? viewOptions}) =>
      _call('setup', [hash, baseURL, viewOptions]);

  /// Recentre la caméra sur la vue globale du site.
  Future<void> goToGlobal() => _run('window.MapBridge.goToGlobal()');

  /// Centre la caméra sur un POI et le sélectionne visuellement.
  Future<void> goToPOI(String poiId) => _call('goToPOI', [poiId]);

  /// Change de bâtiment, et éventuellement d'étage au sein de ce bâtiment.
  Future<void> goToFloor({required String buildingId, String? floorId}) =>
      _call('goToFloor', [buildingId, floorId]);

  /// Efface la sélection visuelle courante (surlignage de POI).
  Future<void> clearSelection() => _run('window.MapBridge.clearSelection()');

  /// Change le mode d'exploration courant du bâtiment
  /// (`view.currentExploreMode = mode`), l'un de `'global'`, `'building'`,
  /// `'floor'` — voir `docs/features/explore-mode.md`.
  Future<void> setExploreMode(String mode) => _call('setExploreMode', [mode]);

  /// Demande le mode d'exploration courant.
  ///
  /// Fire-and-forget comme [getVenueLayout]/[getCategories] : la réponse
  /// arrive de façon asynchrone sur [messages] sous la forme d'un message
  /// `exploreMode` (`{currentExploreMode}`) — même idiome requête/réponse
  /// que le reste de ce pont, sans `requestId` puisqu'il n'y a jamais qu'un
  /// seul mode d'exploration courant à répondre. Voir
  /// `docs/features/explore-mode.md`.
  Future<void> getExploreMode() => _run('window.MapBridge.getExploreMode()');

  /// Demande la liste des bâtiments/étages de la venue courante.
  ///
  /// Fire-and-forget comme le reste du pont Native -> JS : la réponse
  /// arrive de façon asynchrone sur [messages] sous la forme d'un message
  /// `venueLayout` (même schéma requête/réponse que [startItinerary], qui
  /// répond via `itineraryComputed`), pas comme valeur de retour de cet
  /// appel. Voir `assets/www/map.html`, `window.MapBridge.getVenueLayout`.
  Future<void> getVenueLayout() => _run('window.MapBridge.getVenueLayout()');

  /// Calcule et affiche un itinéraire entre deux POI.
  Future<void> startItinerary({
    required String origin,
    required String destination,
    bool isAccessible = false,
  }) {
    return _call('startItinerary', [
      {
        'origin': origin,
        'destination': destination,
        'isAccessible': isAccessible,
      },
    ]);
  }

  /// Calcule et affiche un itinéraire entre deux POI en excluant certaines
  /// particularités de segment (`excludedAttributes` de
  /// `venue.computeNavigation`, ex. forcer un itinéraire qui évite les
  /// ascenseurs) — même appel que [startItinerary], avec ce seul paramètre en
  /// plus. Pas de recalcul automatique quand [excludedAttributes] change
  /// seul : la démo `navigation-exclude-modalities` ne relit son switch
  /// "Avoid elevator" qu'à l'appui du bouton "Itinerary" (voir
  /// `NavigationExcludeModalitiesOverlay`).
  ///
  /// La documentation JSDoc du SDK pour `excludedAttributes` donne
  /// `"elevator"` comme exemple, mais la valeur réellement taguée sur les
  /// segments d'ascenseur de cette venue (confirmé en direct — voir
  /// `docs/features/navigation-exclude-modalities.md`) est `'lift'`, pas
  /// `'elevator'`.
  Future<void> startItineraryExcludingModalities({
    required String origin,
    required String destination,
    bool isAccessible = false,
    List<String> excludedAttributes = const [],
  }) {
    return _call('startItineraryExcludingModalities', [
      {
        'origin': origin,
        'destination': destination,
        'isAccessible': isAccessible,
        'excludedAttributes': excludedAttributes,
      },
    ]);
  }

  /// Restyle la trace de navigation actuellement affichée (créée par
  /// [startItinerary]) via `venue.updateNavigationTrace(trace, options)`.
  /// `options` ne porte que des couleurs (`progressColor`,
  /// `progressOutlineColor`, `progressFutureColor`, `previewColor`,
  /// `previewOutlineColor` — voir `CustomNavigationTraceOverlay.kNavigationTracePresets`
  /// pour le catalogue de presets utilisé par cette démo) : sans effet tant
  /// qu'aucune trace n'a été créée (voir `assets/www/map.html`), et pas de
  /// méthode pour revenir à l'apparence par défaut du SDK une fois changée.
  /// Voir `docs/features/custom-navigation-trace.md`, notamment la
  /// `TypeError` interne au SDK que ce pont attrape déjà côté JS.
  Future<void> updateNavigationTrace(Map<String, String> options) =>
      _call('updateNavigationTrace', [options]);

  /// Clé du preset de couleurs actuellement sélectionné pour
  /// `custom-navigation-trace` (voir `CustomNavigationTraceOverlay.kNavigationTracePresets`),
  /// `'visioglobeBlue'` par défaut. Portée ici plutôt que par l'overlay de la
  /// feature, pour survivre à la fermeture du bottom sheet — même raison que
  /// [highlightedCategoryId] ci-dessous : sans ça, rouvrir le panneau après
  /// avoir choisi une couleur perdrait la sélection, et le prochain
  /// itinéraire calculé retomberait sur le bleu par défaut au lieu de la
  /// dernière couleur choisie.
  final ValueNotifier<String> selectedNavigationTracePresetKey = ValueNotifier<String>(
    'visioglobeBlue',
  );

  /// Affiche/masque un élément de l'UI overlay fournie par le SDK
  /// (`floorSelector`, `search`, `poiDetails`, `navigation`, `userTracking`...).
  Future<void> setUIPartVisible(String part, bool visible) =>
      _call('setUIPartVisible', [part, visible]);

  /// Met à jour l'apparence d'un ou plusieurs POI pour refléter un statut
  /// d'occupation (ex. `{'planId': 'B1-UL00-01', 'color': '#E74C3C'}').
  /// `color: null` réinitialise la surface à son apparence normale.
  Future<void> updateOccupancy(List<Map<String, Object?>> occupancy) =>
      _call('updateOccupancy', [occupancy]);

  /// Demande la position WGS84 d'un POI (issue de son marker/label/image —
  /// un POI n'expose pas de lat/lng directement, voir `assets/www/map.html`).
  ///
  /// Fire-and-forget comme [getVenueLayout]/[startItinerary] : la réponse
  /// arrive de façon asynchrone sur [messages] sous la forme d'un message
  /// `poiPositionResolved` portant le même `requestId`, avec `position: null`
  /// si `poiId` ne correspond à aucun POI (ou à un POI sans marker/label/
  /// image). `requestId` permet de distinguer plusieurs requêtes concurrentes
  /// (ex. origine + destination pour `simulated-position`).
  Future<void> resolvePoiPosition(String requestId, String poiId) =>
      _call('resolvePoiPosition', [requestId, poiId]);

  /// Résout le polygone WGS84 de la première surface d'un POI ("zone" pour
  /// la démo `geofencing`) — contrairement à [resolvePoiPosition] (position
  /// ponctuelle marker/label/image), lit `poi.surfaces[0].positions`, même
  /// forme `{latitude, longitude}` que celle attendue par
  /// [injectTrackedPosition].
  ///
  /// Requête/réponse par `requestId` (même schéma que [resolvePoiPosition]) :
  /// la réponse arrive de façon asynchrone sur [messages] sous la forme d'un
  /// message `poiZoneResolved` portant le même `requestId`, avec
  /// `positions: null` si `poiId` ne correspond à aucun POI, ou
  /// `positions: []` (liste vide, pas `null`) si le POI existe mais n'a
  /// aucune surface — deux états distincts à afficher différemment côté
  /// natif. Voir `docs/features/geofencing.md`.
  Future<void> resolvePoiZone(String requestId, String poiId) =>
      _call('resolvePoiZone', [requestId, poiId]);

  /// Colore (ou réinitialise, `active: false`) la/les surface(s) d'un POI
  /// zone comme alerte visuelle de geofencing (`venue.updateSurface`, même
  /// idiome que [updateOccupancy]/[highlightCategory] — `'initial'`, pas
  /// `undefined`, restaure la couleur du bundle de carte). Le test
  /// d'appartenance position/zone est fait côté natif
  /// ([SimulatedPositionSession]) ; cet appel ne fait qu'appliquer son
  /// résultat visuellement. Voir `docs/features/geofencing.md`.
  Future<void> setZoneAlert(String placeId, bool active) =>
      _call('setZoneAlert', [placeId, active]);

  /// Injecte/actualise une position simulée trackée + son cercle de
  /// précision (`precisionCircleRadius`, en mètres). Active `allowTracking`
  /// côté JS au passage (voir `map.html`) — requis par le SDK avant tout
  /// premier appel à `injectTrackedPosition`.
  Future<void> injectTrackedPosition({
    required double latitude,
    required double longitude,
    required double precisionCircleRadius,
  }) => _call('injectTrackedPosition', [latitude, longitude, precisionCircleRadius]);

  /// Arrête le suivi de position simulée. Pas de méthode dédiée côté SDK pour
  /// "effacer" le marqueur/cercle : c'est `allowTracking = false` qui les
  /// retire de la carte, voir `docs/features/simulated-position.md`.
  Future<void> stopTrackedPosition() => _run('window.MapBridge.stopTrackedPosition()');

  /// Verrouille/déverrouille le focus caméra sur la position trackée courante
  /// (`view.lockCameraPositionOnTracking`). Sans effet tant que
  /// `view.allowTracking` est encore à `false` (no-op documenté côté SDK, pas
  /// d'exception contrairement à [injectTrackedPosition]) — voir
  /// `docs/features/camera-lock-on-position.md`. La nouvelle valeur revient
  /// via le message `cameraLockChanged` (event SDK `trackingchanged`), qui
  /// met à jour `simulatedPosition.isCameraLocked`.
  Future<void> setCameraLockOnPosition(bool locked) =>
      _call('setCameraLockOnPosition', [locked]);

  /// Change la couleur/opacité du cercle de précision de la position trackée
  /// (pas de la flèche centrale) (`view.updatePositionTrackerGraphicOptions`). Le SDK ne fait
  /// que mémoriser ces options : elles s'appliquent au prochain
  /// [injectTrackedPosition], et sont remises aux valeurs par défaut du SDK
  /// (`#0094f0`, 0.3) à chaque `allowTracking = false` ([stopTrackedPosition])
  /// — d'où leur réapplication par `SimulatedPositionSession.start`. Voir
  /// `docs/features/accuracy-circle-style.md`.
  Future<void> updatePositionTrackerGraphicOptions({
    required String color,
    required double opacity,
  }) => _call('updatePositionTrackerGraphicOptions', [color, opacity]);

  /// Rend (ou non) les surfaces d'un POI interactives : quand `interactive`
  /// vaut `true`, le SDK gère lui-même le survol/tap sur la surface rendue
  /// (couleur au repos, de survol, de sélection) sans qu'aucun listener ne
  /// soit nécessaire côté app — voir `docs/features/clickable-surface.md`.
  Future<void> setSurfaceInteractive(String placeId, bool interactive) =>
      _call('setSurfaceInteractive', [placeId, interactive]);

  /// Recharge le cache de CustomData métier depuis le serveur puis lit
  /// celles d'un POI donné — `venue.refreshCustomData()` suivi de
  /// `venue.getPOICustomData(poi)` côté JS, enchaînés en un seul aller-retour
  /// de pont plutôt que deux commandes séparées (voir `assets/www/map.html`).
  ///
  /// Requête/réponse par `requestId` (même schéma que [resolvePoiPosition]) :
  /// la réponse arrive de façon asynchrone sur [messages] sous la forme d'un
  /// message `customDataLoaded` portant le même `requestId`, avec
  /// `found: false` si `poiId` ne correspond à aucun POI, et sinon
  /// `customData` — toujours un objet, jamais null/undefined, vide `{}` si
  /// le POI n'a pas de CustomData — voir `docs/features/custom-data.md`.
  Future<void> loadCustomData(String requestId, String poiId) =>
      _call('loadCustomData', [requestId, poiId]);

  /// Demande la liste des catégories (`venue.categories`) de la venue
  /// courante.
  ///
  /// Fire-and-forget comme [getVenueLayout]/[loadCustomData] : la réponse
  /// arrive de façon asynchrone sur [messages] sous la forme d'un message
  /// `categoriesLoaded` portant le même `requestId` et `categories`, une
  /// liste de paires `{id, label}` — `id` (`Category.id`) est un identifiant
  /// interne brut à utiliser pour le filtrage/la mise en avant, `label` est
  /// le nom résolu via `venue.translator.translateCategory()` côté JS, à
  /// n'utiliser que pour l'affichage. Voir `docs/features/category-highlight.md`.
  Future<void> getCategories(String requestId) => _call('getCategories', [requestId]);

  /// Catégorie actuellement mise en avant (ou `null`), voir
  /// `docs/features/category-highlight.md`.
  ///
  /// Portée ici plutôt que par l'overlay de la feature pour survivre à la
  /// fermeture du bottom sheet — même raison que
  /// `SimulatedPositionSession.isRunning` (voir ce fichier) : sans ça,
  /// rouvrir le panneau perdrait la trace de la catégorie actuellement
  /// surlignée sur la carte, et un nouveau tap pourrait cumuler les
  /// surlignages au lieu de les remplacer (contrat : une seule catégorie mise
  /// en avant à la fois).
  final ValueNotifier<String?> highlightedCategoryId = ValueNotifier<String?>(null);

  /// Met en avant tous les POI de [categoryId] (`poi.categories.some(c =>
  /// c.id === categoryId)`), après avoir d'abord réinitialisé la catégorie
  /// précédemment mise en avant s'il y en avait une — garantit qu'une seule
  /// catégorie est jamais surlignée à la fois. No-op si [categoryId] est déjà
  /// la catégorie courante.
  Future<void> highlightCategory(String categoryId) async {
    final previous = highlightedCategoryId.value;
    if (previous == categoryId) return;
    if (previous != null) {
      await _call('clearCategoryHighlight', [previous]);
    }
    highlightedCategoryId.value = categoryId;
    await _call('highlightCategory', [categoryId]);
  }

  /// Réinitialise la catégorie actuellement mise en avant, s'il y en a une.
  Future<void> clearCategoryHighlight() async {
    final current = highlightedCategoryId.value;
    if (current == null) return;
    highlightedCategoryId.value = null;
    await _call('clearCategoryHighlight', [current]);
  }

  /// POI dynamique actuellement suivi par la démo `dynamic-poi-crud` (un
  /// seul à la fois — voir [DynamicPoiInfo]), ou `null` si aucun n'a encore
  /// été créé (ou si le dernier créé a été supprimé). Porté ici plutôt que
  /// par l'overlay de la feature, pour survivre à la fermeture du bottom
  /// sheet — même raison que [highlightedCategoryId] ci-dessus. C'est
  /// l'overlay (`DynamicPoiCrudOverlay`) qui met cette valeur à jour une
  /// fois qu'un aller-retour de pont confirme le succès de l'opération —
  /// pas ce contrôleur, qui ne fait qu'émettre la commande Native -> JS et
  /// laisser la réponse arriver de façon asynchrone sur [messages].
  final ValueNotifier<DynamicPoiInfo?> dynamicPoi = ValueNotifier<DynamicPoiInfo?>(null);

  /// Crée un POI à la volée (`venue.createPOI({id: newId})`, sans passer par
  /// VisioMapEditor) puis lui attache un label copiant la position d'un POI
  /// "ancre" existant ([anchorId]) — un POI fraîchement créé n'a par
  /// lui-même aucune représentation visuelle, voir
  /// `docs/features/dynamic-poi-crud.md`.
  ///
  /// Requête/réponse par `requestId` (même schéma que [loadCustomData]) : la
  /// réponse arrive de façon asynchrone sur [messages] sous la forme d'un
  /// message `dynamicPoiCreated` portant le même `requestId`, `success`, et
  /// si `success` est `false` un `message` expliquant l'échec — id déjà pris
  /// (`POIAlreadyExistsError`), ancre introuvable, ou ancre sans label/marker
  /// dont copier la position. Ces trois cas sont des états normaux de la
  /// démo à afficher tels quels, pas des exceptions à laisser remonter.
  Future<void> createDynamicPOI(
    String requestId, {
    required String newId,
    required String anchorId,
    required String labelText,
  }) => _call('createDynamicPOI', [requestId, newId, anchorId, labelText]);

  /// Modifie le texte du label attaché au POI dynamique actuellement suivi
  /// (`venue.updateLabel`) — la seule modification "visuelle" possible pour
  /// cette démo, `venue.updatePOI` ne pouvant toucher qu'aux catégories d'un
  /// POI (voir `docs/features/dynamic-poi-crud.md`).
  ///
  /// Requête/réponse par `requestId`, réponse en message
  /// `dynamicPoiLabelUpdated` (même schéma que [createDynamicPOI]).
  Future<void> updateDynamicPoiLabelText(String requestId, String text) =>
      _call('updateDynamicPoiLabelText', [requestId, text]);

  /// Supprime le POI dynamique actuellement suivi (`venue.removePOI`) — ce
  /// qui retire aussi son label de la carte, `removePOI` cascadant sur tout
  /// élément visuel attaché sans appel séparé (voir
  /// `docs/features/dynamic-poi-crud.md`).
  ///
  /// Requête/réponse par `requestId`, réponse en message `dynamicPoiRemoved`
  /// (même schéma que [createDynamicPOI]).
  Future<void> removeDynamicPOI(String requestId) => _call('removeDynamicPOI', [requestId]);

  /// Id du POI ancre sur lequel l'icône de la démo `3d-icon-marker` est
  /// actuellement placée, ou `null` si aucune icône n'est placée. Porté ici
  /// plutôt que par l'overlay de la feature, pour survivre à la fermeture du
  /// bottom sheet — même raison que [dynamicPoi] ci-dessus. Mis à jour par
  /// `IconMarkerOverlay` une fois l'aller-retour de pont confirmé.
  final ValueNotifier<String?> iconMarkerAnchorId = ValueNotifier<String?>(null);

  /// `OrientationType` du SDK choisi pour l'icône de `3d-icon-marker`
  /// (`'fixed'`, `'flat'` ou `'facing'`, défaut `'facing'`), conservé ici
  /// pour la même raison que [iconMarkerAnchorId].
  final ValueNotifier<String> iconMarkerOrientation = ValueNotifier<String>('facing');

  /// Place une image (icône) sur un POI existant ([anchorId], à la fois
  /// propriétaire et source de position, résolue comme pour
  /// [createDynamicPOI]) via `venue.createImage` — en retirant d'abord
  /// l'image déjà placée sous [imageId], le cas échéant. L'objet `Image` du
  /// SDK reste côté JS, indexé par [imageId]. [url] peut être une data URL.
  ///
  /// Requête/réponse par `requestId`, réponse en message `iconImagePlaced`
  /// (`success`, et sinon `error` = `'notFound'` / `'noPosition'` / `'sdk'`
  /// avec `message`, plus `previousRemoved`). Voir
  /// `docs/features/3d-icon-marker.md`.
  Future<void> placeIconImage(
    String requestId, {
    required String imageId,
    required String anchorId,
    required String url,
    required String orientationType,
  }) => _call('placeIconImage', [requestId, imageId, anchorId, url, orientationType]);

  /// Change l'`orientationType` d'une image déjà placée
  /// (`venue.updateImage(image, { orientationType })`), en direct. Réponse
  /// en message `iconImageUpdated` (même schéma que [placeIconImage]).
  Future<void> updateIconImageOrientation(String requestId, String imageId, String orientationType) =>
      _call('updateIconImageOrientation', [requestId, imageId, orientationType]);

  /// Retire une image placée par [placeIconImage] (`venue.removeImage`).
  /// Réponse en message `iconImageRemoved` (même schéma que [placeIconImage]).
  Future<void> removeIconImage(String requestId, String imageId) =>
      _call('removeIconImage', [requestId, imageId]);

  /// Id du POI ancre du label texte de la démo `custom-text-label`, ou
  /// `null` si aucun label n'est placé. Porté ici (comme les réglages
  /// ci-dessous) plutôt que par l'overlay, pour survivre à la fermeture du
  /// bottom sheet — même raison que [iconMarkerAnchorId].
  final ValueNotifier<String?> textLabelAnchorId = ValueNotifier<String?>(null);

  /// Dernier texte appliqué au label de `custom-text-label`.
  final ValueNotifier<String> textLabelText = ValueNotifier<String>('Lunch 12:00–14:00');

  /// Couleur (hex `#RRGGBB`) choisie pour le label de `custom-text-label`.
  final ValueNotifier<String> textLabelColor = ValueNotifier<String>('#E53935');

  /// Taille choisie pour le label de `custom-text-label` (`'small'`,
  /// `'medium'` ou `'large'`, traduite en width/height par l'overlay).
  final ValueNotifier<String> textLabelSize = ValueNotifier<String>('medium');

  /// Rotation (degrés) choisie pour le label de `custom-text-label`.
  final ValueNotifier<int> textLabelRotation = ValueNotifier<int>(0);

  /// Place un label texte (`venue.createLabel`) sur un POI existant
  /// ([anchorId], propriétaire et source de position — résolue comme pour
  /// [createDynamicPOI], puis décalée de ~4 m), en retirant d'abord le label
  /// déjà placé le cas échéant. [width]/[height] en mètres, toujours passés
  /// tous les deux ; [color] en hex ; [rotation] en degrés.
  ///
  /// Requête/réponse par `requestId`, réponse en message `textLabelPlaced`
  /// (`success`, et sinon `error` = `'textRequired'` / `'notFound'` /
  /// `'noPosition'` / `'sdk'` avec `message`, plus `previousRemoved`). Voir
  /// `docs/features/custom-text-label.md`.
  Future<void> placeTextLabel(
    String requestId, {
    required String anchorId,
    required String text,
    required String color,
    required double width,
    required double height,
    required int rotation,
  }) => _call('placeTextLabel', [requestId, anchorId, text, color, width, height, rotation]);

  /// `venue.updateLabel(label, changes)` sur le label placé, en direct.
  /// [changes] = `{text}`, `{color}` ou `{width, height}` (jamais `width`
  /// seul, jamais `rotation` — voir [rotateTextLabel]). Réponse en message
  /// `textLabelUpdated` (`error` = `'noLabel'` / `'textRequired'` / `'sdk'`).
  Future<void> updateTextLabel(String requestId, Map<String, Object> changes) =>
      _call('updateTextLabel', [requestId, changes]);

  /// Change la rotation du label placé : `rotation` n'étant pas dans
  /// `LabelUpdateOptions`, le côté JS retire puis recrée le label avec les
  /// mêmes valeurs. Réponse en message `textLabelUpdated`.
  Future<void> rotateTextLabel(String requestId, int rotation) =>
      _call('rotateTextLabel', [requestId, rotation]);

  /// Retire le label placé (`venue.removeLabel`). Réponse en message
  /// `textLabelRemoved` (`error: 'noLabel'` si aucun label n'est placé).
  Future<void> removeTextLabel(String requestId) => _call('removeTextLabel', [requestId]);

  /// Id du POI ancre du badge HTML de la démo `html-overlay-marker`, ou
  /// `null` si aucun badge n'est placé. Porté ici (comme les valeurs
  /// ci-dessous) plutôt que par l'overlay, pour survivre à la fermeture du
  /// bottom sheet — même raison que [textLabelAnchorId].
  final ValueNotifier<String?> htmlBadgeAnchorId = ValueNotifier<String?>(null);

  /// Dernier texte appliqué au badge de `html-overlay-marker`.
  final ValueNotifier<String> htmlBadgeText = ValueNotifier<String>('Open now · 12:00–14:00');

  /// Visibilité du badge placé (`venue.updateMarker(marker, { isVisible })`).
  final ValueNotifier<bool> htmlBadgeVisible = ValueNotifier<bool>(true);

  /// Nombre de taps sur le badge placé, remis à 0 à chaque placement réussi.
  /// Mis à jour ici, dans [_handleRawMessage], à chaque message
  /// `htmlBadgeTapped` (`{count}`) : le tap arrive alors que le bottom sheet
  /// (modal) est fermé, donc sans overlay monté pour l'écouter.
  final ValueNotifier<int> htmlBadgeTapCount = ValueNotifier<int>(0);

  /// Épingle un badge HTML (`venue.createMarker({ poi, position, element })`,
  /// élément DOM créé côté JS) sur un POI existant ([anchorId], propriétaire
  /// et source de position — résolue comme pour [createDynamicPOI], puis
  /// décalée de ~4 m), en retirant d'abord le badge déjà placé le cas
  /// échéant. Un tap sur le badge remonte en message `htmlBadgeTapped`.
  ///
  /// Requête/réponse par `requestId`, réponse en message `htmlBadgePlaced`
  /// (`success`, et sinon `error` = `'textRequired'` / `'notFound'` /
  /// `'noPosition'` / `'sdk'` avec `message`, plus `previousRemoved`). Voir
  /// `docs/features/html-overlay-marker.md`.
  Future<void> placeHtmlBadge(String requestId, {required String anchorId, required String text}) =>
      _call('placeHtmlBadge', [requestId, anchorId, text]);

  /// Change le texte du badge placé (édition DOM de `marker.element`, aucun
  /// appel SDK). Réponse en message `htmlBadgeUpdated` (`error` =
  /// `'noBadge'` / `'textRequired'`).
  Future<void> updateHtmlBadgeText(String requestId, String text) =>
      _call('updateHtmlBadgeText', [requestId, text]);

  /// Affiche/masque le badge placé (`venue.updateMarker(marker, { isVisible })`).
  /// Réponse en message `htmlBadgeUpdated` (`error` = `'noBadge'` / `'sdk'`).
  Future<void> setHtmlBadgeVisible(String requestId, bool visible) =>
      _call('setHtmlBadgeVisible', [requestId, visible]);

  /// Retire le badge placé (`venue.removeMarker`). Réponse en message
  /// `htmlBadgeRemoved` (`error: 'noBadge'` si aucun badge n'est placé).
  Future<void> removeHtmlBadge(String requestId) => _call('removeHtmlBadge', [requestId]);

  /// Locale actuellement affichée par la venue (code brut renvoyé par
  /// `venue.currentLocale`, ex. `'default'`/`'en'`/`'fr'`), ou `null` tant
  /// qu'aucune réponse `localesLoaded` n'a encore été reçue.
  ///
  /// Portée ici plutôt que par l'overlay de la feature, pour survivre à la
  /// fermeture du bottom sheet — même raison que [highlightedCategoryId]
  /// ci-dessus : sans ça, rouvrir le panneau perdrait la trace de la locale
  /// choisie lors d'un passage précédent tant que [getLocales] n'a pas
  /// répondu à nouveau. Voir `docs/features/runtime-locale.md`.
  final ValueNotifier<String?> currentLocale = ValueNotifier<String?>(null);

  /// Demande la locale courante et la liste des locales disponibles de la
  /// venue (`venue.currentLocale` / `venue.translator.allLocales`).
  ///
  /// Fire-and-forget comme [getCategories]/[getVenueLayout] : la réponse
  /// arrive de façon asynchrone sur [messages] sous la forme d'un message
  /// `localesLoaded` portant le même `requestId`, `currentLocale` et
  /// `allLocales`. Voir `docs/features/runtime-locale.md`.
  Future<void> getLocales(String requestId) => _call('getLocales', [requestId]);

  /// Change la locale courante de la venue (`venue.setCurrentLocale`) : le
  /// SDK se charge lui-même de re-rendre les labels de POI et l'UI courante
  /// dans la nouvelle locale, aucun re-fetch manuel des données POI n'est
  /// nécessaire côté natif — voir `docs/features/runtime-locale.md`.
  ///
  /// Met à jour [currentLocale] immédiatement (avant même que la `Promise`
  /// JS sous-jacente ne se résolve) plutôt que d'attendre un message de
  /// confirmation dédié : il n'y en a pas, le résultat étant directement
  /// observable sur la carte (voir `assets/www/map.html`,
  /// `window.MapBridge.setCurrentLocale`).
  Future<void> setCurrentLocale(String locale) {
    currentLocale.value = locale;
    return _call('setCurrentLocale', [locale]);
  }

  /// Valeurs traduites en espagnol de la démo `add-locale` (une entrée par
  /// clé de `AddLocaleOverlay.kSpanishResources`), ou `null` tant que
  /// [addSpanishLocale] n'a pas encore été appelé avec succès.
  ///
  /// Portée ici plutôt que par l'overlay de la feature, pour survivre à la
  /// fermeture du bottom sheet — même raison que [currentLocale] ci-dessus :
  /// `venue.translator.addLocale` a déjà pris effet côté SDK dès le premier
  /// appel (l'ajout d'une locale à l'exécution n'a rien d'idempotent à
  /// répéter), donc rouvrir le panneau doit continuer à afficher l'état
  /// "ajoutée", pas revenir à "(not added yet)". Voir
  /// `docs/features/add-locale.md`.
  final ValueNotifier<Map<String, String>?> spanishLocaleTranslations =
      ValueNotifier<Map<String, String>?>(null);

  /// Ajoute la locale `'es'` à l'exécution avec le dictionnaire fixe
  /// [resources] (`venue.translator.addLocale('es', resources)`), puis relit
  /// immédiatement chaque clé traduite (`venue.translator.translate(key,
  /// 'es')`) dans le même aller-retour de pont — même idiome que
  /// [loadCustomData] (`refreshCustomData` + `getPOICustomData` enchaînés
  /// côté JS plutôt que deux commandes séparées).
  ///
  /// Requête/réponse par `requestId` (même schéma que [loadCustomData]) : la
  /// réponse arrive de façon asynchrone sur [messages] sous la forme d'un
  /// message `spanishLocaleAdded` portant le même `requestId` et `values`
  /// (une entrée par clé de [resources], chacune déjà traduite en espagnol) —
  /// c'est la preuve que l'aller-retour `addLocale`/`translate` a fonctionné,
  /// indépendamment de la visibilité de l'UI native du SDK. Voir
  /// `docs/features/add-locale.md`.
  Future<void> addSpanishLocale(String requestId, Map<String, String> resources) =>
      _call('addSpanishLocale', [requestId, resources]);

  /// Thème de scène 3D par défaut du SDK (`view.setTheme`), et réglages
  /// d'accent par défaut de la démo `custom-theme` (bleu Visioglobe / blanc).
  static const String kDefaultTheme = 'day';
  static const String kDefaultAccentColor = '#0094F0';
  static const String kDefaultTextAccentColor = '#FFFFFF';

  /// Ids des thèmes de scène 3D enregistrés (`view.themes`), ou `null` tant
  /// que [getThemes] n'a pas répondu. Mis à jour ici, dans
  /// [_handleRawMessage], à chaque message `themesLoaded`.
  final ValueNotifier<List<String>?> themes = ValueNotifier<List<String>?>(null);

  /// Thème appliqué par la démo `custom-theme` — suivi côté app : le SDK
  /// (1.1.0 inclus) n'a pas de getter du thème courant. Porté ici (comme les couleurs
  /// ci-dessous) pour survivre à la fermeture du bottom sheet.
  final ValueNotifier<String> currentTheme = ValueNotifier<String>(kDefaultTheme);

  /// `view.accentColor` appliqué par la démo `custom-theme`.
  final ValueNotifier<String> accentColor = ValueNotifier<String>(kDefaultAccentColor);

  /// `view.textAccentColor` appliqué par la démo `custom-theme`.
  final ValueNotifier<String> textAccentColor = ValueNotifier<String>(kDefaultTextAccentColor);

  /// Demande la liste des thèmes enregistrés (`view.themes`). Réponse en
  /// message `themesLoaded` (`{requestId, themes}`), aussi reflétée dans
  /// [themes]. Voir `docs/features/custom-theme.md`.
  Future<void> getThemes(String requestId) => _call('getThemes', [requestId]);

  /// `view.setTheme(name)` — [name] doit venir de [themes] (le SDK lève
  /// sinon). Réponse en message `themeApplied` (`{success, theme, message?}`).
  Future<void> setTheme(String name) {
    currentTheme.value = name;
    return _call('setTheme', [name]);
  }

  /// `view.accentColor = accent; view.textAccentColor = textAccent` (hex,
  /// rgba ou hsl). Réponse en message `accentColorsApplied`.
  Future<void> setAccentColors({required String accent, required String textAccent}) {
    accentColor.value = accent;
    textAccentColor.value = textAccent;
    return _call('setAccentColors', [accent, textAccent]);
  }

  /// Projection caméra de la vue courante, telle que rapportée par le SDK
  /// (`view.cameraProjection`, en lecture seule : `'perspective'` ou
  /// `'orthographic'`), ou `null` pendant un (re)chargement de la carte.
  /// Mis à jour ici, dans [_handleRawMessage], à chaque message `loading`
  /// (-> `null`) et `ready` (-> valeur du SDK). Voir
  /// `docs/features/camera-projection-toggle.md`.
  final ValueNotifier<String?> cameraProjection = ValueNotifier<String?>(null);

  /// Recrée la carte avec `createView(..., { cameraProjection: projection })`.
  ///
  /// `cameraProjection` n'est qu'une option de création de vue (aucun
  /// setter) : côté JS, `MapBridge.setCameraProjection` rejoue tout [setup]
  /// (destroyView -> unloadVenue -> loadVenue -> createView) avec les mêmes
  /// hash/baseURL/options de vue. Réponse : `loading`, puis `ready`
  /// (`{cameraProjection}`, reflété dans [cameraProjection]) ou `error`.
  Future<void> setCameraProjection(String projection) =>
      _call('setCameraProjection', [projection]);

  Future<void> _call(String method, List<Object?> args) {
    final encodedArgs = args.map(jsonEncode).join(', ');
    return _run('window.MapBridge.$method($encodedArgs)');
  }

  Future<void> _run(String script) async {
    try {
      await _webViewController.runJavaScript(script);
    } catch (error) {
      // Une commande Native -> JS ratée (carte pas encore prête, méthode
      // absente...) ne doit jamais faire planter l'app : on trace et on
      // laisse l'appelant continuer.
      debugPrint('VisioOneController: échec JS "$script" ($error)');
    }
  }

  void _handleRawMessage(JavaScriptMessage message) {
    final parsed = VisioOneMessage.tryParse(message.message);
    if (parsed == null) {
      debugPrint('VisioOneController: message JS illisible: ${message.message}');
      return;
    }
    if (parsed.type == 'loading') cameraProjection.value = null;
    if (parsed.type == 'ready') {
      final projection = parsed.data is Map ? (parsed.data as Map)['cameraProjection'] : null;
      cameraProjection.value = projection is String ? projection : null;
    }
    if (parsed.type == 'themesLoaded') {
      final list = parsed.data is Map ? (parsed.data as Map)['themes'] : null;
      if (list is List) themes.value = list.whereType<String>().toList();
    }
    if (parsed.type == 'cameraLockChanged') {
      final locked = parsed.data is Map ? (parsed.data as Map)['locked'] : null;
      if (locked is bool) simulatedPosition.onCameraLockChanged(locked);
    }
    if (parsed.type == 'htmlBadgeTapped') {
      final count = parsed.data is Map ? (parsed.data as Map)['count'] : null;
      if (count is int) htmlBadgeTapCount.value = count;
    }
    _messages.add(parsed);
  }

  /// Libère les ressources. À appeler depuis `dispose()` du widget hôte.
  void dispose() {
    simulatedPosition.dispose();
    highlightedCategoryId.dispose();
    selectedNavigationTracePresetKey.dispose();
    dynamicPoi.dispose();
    iconMarkerAnchorId.dispose();
    iconMarkerOrientation.dispose();
    textLabelAnchorId.dispose();
    textLabelText.dispose();
    textLabelColor.dispose();
    textLabelSize.dispose();
    textLabelRotation.dispose();
    htmlBadgeAnchorId.dispose();
    htmlBadgeText.dispose();
    htmlBadgeVisible.dispose();
    htmlBadgeTapCount.dispose();
    currentLocale.dispose();
    spanishLocaleTranslations.dispose();
    themes.dispose();
    currentTheme.dispose();
    accentColor.dispose();
    textAccentColor.dispose();
    cameraProjection.dispose();
    _messages.close();
  }
}
