import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'visio_one_controller.dart';
import 'visio_one_message.dart';

enum _MapLoadState { loading, ready, error }

// Stand-in for a real occupancy sensor feed: cycles a POI's surface through
// these colors on a timer. See docs/features/occupancy-simulated.md.
const List<String> _occupancyColors = ['#2ECC71', '#F1C40F', '#E74C3C'];
const Duration _occupancyInterval = Duration(milliseconds: 2500);

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

  final TextEditingController _placeIdController = TextEditingController();
  Timer? _occupancyTimer;
  bool _simulateOccupancy = false;
  int _occupancyColorIndex = 0;

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
    _occupancyTimer?.cancel();
    _placeIdController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _toggleOccupancySimulation() {
    if (_simulateOccupancy) {
      _stopOccupancySimulation();
    } else {
      _startOccupancySimulation();
    }
  }

  void _startOccupancySimulation() {
    final placeId = _placeIdController.text.trim();
    final controller = _controller;
    if (placeId.isEmpty || controller == null) return;

    setState(() => _simulateOccupancy = true);
    _occupancyColorIndex = 0;
    controller.updateOccupancy([
      {'planId': placeId, 'color': _occupancyColors[_occupancyColorIndex]},
    ]);
    _occupancyTimer = Timer.periodic(_occupancyInterval, (_) {
      _occupancyColorIndex = (_occupancyColorIndex + 1) % _occupancyColors.length;
      controller.updateOccupancy([
        {'planId': placeId, 'color': _occupancyColors[_occupancyColorIndex]},
      ]);
    });
  }

  void _stopOccupancySimulation() {
    _occupancyTimer?.cancel();
    _occupancyTimer = null;
    final placeId = _placeIdController.text.trim();
    if (placeId.isNotEmpty) {
      // Reset the surface rather than leaving it stuck on the last simulated color.
      _controller?.updateOccupancy([{'planId': placeId, 'color': null}]);
    }
    setState(() => _simulateOccupancy = false);
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
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _OccupancySimulationPanel(
                placeIdController: _placeIdController,
                simulating: _simulateOccupancy,
                onToggle: _toggleOccupancySimulation,
              ),
            ),
        ],
      ),
    );
  }
}

class _OccupancySimulationPanel extends StatelessWidget {
  const _OccupancySimulationPanel({
    required this.placeIdController,
    required this.simulating,
    required this.onToggle,
  });

  final TextEditingController placeIdController;
  final bool simulating;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.all(12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: placeIdController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Place ID',
                  hintStyle: TextStyle(color: Colors.white54),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onToggle,
              child: Text(simulating ? 'Stop occupancy simulation' : 'Simulate occupancy'),
            ),
          ],
        ),
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
