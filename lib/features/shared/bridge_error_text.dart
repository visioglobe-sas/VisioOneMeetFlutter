import '../../l10n/app_localizations.dart';

/// Résultat renvoyé par le pont quand la réponse n'arrive pas à temps.
const Map<String, Object?> kBridgeTimeoutResult = {'success': false, 'error': 'timeout'};

/// Texte traduit d'un échec renvoyé par le pont (`{success: false, error,
/// message?}`) pour les démos qui créent des objets sur la carte
/// (`dynamic-poi-crud`, `3d-icon-marker`, `custom-text-label`,
/// `html-overlay-marker`). [anchorId] complète le message des erreurs liées
/// au POI ancre. Pour `'sdk'` et `'alreadyExists'`, le message d'origine du
/// SDK (en anglais) est affiché tel quel après le libellé traduit.
String bridgeErrorText(AppLocalizations l10n, Map<String, Object?> result, {String anchorId = ''}) {
  final sdkMessage = result['message'] as String?;
  return switch (result['error']) {
    'textRequired' => l10n.errorTextRequired,
    'notFound' => l10n.poiNotFound(anchorId),
    'noPosition' => l10n.errorNoPosition(anchorId),
    'noLabel' => l10n.errorNoLabel,
    'noBadge' => l10n.errorNoBadge,
    'noImage' => l10n.errorNoImage,
    'noPoi' => l10n.errorNoDynamicPoi,
    'alreadyExists' => l10n.errorPoiAlreadyExists,
    'notReady' => l10n.errorMapNotReady,
    'timeout' => l10n.errorTimeout,
    _ => sdkMessage == null ? l10n.errorGeneric : l10n.errorSdk(sdkMessage),
  };
}
