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
  Future<void> setup(String hash) => _call('setup', [hash]);

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
  /// `docs/features/camera-lock-on-position.md`.
  Future<void> setCameraLockOnPosition(bool locked) =>
      _call('setCameraLockOnPosition', [locked]);

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
    _messages.add(parsed);
  }

  /// Libère les ressources. À appeler depuis `dispose()` du widget hôte.
  void dispose() {
    simulatedPosition.dispose();
    highlightedCategoryId.dispose();
    dynamicPoi.dispose();
    currentLocale.dispose();
    _messages.close();
  }
}
