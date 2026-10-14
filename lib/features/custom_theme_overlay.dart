import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../visio_one/visio_one_controller.dart';
import '../visio_one/visio_one_message.dart';

/// Couleurs d'accent proposées (`view.accentColor`), dans l'ordre des chips.
const List<(String label, String hex)> _kAccentColors = [
  ('Visioglobe blue', VisioOneController.kDefaultAccentColor),
  ('Red', '#E53935'),
  ('Green', '#43A047'),
  ('Purple', '#8E24AA'),
];

/// Couleurs de texte d'accent proposées (`view.textAccentColor`).
const List<(String label, String hex)> _kTextAccentColors = [
  ('White', VisioOneController.kDefaultTextAccentColor),
  ('Yellow', '#FFEB3B'),
  ('Black', '#212121'),
];

/// Overlay de la feature `custom-theme`, affiché dans le bottom sheet ouvert
/// par le FAB de [VisioOneMapShell] : un choix de thème de scène 3D construit
/// à l'exécution depuis `view.themes` (ids bruts du SDK), des chips de
/// couleur d'accent et de couleur de texte d'accent, et un bouton Reset.
/// Tout s'applique immédiatement, sans bouton "Apply".
///
/// L'état (thème courant, couleurs) vit sur le contrôleur pour survivre à la
/// fermeture du bottom sheet — fermeture nécessaire pour taper un lieu et
/// voir la fiche POI dont le bouton "Go" utilise les couleurs d'accent. La
/// carte de cet écran est créée avec `enableShadows: true` (voir
/// `FeatureScreen`), sans quoi `setTheme` n'aurait aucun effet visible. Voir
/// `docs/features/custom-theme.md`.
class CustomThemeOverlay extends StatefulWidget {
  const CustomThemeOverlay({super.key, required this.controller});

  final VisioOneController controller;

  @override
  State<CustomThemeOverlay> createState() => _CustomThemeOverlayState();
}

class _CustomThemeOverlayState extends State<CustomThemeOverlay> {
  StreamSubscription<VisioOneMessage>? _subscription;
  String? _errorMessage;
  int _requestCounter = 0;

  VisioOneController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _subscription = _c.messages.listen(_onMessage);
    // `view.themes` ne change pas pendant la vie de la vue : une seule
    // lecture suffit, la réponse est mise en cache dans `_c.themes`.
    if (_c.themes.value == null) unawaited(_c.getThemes('custom-theme-${_requestCounter++}'));
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _onMessage(VisioOneMessage message) {
    if (message.type != 'themeApplied' && message.type != 'accentColorsApplied') return;
    final data = message.data;
    if (data is! Map || !mounted) return;
    setState(() => _errorMessage = data['success'] == true ? null : data['message'] as String?);
  }

  void _reset() {
    unawaited(_c.setTheme(VisioOneController.kDefaultTheme));
    unawaited(
      _c.setAccentColors(
        accent: VisioOneController.kDefaultAccentColor,
        textAccent: VisioOneController.kDefaultTextAccentColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: Listenable.merge([_c.themes, _c.currentTheme, _c.accentColor, _c.textAccentColor]),
      builder: (context, _) {
        final themes = _c.themes.value;
        final labelStyle = Theme.of(context).textTheme.labelLarge;
        // Le bottom sheet est limité en hauteur : le panneau défile si besoin.
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Theme', style: labelStyle),
              const SizedBox(height: 4),
              if (themes == null)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                Wrap(
                  spacing: 8,
                  children: [
                    for (final id in themes)
                      ChoiceChip(
                        label: Text(id),
                        selected: _c.currentTheme.value == id,
                        onSelected: (_) => _c.setTheme(id),
                      ),
                  ],
                ),
              const SizedBox(height: 12),
              Text('Accent color', style: labelStyle),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  for (final (name, hex) in _kAccentColors)
                    ChoiceChip(
                      avatar: _Swatch(hex: hex),
                      label: Text(name),
                      selected: _c.accentColor.value == hex,
                      showCheckmark: false,
                      onSelected: (_) => _c.setAccentColors(accent: hex, textAccent: _c.textAccentColor.value),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Accent text color', style: labelStyle),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  for (final (name, hex) in _kTextAccentColors)
                    ChoiceChip(
                      avatar: _Swatch(hex: hex),
                      label: Text(name),
                      selected: _c.textAccentColor.value == hex,
                      showCheckmark: false,
                      onSelected: (_) => _c.setAccentColors(accent: _c.accentColor.value, textAccent: hex),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _reset, child: const Text('Reset')),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? l10n.customThemeHint,
                style: _errorMessage != null
                    ? TextStyle(color: Theme.of(context).colorScheme.error)
                    : Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Pastille de couleur avec un contour, pour que le blanc et le noir restent
/// visibles quelle que soit la couleur de fond du panneau.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.hex});

  final String hex;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 18,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0xFF000000 | int.parse(hex.substring(1), radix: 16)),
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
      ),
    );
  }
}
