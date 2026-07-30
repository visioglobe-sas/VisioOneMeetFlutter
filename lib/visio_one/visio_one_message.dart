import 'dart:convert';

/// Enveloppe JSON générique utilisée par le pont JS -> Native.
///
/// Contrat : `{"type": "...", "data": ...}`. Voir `assets/www/map.html`
/// (fonction `sendToNative`) côté JS et `docs/COMMUNICATION_GUIDE.md` pour
/// la liste des `type` émis par le SDK VisioOne.
class VisioOneMessage {
  const VisioOneMessage({required this.type, this.data});

  final String type;
  final Object? data;

  static VisioOneMessage? tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final type = decoded['type'];
      if (type is! String) return null;
      return VisioOneMessage(type: type, data: decoded['data']);
    } catch (_) {
      // Un message malformé ne doit jamais faire planter l'app : on
      // l'ignore et on le laisse tracer dans les logs de la WebView.
      return null;
    }
  }

  @override
  String toString() => 'VisioOneMessage(type: $type, data: $data)';
}
