import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../visio_one/visio_one_controller.dart';
import '../visio_one/visio_one_message.dart';
import 'shared/color_chip.dart';

/// Couleurs d'accent proposées (`view.accentColor`), dans l'ordre des chips.
const List<String> _kAccentColors = [VisioOneController.kDefaultAccentColor, '#E53935', '#43A047', '#8E24AA'];

/// Couleurs de texte d'accent proposées (`view.textAccentColor`).
const List<String> _kTextAccentColors = [VisioOneController.kDefaultTextAccentColor, '#FFEB3B', '#212121'];

String _colorName(AppLocalizations l10n, String hex) => switch (hex) {
  VisioOneController.kDefaultAccentColor => l10n.colorVisioglobeBlue,
  '#E53935' => l10n.colorRed,
  '#43A047' => l10n.colorGreen,
  '#8E24AA' => l10n.colorPurple,
  VisioOneController.kDefaultTextAccentColor => l10n.colorWhite,
  '#FFEB3B' => l10n.colorYellow,
  _ => l10n.colorBlack,
};

/// Overlay de la feature `custom-theme`, affiché dans le bottom sheet ouvert
/// par le FAB de `VisioOneMapShell` : un choix de thème de scène 3D construit
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
  // Message du SDK du dernier échec (`themeApplied` / `accentColorsApplied`).
  String? _sdkError;

  VisioOneController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _subscription = _c.messages.listen(_onMessage);
    // `view.themes` ne change pas pendant la vie de la vue : une seule
    // lecture suffit, la réponse est mise en cache dans `_c.themes`.
    if (_c.themes.value == null) unawaited(_c.getThemes('custom-theme-themes'));
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
    setState(() => _sdkError = data['success'] == true ? null : (data['message'] as String? ?? ''));
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
        final sdkError = _sdkError;
        return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.customThemeThemeLabel, style: labelStyle),
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
              Text(l10n.customThemeAccentLabel, style: labelStyle),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  for (final hex in _kAccentColors)
                    ColorChoiceChip(
                      hex: hex,
                      label: _colorName(l10n, hex),
                      selected: _c.accentColor.value == hex,
                      onSelected: () => _c.setAccentColors(accent: hex, textAccent: _c.textAccentColor.value),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(l10n.customThemeTextAccentLabel, style: labelStyle),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  for (final hex in _kTextAccentColors)
                    ColorChoiceChip(
                      hex: hex,
                      label: _colorName(l10n, hex),
                      selected: _c.textAccentColor.value == hex,
                      onSelected: () => _c.setAccentColors(accent: _c.accentColor.value, textAccent: hex),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _reset, child: Text(l10n.resetButton)),
              const SizedBox(height: 12),
              Text(
                sdkError != null ? l10n.errorSdk(sdkError) : l10n.customThemeHint,
                style: sdkError != null
                    ? TextStyle(color: Theme.of(context).colorScheme.error)
                    : Theme.of(context).textTheme.bodyMedium,
              ),
            ],
        );
      },
    );
  }
}
