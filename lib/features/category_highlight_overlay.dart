import 'dart:async';

import 'package:flutter/material.dart';

import '../visio_one/visio_one_controller.dart';
import '../visio_one/visio_one_message.dart';

/// Overlay de la feature `category-highlight` : liste les catégories de la
/// venue (`venue.categories`, récupérées via un aller-retour de pont —
/// [VisioOneController.getCategories] / message `categoriesLoaded`, même
/// idiom `requestId` que `custom-data`) sous forme de chips sélectionnables,
/// affichée dans le bottom sheet ouvert par le FAB de [VisioOneMapShell].
/// Taper une catégorie met en avant tous ses POI
/// ([VisioOneController.highlightCategory]) ; la retaper, ou "Clear", les
/// réinitialise ([VisioOneController.clearCategoryHighlight]). Une seule
/// catégorie est jamais mise en avant à la fois — invariant porté par
/// [VisioOneController.highlightedCategoryId], pas par cet overlay, pour
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
  StreamSubscription<VisioOneMessage>? _subscription;
  late final String _requestId = 'category-highlight-${DateTime.now().microsecondsSinceEpoch}';

  List<({String id, String label})>? _categories;

  @override
  void initState() {
    super.initState();
    _subscription = widget.controller.messages.listen(_onMessage);
    widget.controller.getCategories(_requestId);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _onMessage(VisioOneMessage message) {
    if (message.type != 'categoriesLoaded') return;
    final data = message.data;
    if (data is! Map || data['requestId'] != _requestId) return;
    final rawCategories = data['categories'];
    if (rawCategories is! List) return;
    setState(() {
      _categories = rawCategories.map((c) {
        final map = c as Map;
        return (id: map['id'].toString(), label: map['label'].toString());
      }).toList();
    });
  }

  void _toggle(String categoryId) {
    if (widget.controller.highlightedCategoryId.value == categoryId) {
      widget.controller.clearCategoryHighlight();
    } else {
      widget.controller.highlightCategory(categoryId);
    }
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
      return const Text('This venue has no categories.');
    }

    return ValueListenableBuilder<String?>(
      valueListenable: widget.controller.highlightedCategoryId,
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
              onPressed: selected == null ? null : widget.controller.clearCategoryHighlight,
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );
  }
}
