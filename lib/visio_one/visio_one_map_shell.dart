import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'visio_one_controller.dart';
import 'visio_one_message.dart';

/// Hash de démo (41 caractères) — même carte que celle utilisée par défaut
/// dans VisioOneMeetAndroid et VisioOneMeetIos, pour vérifier facilement
/// que l'intégration fonctionne avant de brancher sa propre carte.
///
/// Voir docs/INTEGRATION_GUIDE.md, partie D, pour obtenir le hash de VOTRE
/// carte depuis my.visioglobe.com.
const String kDefaultMapHash = 'kbae8e6c066cca4b02c2afac2bc963a643d87437a';

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
  const VisioOneMapShell({super.key, required this.hash, required this.overlayBuilder});

  /// Hash à 41 caractères d'une carte publiée sur my.visioglobe.com.
  final String hash;

  /// Construit l'overlay spécifique à la feature une fois la carte prête.
  final Widget Function(BuildContext context, VisioOneController controller) overlayBuilder;

  @override
  State<VisioOneMapShell> createState() => _VisioOneMapShellState();
}

class _VisioOneMapShellState extends State<VisioOneMapShell> {
  VisioOneController? _controller;
  _MapLoadState _state = _MapLoadState.loading;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final controller = await VisioOneController.create();
    controller.messages.listen(_onMessage);
    await controller.webViewController.setNavigationDelegate(
      NavigationDelegate(onPageFinished: (_) => controller.setup(widget.hash)),
    );
    await controller.loadMapPage();

    if (!mounted) {
      controller.dispose();
      return;
    }
    setState(() => _controller = controller);
  }

  void _onMessage(VisioOneMessage message) {
    switch (message.type) {
      case 'ready':
        setState(() => _state = _MapLoadState.ready);
      case 'error':
        final data = message.data;
        final text = data is Map ? data['message'] as String? : null;
        setState(() {
          _state = _MapLoadState.error;
          _errorMessage = text ?? 'Erreur inconnue du SDK VisioOne';
        });
      default:
        // Les autres types (poiSelected, floorChanged, itineraryComputed...)
        // sont à router vers l'UI native de l'app hôte. Rien à faire ici
        // dans ce squelette d'intégration.
        break;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() {
      _state = _MapLoadState.loading;
      _errorMessage = null;
    });
    _controller?.setup(widget.hash);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        children: [
          if (controller != null) WebViewWidget(controller: controller.webViewController),
          if (_state == _MapLoadState.loading)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          if (_state == _MapLoadState.error) _ErrorOverlay(message: _errorMessage!, onRetry: _retry),
          if (controller != null && _state == _MapLoadState.ready)
            _FeatureBottomSheet(child: widget.overlayBuilder(context, controller)),
        ],
      ),
    );
  }
}

/// Bottom sheet persistant et rétractable (jamais totalement caché,
/// `minChildSize` = `initialChildSize`) qui héberge le contrôle de la feature
/// courante, à la place de l'ancien overlay flottant par-dessus la carte.
class _FeatureBottomSheet extends StatelessWidget {
  const _FeatureBottomSheet({required this.child});

  final Widget child;

  static const double _peekSize = 0.16;
  static const double _expandedSize = 0.45;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: _peekSize,
      minChildSize: _peekSize,
      maxChildSize: _expandedSize,
      snap: true,
      snapSizes: const [_peekSize, _expandedSize],
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: child),
            ],
          ),
        );
      },
    );
  }
}

class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
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
                'Impossible de charger la carte VisioOne\n$message',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
            ],
          ),
        ),
      ),
    );
  }
}
