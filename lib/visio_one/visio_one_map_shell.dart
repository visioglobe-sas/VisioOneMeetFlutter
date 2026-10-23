import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../l10n/app_localizations.dart';

import 'visio_one_controller.dart';
import 'visio_one_message.dart';

/// Défaut public du SDK pour `LoadOptions.baseURL` quand l'app ne le
/// renseigne pas explicitement (voir `docs/features/custom-base-url.md`) —
/// affiché comme valeur pré-remplie par cette démo, jamais codé en dur
/// ailleurs dans l'app : les autres features laissent `baseURL` à `null` et
/// s'appuient sur ce même défaut côté SDK.
const String kDefaultMapServerBaseUrl = 'https://mapserver.visioglobe.com/';

enum _MapLoadState { loading, ready, error }

/// Coquille partagée par tous les écrans de feature : charge la carte
/// VisioOne pour [hash] et affiche [overlayBuilder] par-dessus une fois la
/// carte prête, tout en gérant elle-même le cycle de vie du
/// [VisioOneController] et les états loading/error.
///
/// Cycle de vie (voir docs/COMMUNICATION_GUIDE.md pour le détail) :
/// 1. [VisioOneController.create] configure la WebView (JS, canal, debug).
/// 2. [VisioOneController.loadMapPage] charge `assets/www/map.html`.
/// 3. `onPageFinished` déclenche [VisioOneController.setup] avec [hash].
/// 4. Le message JS `ready`/`error` fait sortir l'écran de l'état "loading".
class VisioOneMapShell extends StatefulWidget {
  const VisioOneMapShell({
    super.key,
    required this.hash,
    this.baseURL,
    this.viewOptions,
    this.authorizationToken,
    required this.overlayBuilder,
    this.mapOverlayBuilder,
    this.onMessage,
    this.showControlsOnError = false,
  });

  /// Hash à 41 caractères d'une carte publiée sur my.visioglobe.com.
  final String hash;

  /// Serveur de cartes à interroger (`LoadOptions.baseURL`), ou `null` pour
  /// le défaut public du SDK (`https://mapserver.visioglobe.com/`) — voir
  /// `docs/features/custom-base-url.md`. Seule cette démo le renseigne ;
  /// toutes les autres features laissent `null`. Changer cette valeur ne
  /// suffit pas à recharger une instance déjà montée : [FeatureScreen] lui
  /// donne une `Key` dérivée de `baseURL` pour forcer un remount complet
  /// (même mécanisme qu'un changement de [hash] aurait exigé).
  final String? baseURL;

  /// Options passées en 3e argument de `createView` (`null` = aucune, le
  /// défaut du SDK). Seule `custom-theme` le renseigne
  /// (`{'enableShadows': true}`) ; toutes les autres features laissent `null`.
  final Map<String, Object>? viewOptions;

  /// Jeton d'autorisation d'une carte protégée (`LoadOptions.authorizationToken`),
  /// ou `null` (carte publique, cas de toutes les features). Seul le code
  /// d'exemple `auth-token` le renseigne — voir
  /// `lib/features/auth_token_sample.dart` et `docs/features/auth-token.md`.
  final String? authorizationToken;

  /// Construit l'overlay spécifique à la feature une fois la carte prête.
  final Widget Function(BuildContext context, VisioOneController controller) overlayBuilder;

  /// Overlay optionnel affiché directement au-dessus de la carte (pas dans le
  /// bottom sheet ouvert par le FAB) une fois celle-ci prête. Peut renvoyer
  /// `null` (aucun overlay pour la feature affichée) même quand ce champ
  /// lui-même n'est pas `null` — [FeatureScreen] branche toujours
  /// `Feature.buildMapOverlay`, qui ne renvoie un widget que pour
  /// `native-ui-replacement`, pour que son sélecteur d'étage natif soit
  /// visible sans action du visiteur — voir
  /// `lib/features/native_ui_replacement_overlay.dart`.
  final Widget? Function(BuildContext context, VisioOneController controller)? mapOverlayBuilder;

  /// Callback optionnel pour les messages JS -> Native que ce squelette
  /// partagé ne gère pas lui-même (tout sauf `ready`/`error`, ex.
  /// `poiSelected`, `floorChanged`...). Laissé à `null` par défaut : seule la
  /// feature concernée (ex. `poi-click`) le renseigne, pour ne pas faire
  /// réagir les autres écrans de feature à un événement qui ne les concerne
  /// pas alors que `map.html` émet les mêmes événements sur toutes les cartes.
  final void Function(BuildContext context, VisioOneMessage message)? onMessage;

  /// `true` pour garder le FAB accessible même en état d'erreur, en plus de
  /// l'état "prête" habituel. Seule `custom-base-url` en a besoin : sans
  /// ça, une `baseURL` invalide ferait échouer le chargement et masquerait
  /// le seul moyen d'en taper une nouvelle (le FAB n'ouvre le panneau que si
  /// la carte est "ready" par défaut) -- le bouton "Retry" de l'état
  /// d'erreur, lui, ne fait que rejouer la même valeur. Voir
  /// `docs/features/custom-base-url.md`.
  final bool showControlsOnError;

  @override
  State<VisioOneMapShell> createState() => _VisioOneMapShellState();
}

class _VisioOneMapShellState extends State<VisioOneMapShell> {
  VisioOneController? _controller;
  StreamSubscription<VisioOneMessage>? _subscription;
  _MapLoadState _state = _MapLoadState.loading;
  // Message brut du SDK (non traduit), `null` s'il n'en a fourni aucun.
  String? _errorDetail;
  bool _unauthorized = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final controller = await VisioOneController.create();
    if (!mounted) {
      controller.dispose();
      return;
    }
    _subscription = controller.messages.listen(_onMessage);
    await controller.webViewController.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (_) => controller.setup(
          widget.hash,
          baseURL: widget.baseURL,
          viewOptions: widget.viewOptions,
          authorizationToken: widget.authorizationToken,
        ),
      ),
    );
    await controller.loadMapPage();

    if (!mounted) {
      _subscription?.cancel();
      controller.dispose();
      return;
    }
    setState(() => _controller = controller);
  }

  void _onMessage(VisioOneMessage message) {
    // Un message tardif peut arriver pendant la destruction de l'écran.
    if (!mounted) return;
    switch (message.type) {
      case 'loading':
        // Émis au début de chaque `setup` JS, y compris un rechargement
        // déclenché depuis la carte déjà prête (`camera-projection-toggle`
        // recrée la vue sans remonter ce shell) : on repasse en "loading"
        // pour masquer le FAB et afficher le spinner jusqu'au `ready` suivant.
        if (_state != _MapLoadState.loading) setState(() => _state = _MapLoadState.loading);
      case 'ready':
        setState(() => _state = _MapLoadState.ready);
      case 'error':
        final data = message.data;
        // `UnauthorizedError` du SDK (carte protégée, code d'exemple
        // `auth-token`) : signalé distinctement des autres échecs de chargement.
        final unauthorized = VisioOneController.isUnauthorizedError(message);
        if (unauthorized) debugPrint('VisioOneMapShell: UnauthorizedError');
        setState(() {
          _state = _MapLoadState.error;
          _errorDetail = data is Map ? data['message'] as String? : null;
          _unauthorized = unauthorized;
        });
      default:
        // Les autres types (poiSelected, floorChanged, itineraryComputed...)
        // sont routés vers l'UI native de l'app hôte via [onMessage], propre
        // à la feature affichée (voir `lib/features/poi_click_overlay.dart`
        // pour `poiSelected`) — ce squelette partagé n'a pas à les connaître
        // individuellement.
        widget.onMessage?.call(context, message);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() {
      _state = _MapLoadState.loading;
      _errorDetail = null;
      _unauthorized = false;
    });
    _controller?.setup(
      widget.hash,
      baseURL: widget.baseURL,
      viewOptions: widget.viewOptions,
      authorizationToken: widget.authorizationToken,
    );
  }

  void _showFeatureControls(BuildContext context, VisioOneController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      // Hauteur selon le contenu (jusqu'au plein écran, pas plafonnée à 9/16)
      // et remontée au-dessus du clavier ; le contenu défile s'il dépasse.
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: widget.overlayBuilder(sheetContext, controller),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final mapOverlay = controller != null && _state == _MapLoadState.ready
        ? widget.mapOverlayBuilder?.call(context, controller)
        : null;
    return Scaffold(
      body: ColoredBox(
        color: Colors.black,
        child: Stack(
          children: [
            if (controller != null) WebViewWidget(controller: controller.webViewController),
            ?mapOverlay,
            if (_state == _MapLoadState.loading)
              const Center(child: CircularProgressIndicator(color: Colors.white)),
            if (_state == _MapLoadState.error)
              _ErrorOverlay(detail: _errorDetail, unauthorized: _unauthorized, onRetry: _retry),
          ],
        ),
      ),
      floatingActionButton:
          controller != null &&
              (_state == _MapLoadState.ready ||
                  (widget.showControlsOnError && _state == _MapLoadState.error))
          ? FloatingActionButton(
              onPressed: () => _showFeatureControls(context, controller),
              child: const Icon(Icons.tune),
            )
          : null,
    );
  }
}

class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({required this.detail, required this.unauthorized, required this.onRetry});

  final String? detail;
  final bool unauthorized;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lines = [
      l10n.mapLoadErrorTitle,
      if (unauthorized) l10n.authTokenUnauthorizedError,
      detail ?? l10n.mapLoadErrorUnknown,
    ];
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 12),
              Text(
                lines.join('\n'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: Text(l10n.mapLoadErrorRetry)),
            ],
          ),
        ),
      ),
    );
  }
}
