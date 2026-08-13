import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

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
  VisioOneController._(this._webViewController);

  final WebViewController _webViewController;
  final StreamController<VisioOneMessage> _messages =
      StreamController<VisioOneMessage>.broadcast();

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
    _messages.close();
  }
}
