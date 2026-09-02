import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../visio_one/visio_one_map_shell.dart';

/// Panneau de la démo `custom-base-url` : un champ "Base URL" pré-rempli
/// avec [kDefaultMapServerBaseUrl] (le défaut public du SDK) + un bouton
/// Reload. Contrairement aux autres features, il ne parle pas directement
/// au [VisioOneController] : `baseURL` est une option de `loadVenue`, pas
/// une propriété mutable sur une venue déjà chargée, donc la seule façon de
/// la changer est de reconstruire tout le [VisioOneMapShell] avec une
/// nouvelle valeur — [onReload] remonte la valeur tapée à [FeatureScreen],
/// qui possède cet état et déclenche le remount (voir
/// `docs/features/custom-base-url.md`).
class CustomBaseUrlOverlay extends StatefulWidget {
  const CustomBaseUrlOverlay({super.key, required this.currentBaseUrl, required this.onReload});

  final String currentBaseUrl;
  final ValueChanged<String> onReload;

  @override
  State<CustomBaseUrlOverlay> createState() => _CustomBaseUrlOverlayState();
}

class _CustomBaseUrlOverlayState extends State<CustomBaseUrlOverlay> {
  late final TextEditingController _textController = TextEditingController(text: widget.currentBaseUrl);

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.customBaseUrlDescription),
        const SizedBox(height: 12),
        TextField(
          controller: _textController,
          decoration: InputDecoration(labelText: l10n.customBaseUrlFieldLabel, border: const OutlineInputBorder()),
          keyboardType: TextInputType.url,
          autocorrect: false,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () {
            final value = _textController.text.trim();
            widget.onReload(value.isEmpty ? kDefaultMapServerBaseUrl : value);
          },
          child: Text(l10n.customBaseUrlReloadButton),
        ),
      ],
    );
  }
}
