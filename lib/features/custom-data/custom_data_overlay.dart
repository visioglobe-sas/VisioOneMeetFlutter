import 'package:flutter/material.dart';

import '../../demo_map.dart';
import '../../l10n/app_localizations.dart';
import '../../visio_one/visio_one_controller.dart';
import 'custom_data_bridge.dart';

/// Résultat d'un chargement de CustomData — voir `_CustomDataOverlayState._load`.
class _CustomDataResult {
  const _CustomDataResult({required this.poiId, required this.found, required this.customData});

  final String poiId;
  final bool found;
  final Map<String, String> customData;
}

/// Overlay de la feature `custom-data` : un champ Place ID + un bouton
/// "Load", affiché dans le bottom sheet ouvert par le FAB de
/// `VisioOneMapShell`. "Load" enchaîne les deux appels SDK exigés par cette
/// démo en une seule commande de pont — `venue.refreshCustomData()` puis
/// `venue.getPOICustomData(poi)` côté JS (voir
/// `assets/www/features/custom-data.js`) — plutôt que deux boutons séparés,
/// cohérent avec `startItinerary` qui enchaîne déjà plusieurs appels SDK
/// côté JS pour une seule commande Native -> JS. Voir
/// `docs/features/custom-data.md`.
class CustomDataOverlay extends StatefulWidget {
  const CustomDataOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  State<CustomDataOverlay> createState() => _CustomDataOverlayState();
}

/// Place IDs confirmés (via `mapserver.visioglobe.com`) comme portant de
/// vraies `CustomData` sur la carte `kCustomDataMapHash` utilisée par cette
/// démo (voir `lib/features/feature.dart` et
/// `docs/features/custom-data.md`) — proposés en accès rapide ci-dessous
/// pour ne pas obliger à connaître/taper un Place ID à la main pour voir un
/// résultat non vide.
const List<String> _kKnownPoiIdsWithCustomData = DemoMap.customDataQuickIds;

class _CustomDataOverlayState extends State<CustomDataOverlay> {
  late final TextEditingController _placeIdController =
      widget.controller.panel.text('custom-data.placeId', DemoMap.customDataPlaceId);

  // Dernier résultat affiché, gardé dans `controller.panel` pour le
  // retrouver à la réouverture du panneau.
  late final ValueNotifier<_CustomDataResult?> _result =
      widget.controller.panel.value<_CustomDataResult?>('custom-data.result', null);

  bool _loading = false;

  /// Remplit le champ Place ID avec un des [_kKnownPoiIdsWithCustomData] et
  /// lance immédiatement le chargement — un seul tap pour voir une vraie
  /// liste clé/valeur non vide, plutôt que de devoir taper l'ID à la main
  /// puis appuyer sur "Load".
  void _loadKnownPoi(String poiId) {
    _placeIdController.text = poiId;
    _load();
  }

  Future<void> _load() async {
    final poiId = _placeIdController.text.trim();
    if (poiId.isEmpty) return;

    setState(() => _loading = true);
    _result.value = null;

    // Un poiId introuvable répond quand même (`found: false`) ; `null` =
    // pas de réponse à temps, affiché comme introuvable.
    final data = await widget.controller.loadCustomData(poiId);
    final rawCustomData = data?['customData'];
    _result.value = _CustomDataResult(
      poiId: poiId,
      found: data?['found'] == true,
      customData: {
        if (rawCustomData is Map)
          for (final entry in rawCustomData.entries) entry.key.toString(): entry.value.toString(),
      },
    );
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.customDataKnownPoisLabel, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final poiId in _kKnownPoiIdsWithCustomData)
              ActionChip(
                label: Text(poiId),
                onPressed: _loading ? null : () => _loadKnownPoi(poiId),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _placeIdController,
                decoration: InputDecoration(labelText: l10n.placeIdLabel, isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _loading ? null : _load,
              child: Text(_loading ? l10n.loadingLabel : l10n.customDataLoadButton),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<_CustomDataResult?>(
          valueListenable: _result,
          builder: (context, result, _) => _buildResult(context, l10n, result),
        ),
      ],
    );
  }

  Widget _buildResult(BuildContext context, AppLocalizations l10n, _CustomDataResult? result) {
    if (result == null) return const SizedBox.shrink();

    if (!result.found) {
      return Text(
        l10n.poiNotFound(result.poiId),
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }

    final customData = result.customData;
    if (customData.isEmpty) {
      return Text(l10n.customDataEmpty);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final entry in customData.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text('${entry.key}: ${entry.value}'),
          ),
      ],
    );
  }
}
