// Teste le contrat du pont JS -> Native ([VisioOneMessage]), la seule
// logique pure (sans WebView / platform channels) de ce projet.
//
// Un test de widget complet nécessiterait de mocker le platform channel de
// webview_flutter (WebViewController, JavaScriptChannel...) : hors périmètre
// de ce squelette d'intégration.

import 'package:flutter_test/flutter_test.dart';
import 'package:visio_one_meet_flutter/visio_one/visio_one_message.dart';

void main() {
  group('VisioOneMessage.tryParse', () {
    test('parses a message without data', () {
      final message = VisioOneMessage.tryParse('{"type":"ready"}');
      expect(message?.type, 'ready');
      expect(message?.data, isNull);
    });

    test('parses a message with structured data', () {
      final message = VisioOneMessage.tryParse(
        '{"type":"poiSelected","data":{"id":"B1-UL00-01","name":"Salle A"}}',
      );
      expect(message?.type, 'poiSelected');
      expect((message?.data as Map)['id'], 'B1-UL00-01');
    });

    test('returns null for malformed JSON', () {
      expect(VisioOneMessage.tryParse('not json'), isNull);
    });

    test('returns null when "type" is missing or not a string', () {
      expect(VisioOneMessage.tryParse('{"data":{}}'), isNull);
      expect(VisioOneMessage.tryParse('{"type":42}'), isNull);
    });
  });
}
