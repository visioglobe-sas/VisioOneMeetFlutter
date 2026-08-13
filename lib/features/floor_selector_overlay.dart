import 'dart:async';

import 'package:flutter/material.dart';

import '../visio_one/visio_one_controller.dart';
import '../visio_one/visio_one_message.dart';

/// Overlay de la feature `floor-selector` : liste de boutons de bâtiments
/// (si la venue en compte plusieurs) puis d'étages du bâtiment sélectionné,
/// affichée dans le bottom sheet ouvert par le FAB de [VisioOneMapShell].
///
/// `goToFloor` existait déjà sur [VisioOneController] (statut 🟡 dans
/// `VisioOneHub/CHECKLIST.md` : câblé jusqu'au pont JS, jamais relié à un
/// bouton) — la pièce manquante n'était pas ce contrôleur mais une source de
/// données : rien ne renvoyait la liste des bâtiments/étages de la venue
/// côté Dart, donc pas de moyen de savoir *quels* boutons afficher sans
/// coder en dur des identifiants propres à une carte de démo. Cette classe
/// demande cette liste via [VisioOneController.getVenueLayout] (nouvelle
/// commande, voir `assets/www/map.html`) et l'affiche dynamiquement. Voir
/// `docs/features/floor-selector.md`.
class FloorSelectorOverlay extends StatefulWidget {
  const FloorSelectorOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  State<FloorSelectorOverlay> createState() => _FloorSelectorOverlayState();
}

class _FloorSelectorOverlayState extends State<FloorSelectorOverlay> {
  StreamSubscription<VisioOneMessage>? _subscription;
  List<_Building>? _buildings;
  String? _selectedBuildingId;
  String? _selectedFloorId;

  @override
  void initState() {
    super.initState();
    _subscription = widget.controller.messages.listen(_onMessage);
    widget.controller.getVenueLayout();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _onMessage(VisioOneMessage message) {
    switch (message.type) {
      case 'venueLayout':
        _onVenueLayout(message.data);
      case 'floorChanged':
        // Garde ce panneau synchronisé si l'étage courant change par un
        // autre biais pendant qu'il est ouvert — le floor-selector natif du
        // SDK lui-même (toujours affiché sur la carte, voir
        // `docs/features/floor-selector.md`, "Points d'attention") ou un
        // `goToPOI` déclenché depuis un autre écran de feature.
        final data = message.data;
        if (data is! Map) return;
        setState(() {
          _selectedBuildingId = data['buildingId'] as String? ?? _selectedBuildingId;
          _selectedFloorId = data['floorId'] as String?;
        });
    }
  }

  void _onVenueLayout(Object? data) {
    if (data is! Map) return;
    final rawBuildings = data['buildings'];
    if (rawBuildings is! List) return;

    final buildings = rawBuildings
        .whereType<Map>()
        .map(_Building.fromJson)
        .where((b) => b.floors.isNotEmpty)
        .toList();
    if (buildings.isEmpty) return;

    final currentBuildingId = data['currentBuildingId'] as String?;
    final currentFloorId = data['currentFloorId'] as String?;
    final hasCurrentBuilding = buildings.any((b) => b.id == currentBuildingId);

    setState(() {
      _buildings = buildings;
      _selectedBuildingId = hasCurrentBuilding ? currentBuildingId : buildings.first.id;
      _selectedFloorId = hasCurrentBuilding ? currentFloorId : null;
    });
  }

  void _selectBuilding(_Building building) {
    if (building.id == _selectedBuildingId) return;
    setState(() {
      _selectedBuildingId = building.id;
      _selectedFloorId = null;
    });
    // Pas de floorId : `window.MapBridge.goToFloor` bascule alors sur
    // l'étage par défaut du bâtiment (`view.goToBuilding`), voir map.html.
    widget.controller.goToFloor(buildingId: building.id);
  }

  void _selectFloor(_Building building, _Floor floor) {
    setState(() {
      _selectedBuildingId = building.id;
      _selectedFloorId = floor.id;
    });
    widget.controller.goToFloor(buildingId: building.id, floorId: floor.id);
  }

  @override
  Widget build(BuildContext context) {
    final buildings = _buildings;
    if (buildings == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
            SizedBox(width: 12),
            Text('Loading buildings and floors…'),
          ],
        ),
      );
    }

    final selectedBuilding = buildings.firstWhere(
      (b) => b.id == _selectedBuildingId,
      orElse: () => buildings.first,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (buildings.length > 1) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: buildings.map((building) {
              final isSelected = building.id == selectedBuilding.id;
              return ChoiceChip(
                label: Text(building.id),
                selected: isSelected,
                onSelected: (_) => _selectBuilding(building),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
        ...selectedBuilding.floors.map((floor) {
          final isSelected = floor.id == _selectedFloorId;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity,
              child: isSelected
                  ? FilledButton.icon(
                      onPressed: () => _selectFloor(selectedBuilding, floor),
                      icon: const Icon(Icons.check),
                      label: Text('Floor ${floor.levelIndex}'),
                    )
                  : OutlinedButton(
                      onPressed: () => _selectFloor(selectedBuilding, floor),
                      child: Text('Floor ${floor.levelIndex}'),
                    ),
            ),
          );
        }),
      ],
    );
  }
}

/// Bâtiment tel que reçu du message `venueLayout` (voir map.html,
/// `window.MapBridge.getVenueLayout`) — pas de nom/libellé exposé par le
/// SDK pour un `Building`, seulement son `id` (voir
/// `docs/features/floor-selector.md`, "Points d'attention").
class _Building {
  const _Building({required this.id, required this.floors});

  final String id;
  final List<_Floor> floors;

  static _Building fromJson(Map json) {
    final rawFloors = json['floors'];
    return _Building(
      id: json['id'] as String,
      floors: rawFloors is List ? rawFloors.whereType<Map>().map(_Floor.fromJson).toList() : const [],
    );
  }
}

/// Étage tel que reçu du message `venueLayout`. `levelIndex` (pas de
/// nom/libellé exposé non plus, voir `_Building`) est aussi ce que le
/// floor-selector natif du SDK affiche par défaut.
class _Floor {
  const _Floor({required this.id, required this.levelIndex});

  final String id;
  final int levelIndex;

  static _Floor fromJson(Map json) {
    return _Floor(id: json['id'] as String, levelIndex: json['levelIndex'] as int);
  }
}
