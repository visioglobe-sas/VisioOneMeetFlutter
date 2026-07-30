import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'visio_one_controller.dart';
import 'visio_one_message.dart';

enum _MapLoadState { loading, ready, error }

/// Écran plein écran affichant une carte VisioOne pour le hash donné.
///
/// Cycle de vie (voir docs/COMMUNICATION_GUIDE.md pour le détail) :
/// 1. [VisioOneController.create] configure la WebView (JS, canal, debug).
/// 2. [VisioOneController.loadMapPage] charge `assets/www/map.html`.
/// 3. `onPageFinished` déclenche [VisioOneController.setup] avec [hash].
/// 4. Le message JS `ready`/`error` fait sortir l'écran de l'état "loading".
class VisioOneMapScreen extends StatefulWidget {
  const VisioOneMapScreen({super.key, required this.hash});

  /// Hash à 41 caractères d'une carte publiée sur my.visioglobe.com.
  final String hash;

  @override
  State<VisioOneMapScreen> createState() => _VisioOneMapScreenState();
}

class _VisioOneMapScreenState extends State<VisioOneMapScreen> {
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
        ],
      ),
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
