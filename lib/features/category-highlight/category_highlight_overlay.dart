import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../visio_one/visio_one_controller.dart';
import 'category_highlight_bridge.dart';

/// Overlay de la feature `category-highlight` : liste les catégories de la
/// venue (`venue.categories`, récupérées via un aller-retour de pont —
/// [CategoryHighlightBridge.getCategories] / message `categoriesLoaded`) sous forme de chips sélectionnables,
/// affichée dans le bottom sheet ouvert par le FAB de `VisioOneMapShell`.
/// Taper une catégorie met en avant tous ses POI
/// ([CategoryHighlightBridge.highlightCategory]) ; la retaper, ou "Clear",
/// les réinitialise ([CategoryHighlightBridge.clearCategoryHighlight]). Une
/// seule catégorie est jamais mise en avant à la fois — invariant porté par
/// `controller.panel`, pas par le `State` de cet overlay, pour
/// rester correct même si le bottom sheet est fermé puis rouvert (cet
/// overlay est recréé à chaque ouverture, comme tous les overlays de ce
/// dépôt). Voir `docs/features/category-highlight.md`.
class CategoryHighlightOverlay extends StatefulWidget {
  const CategoryHighlightOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  State<CategoryHighlightOverlay> createState() => _CategoryHighlightOverlayState();
}

class _CategoryHighlightOverlayState extends State<CategoryHighlightOverlay> {
  List<({String id, String label})>? _categories;

  VisioOneController get _c => widget.controller;

  /// Catégorie actuellement mise en avant (ou `null`), gardée dans
  /// `controller.panel` pour survivre à la fermeture du bottom sheet : sans
  /// ça, rouvrir le panneau perdrait la trace de la catégorie surlignée, et
  /// un nouveau tap pourrait cumuler les surlignages au lieu de les
  /// remplacer (contrat : une seule catégorie mise en avant à la fois).
  ValueNotifier<String?> get _selected => _c.panel.value<String?>('category-highlight.selected', null);

  @override
  void initState() {
    super.initState();
    _c.getCategories().then((categories) {
      if (mounted) setState(() => _categories = categories ?? const []);
    });
  }

  /// Met en avant [categoryId] après avoir réinitialisé la catégorie
  /// précédente ; la retaper la réinitialise.
  Future<void> _toggle(String categoryId) async {
    final previous = _selected.value;
    if (previous != null) {
      _selected.value = null;
      await _c.clearCategoryHighlight(previous);
    }
    if (previous == categoryId) return;
    _selected.value = categoryId;
    await _c.highlightCategory(categoryId);
  }

  Future<void> _clear() async {
    final current = _selected.value;
    if (current == null) return;
    _selected.value = null;
    await _c.clearCategoryHighlight(current);
  }

  @override
  Widget build(BuildContext context) {
    final categories = _categories;
    if (categories == null) {
      return const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (categories.isEmpty) {
      return Text(AppLocalizations.of(context)!.categoryHighlightEmpty);
    }

    return ValueListenableBuilder<String?>(
      valueListenable: _selected,
      builder: (context, selected, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in categories)
                  ChoiceChip(
                    label: Text(category.label),
                    selected: selected == category.id,
                    onSelected: (_) => _toggle(category.id),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: selected == null ? null : _clear,
              child: Text(AppLocalizations.of(context)!.clearButton),
            ),
          ],
        );
      },
    );
  }
}
