import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../visio_one/visio_one_controller.dart';
import '../../visio_one/visio_one_message.dart';
import '../shared/color_chip.dart';
import 'custom_theme_bridge.dart';

/// Thème de scène 3D par défaut du SDK (`view.setTheme`), et réglages
/// d'accent par défaut de la démo (bleu Visioglobe / blanc).
const String kDefaultTheme = 'day';
const String kDefaultAccentColor = '#0094F0';
const String kDefaultTextAccentColor = '#FFFFFF';

/// Couleurs d'accent proposées (`view.accentColor`), dans l'ordre des chips.
const List<String> _kAccentColors = [kDefaultAccentColor, '#E53935', '#43A047', '#8E24AA'];

/// Couleurs de texte d'accent proposées (`view.textAccentColor`).
const List<String> _kTextAccentColors = [kDefaultTextAccentColor, '#FFEB3B', '#212121'];

String _colorName(AppLocalizations l10n, String hex) => switch (hex) {
  kDefaultAccentColor => l10n.colorVisioglobeBlue,
  '#E53935' => l10n.colorRed,
  '#43A047' => l10n.colorGreen,
  '#8E24AA' => l10n.colorPurple,
  kDefaultTextAccentColor => l10n.colorWhite,
  '#FFEB3B' => l10n.colorYellow,
  _ => l10n.colorBlack,
};

/// Overlay de la feature `custom-theme`, affiché dans le bottom sheet ouvert
/// par le FAB de `VisioOneMapShell` : un choix de thème de scène 3D construit
/// à l'exécution depuis `view.themes` (ids bruts du SDK), des chips de
/// couleur d'accent et de couleur de texte d'accent, et un bouton Reset.
/// Tout s'applique immédiatement, sans bouton "Apply".
///
/// L'état (thème courant, couleurs) vit dans `controller.panel` pour survivre à la
/// fermeture du bottom sheet — fermeture nécessaire pour taper un lieu et
/// voir la fiche POI dont le bouton "Go" utilise les couleurs d'accent. La
/// carte de cet écran est créée avec `enableShadows: true` (voir
/// `lib/features/feature.dart`), sans quoi `setTheme` n'aurait aucun effet visible. Voir
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

  // État gardé dans `controller.panel` (survit à la fermeture du bottom
  // sheet). Le thème appliqué est suivi côté app : le SDK (1.1.0 inclus)
  // n'a pas de getter du thème courant.
  ValueNotifier<List<String>?> get _themes => _c.panel.value<List<String>?>('custom-theme.themes', null);
  ValueNotifier<String> get _theme => _c.panel.value<String>('custom-theme.theme', kDefaultTheme);
  ValueNotifier<String> get _accent => _c.panel.value<String>('custom-theme.accent', kDefaultAccentColor);
  ValueNotifier<String> get _textAccent => _c.panel.value<String>('custom-theme.textAccent', kDefaultTextAccentColor);

  void _setTheme(String name) {
    _theme.value = name;
    _c.setTheme(name);
  }

  void _setAccentColors({required String accent, required String textAccent}) {
    _accent.value = accent;
    _textAccent.value = textAccent;
    _c.setAccentColors(accent: accent, textAccent: textAccent);
  }

  @override
  void initState() {
    super.initState();
    _subscription = _c.messages.listen(_onMessage);
    // `view.themes` ne change pas pendant la vie de la vue : une seule
    // lecture suffit, la réponse est mise en cache dans `controller.panel`.
    if (_themes.value == null) {
      _c.getThemes().then((themes) {
        if (themes != null) _themes.value = themes;
      });
    }
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
    _setTheme(kDefaultTheme);
    _setAccentColors(accent: kDefaultAccentColor, textAccent: kDefaultTextAccentColor);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: Listenable.merge([_themes, _theme, _accent, _textAccent]),
      builder: (context, _) {
        final themes = _themes.value;
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
                        selected: _theme.value == id,
                        onSelected: (_) => _setTheme(id),
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
                      selected: _accent.value == hex,
                      onSelected: () => _setAccentColors(accent: hex, textAccent: _textAccent.value),
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
                      selected: _textAccent.value == hex,
                      onSelected: () => _setAccentColors(accent: _accent.value, textAccent: hex),
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
