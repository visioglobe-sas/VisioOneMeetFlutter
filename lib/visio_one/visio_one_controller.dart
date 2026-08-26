import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'simulated_position_session.dart';
import 'visio_one_message.dart';

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
    _messages.close();
  }
}
