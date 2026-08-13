import 'dart:async';

import 'package:flutter/material.dart';

import '../visio_one/visio_one_controller.dart';

// Stand-in for a real occupancy sensor feed: cycles a POI's surface through
// these colors on a timer. See docs/features/occupancy-simulated.md.
const List<String> _occupancyColors = ['#2ECC71', '#F1C40F', '#E74C3C'];
const Duration _occupancyInterval = Duration(milliseconds: 2500);

/// Overlay de la feature `occupancy-simulated` : un contrôle (champ Place ID
/// + bouton toggle), affiché dans le bottom sheet de l'écran de feature, qui
/// fait tourner la couleur d'occupation d'un POI sur un `Timer.periodic`, en
/// lieu et place d'un vrai capteur.
class OccupancySimulationOverlay extends StatefulWidget {
  const OccupancySimulationOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  State<OccupancySimulationOverlay> createState() => _OccupancySimulationOverlayState();
}

class _OccupancySimulationOverlayState extends State<OccupancySimulationOverlay> {
  final TextEditingController _placeIdController = TextEditingController();
  Timer? _occupancyTimer;
  bool _simulateOccupancy = false;
  int _occupancyColorIndex = 0;
  // The place ID actually targeted by the running timer — captured at start,
  // deliberately not re-read from the text field on stop (see _stopOccupancySimulation).
  String? _simulatingPlaceId;

  @override
  void dispose() {
    _occupancyTimer?.cancel();
    _placeIdController.dispose();
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
    if (placeId.isEmpty) return;

    setState(() => _simulateOccupancy = true);
    _simulatingPlaceId = placeId;
    _occupancyColorIndex = 0;
    widget.controller.updateOccupancy([
      {'planId': placeId, 'color': _occupancyColors[_occupancyColorIndex]},
    ]);
    _occupancyTimer = Timer.periodic(_occupancyInterval, (_) {
      _occupancyColorIndex = (_occupancyColorIndex + 1) % _occupancyColors.length;
      widget.controller.updateOccupancy([
        {'planId': placeId, 'color': _occupancyColors[_occupancyColorIndex]},
      ]);
    });
  }

  void _stopOccupancySimulation() {
    _occupancyTimer?.cancel();
    _occupancyTimer = null;
    // Reset the POI that was actually being simulated — not whatever the text
    // field currently holds, which may have been edited since simulation started.
    final placeId = _simulatingPlaceId;
    _simulatingPlaceId = null;
    if (placeId != null && placeId.isNotEmpty) {
      // Reset the surface rather than leaving it stuck on the last simulated color.
      widget.controller.updateOccupancy([{'planId': placeId, 'color': null}]);
    }
    setState(() => _simulateOccupancy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _placeIdController,
            decoration: const InputDecoration(hintText: 'Place ID', isDense: true),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _toggleOccupancySimulation,
          child: Text(_simulateOccupancy ? 'Stop occupancy simulation' : 'Simulate occupancy'),
        ),
      ],
    );
  }
}
