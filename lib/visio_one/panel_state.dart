import 'package:flutter/widgets.dart';

/// Valeurs saisies dans les panneaux de feature (champs texte, interrupteurs,
/// derniers résultats affichés), conservées au niveau de l'écran.
///
/// Le panneau (bottom sheet) est reconstruit à chaque ouverture du FAB : un
/// `TextEditingController` ou un `bool` gardé dans le `State` d'un overlay
/// serait perdu à chaque fermeture. Ce magasin, porté par
/// `VisioOneController` (une instance par écran de feature, détruite en
/// quittant l'écran), crée chaque valeur à la première ouverture avec sa
/// valeur par défaut, puis rend la même instance aux ouvertures suivantes :
/// le panneau rouvert affiche donc ce qui a été saisi et ce qui tourne sur
/// la carte.
///
/// Les clés sont préfixées par le slug de la feature (ex.
/// `'goto-poi.placeId'`) ; une même clé lue par deux panneaux d'un même
/// écran désigne la même valeur.
class PanelState {
  final Map<String, ChangeNotifier> _entries = {};

  /// Contrôleur de champ texte persistant pour [key], créé avec [initial]
  /// à la première demande. Ne jamais le `dispose()` côté overlay.
  TextEditingController text(String key, String initial) =>
      _entries.putIfAbsent(key, () => TextEditingController(text: initial)) as TextEditingController;

  /// Valeur observable persistante pour [key], créée avec [initial] à la
  /// première demande. Ne jamais la `dispose()` côté overlay.
  ValueNotifier<T> value<T>(String key, T initial) =>
      _entries.putIfAbsent(key, () => ValueNotifier<T>(initial)) as ValueNotifier<T>;

  /// À appeler par `VisioOneController.dispose()`.
  void dispose() {
    for (final entry in _entries.values) {
      entry.dispose();
    }
    _entries.clear();
  }
}
