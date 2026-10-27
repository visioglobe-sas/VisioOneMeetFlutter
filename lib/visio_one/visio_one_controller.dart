import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'feature_session.dart';
import 'panel_state.dart';
import 'visio_one_message.dart';

/// Nom du `JavaScriptChannel` exposé à la page `assets/www/map.html` (`window.VisioOneBridge`).
///
/// Un seul canal JS -> Native, avec une enveloppe `{type, data}` (voir
/// [VisioOneMessage]) plutôt qu'un canal par événement : garde la surface
/// de pont minimale (voir `docs/COMMUNICATION_GUIDE.md`).
const String kVisioOneBridgeChannel = 'VisioOneBridge';

/// Pont typé Native <-> SDK VisioOne (exécuté en JS dans la WebView).
///
/// Ce fichier ne contient que le cœur du pont, commun à toutes les features :
/// - **Native -> JS** : [send] (commande sans réponse) et [request]
///   (commande + réponse corrélée par `requestId`), qui appellent
///   `window.MapBridge.<methode>(...)` via [WebViewController.runJavaScript].
///   Chaque argument est encodé en JSON ([jsonEncode]) avant interpolation
///   dans le script — jamais de concaténation de texte brut, pour éviter
///   toute injection JS (voir `docs/COMMUNICATION_GUIDE.md`). Seule
///   [setup] (chargement de la carte) est définie ici.
/// - **JS -> Native** : un seul [JavaScriptChannel] ([kVisioOneBridgeChannel]),
///   exposé en flux typé via [messages].
///
/// Les commandes de chaque feature sont des extensions de cette classe,
/// rangées avec la feature : `lib/features/<slug>/<feature>_bridge.dart`
/// (ex. `GotoPoiBridge.goToPOI`), et leur JS dans
/// `assets/www/features/<slug>.js`. L'état qui doit survivre à la fermeture
/// du panneau vit dans [panel] (valeurs de formulaire) ou dans la
/// [FeatureSession] de l'écran ([attachSession]).
class VisioOneController {
  VisioOneController._(this._webViewController);

  final WebViewController _webViewController;
  final StreamController<VisioOneMessage> _messages =
      StreamController<VisioOneMessage>.broadcast();

  /// Valeurs saisies dans le panneau de la feature (champs, interrupteurs,
  /// derniers résultats), conservées entre deux ouvertures du bottom sheet.
  final PanelState panel = PanelState();

  /// État de la feature affichée qui doit vivre aussi longtemps que l'écran
  /// (boucle, minuteur, miroir d'un état SDK), voir [attachSession].
  FeatureSession? _session;

  /// Requêtes en attente de réponse ([request]), par `requestId`.
  final Map<String, Completer<Map<String, Object?>?>> _pending = {};
  int _requestCounter = 0;

  bool _disposed = false;

  /// Délai au-delà duquel [request] abandonne et renvoie `null`.
  static const Duration kRequestTimeout = Duration(seconds: 5);

  /// Attache la session de la feature affichée (une seule par écran), créée
  /// par `VisioOneMapShell` juste après ce contrôleur, avant le chargement
  /// de la carte : elle reçoit donc tous les messages, y compris le premier
  /// `ready`, et survit à la fermeture du panneau. Libérée par [dispose].
  void attachSession(FeatureSession session) {
    assert(_session == null, 'une seule session par écran');
    _session = session;
  }

  /// Session attachée par [attachSession], du type attendu par la feature.
  T session<T extends FeatureSession>() => _session! as T;

  /// Commande Native -> JS sans réponse : `window.MapBridge.<method>(...)`,
  /// chaque argument encodé en JSON ([jsonEncode]) — jamais de
  /// concaténation de texte brut (voir `docs/COMMUNICATION_GUIDE.md`).
  Future<void> send(String method, [List<Object?> args = const []]) {
    final encodedArgs = args.map(jsonEncode).join(', ');
    return _run('window.MapBridge.$method($encodedArgs)');
  }

  /// Commande Native -> JS avec réponse : appelle
  /// `window.MapBridge.<method>(requestId, ...args)` et attend le message JS
  /// -> Native qui renvoie ce même `requestId` (quel que soit son `type`),
  /// dont il rend les `data`. Renvoie `null` si aucune réponse n'arrive dans
  /// [timeout]. Après [dispose], la future ne se termine jamais : le code
  /// qui l'attend (souvent un panneau fermé entre-temps) ne s'exécute pas
  /// sur un écran détruit.
  Future<Map<String, Object?>?> request(
    String method, [
    List<Object?> args = const [],
    Duration timeout = kRequestTimeout,
  ]) {
    final requestId = '$method-${_requestCounter++}';
    final completer = Completer<Map<String, Object?>?>();
    _pending[requestId] = completer;
    Timer(timeout, () {
      if (_disposed) return;
      if (_pending.remove(requestId) != null) completer.complete(null);
    });
    send(method, [requestId, ...args]);
    return completer.future;
  }

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

  /// Charge la page hôte bundlée (`assets/www/map.html` et ses scripts
  /// `bridge/` + `features/`, référencés dans `pubspec.yaml`). Le SDK VisioOne lui-même n'est initialisé qu'à l'appel
  /// de [setup], déclenché depuis `onPageFinished` par `VisioOneMapShell`.
  Future<void> loadMapPage() {
    return _webViewController.loadFlutterAsset('assets/www/map.html');
  }

  /// Initialise (ou réinitialise) la carte pour le hash donné.
  ///
  /// `hash` est la chaîne de 41 caractères identifiant une carte publiée
  /// sur my.visioglobe.com (voir le README, « Configure your own map »).
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
  ///
  /// `authorizationToken` (`null` par défaut) : jeton d'autorisation d'une
  /// carte protégée (`LoadOptions.authorizationToken`, envoyé par le SDK en
  /// `Authorization: Bearer <token>`), seul le code d'exemple `auth-token` le
  /// renseigne — voir `lib/features/auth_token_sample.dart`. Un jeton
  /// invalide, expiré ou absent répond `error` avec `unauthorized: true`
  /// (voir [isUnauthorizedError]).
  Future<void> setup(
    String hash, {
    String? baseURL,
    Map<String, Object>? viewOptions,
    String? authorizationToken,
  }) => send('setup', [hash, baseURL, viewOptions, authorizationToken]);

  /// `true` si [message] est un `error` dû à un jeton d'autorisation
  /// invalide, expiré ou absent (`UnauthorizedError` du SDK), par opposition
  /// aux autres échecs de chargement.
  static bool isUnauthorizedError(VisioOneMessage message) {
    final data = message.data;
    return message.type == 'error' && data is Map && data['unauthorized'] == true;
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
    // Un dernier message peut encore arriver de la WebView pendant la
    // destruction de l'écran : les notifiers sont alors déjà libérés.
    if (_disposed) return;
    final parsed = VisioOneMessage.tryParse(message.message);
    if (parsed == null) {
      debugPrint('VisioOneController: message JS illisible: ${message.message}');
      return;
    }
    final data = parsed.data;
    if (data is Map && data['requestId'] is String) {
      final completer = _pending.remove(data['requestId']);
      completer?.complete(data.map((key, value) => MapEntry(key.toString(), value)));
    }
    _messages.add(parsed);
  }

  /// Libère les ressources. À appeler depuis `dispose()` du widget hôte.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _pending.clear();
    _session?.dispose();
    panel.dispose();
    _messages.close();
  }
}
